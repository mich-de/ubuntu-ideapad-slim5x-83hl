// SPDX-License-Identifier: GPL-2.0-only
/*
 * 83HL (Snapdragon X1P-42-100): voti di alimentazione che Windows tiene per il CDSP (NPU) mentre gira.
 *
 * Dal file di risorse Windows RCDS.bin (\_SB.NSP0, pacchetto qcsubsys_ext_cdsp8380):
 *   P0 (avvio):    rail cx, mxa, mxc, nsp = 384 (turbo), xo acceso, bus CDSP_PROC->EBI1 e CDSP_PROC->CLK_CTL
 *   P1 (in corsa): solo nsp torna a 0; tutto il resto RESTA votato
 * Linux (qcom_q6v5_pas) rilascia cx/mxc/nsp/xo dopo l'handover e non vota mai mxa ne' CLK_CTL: su questo SoC il CDSP
 * parte, annuncia i canali glink e poi smette di rispondere (qualcomm/fastrpc#405).
 *
 * Il driver non vota nulla finche' non viene attivato:
 *   echo 1 > /sys/devices/platform/cdsp-keepalive/active      (0 per rilasciare)
 * oppure al caricamento: modprobe cdsp_keepalive_83hl active=1 [level=384] [mask=7]
 *   mask: bit0 rail, bit1 xo, bit2 bus (per capire quale voto serve davvero)
 */
#include <linux/clk.h>
#include <linux/interconnect.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/pm_domain.h>
#include <linux/pm_runtime.h>

static bool active;
module_param(active, bool, 0444);
static unsigned int level = 384;
module_param(level, uint, 0644);
static unsigned int mask = 7;
module_param(mask, uint, 0644);

struct keepalive {
	struct device *dev;
	struct dev_pm_domain_list *pds;
	struct clk *xo;
	struct icc_path *ebi, *clkctl;
	struct mutex lock;
	bool on;
	unsigned int on_mask;
};

static int keepalive_set(struct keepalive *ka, bool on)
{
	int i, ret = 0;

	mutex_lock(&ka->lock);
	if (on == ka->on)
		goto out;
	if (on) {
		ka->on_mask = mask;
		if (ka->on_mask & 1) {
			for (i = 0; ka->pds && i < ka->pds->num_pds; i++) {
				ret = dev_pm_genpd_set_performance_state(ka->pds->pd_devs[i], level);
				if (ret)
					dev_warn(ka->dev, "rail %d: livello %u rifiutato (%d)\n", i, level, ret);
				ret = pm_runtime_resume_and_get(ka->pds->pd_devs[i]);
				if (ret)
					dev_warn(ka->dev, "rail %d: accensione fallita (%d)\n", i, ret);
			}
		}
		if ((ka->on_mask & 2) && ka->xo)
			clk_prepare_enable(ka->xo);
		if (ka->on_mask & 4) {
			if (ka->ebi)
				icc_set_bw(ka->ebi, 1, 1);
			if (ka->clkctl)
				icc_set_bw(ka->clkctl, 1, 1);
		}
		ret = 0;
	} else {
		if (ka->on_mask & 4) {
			if (ka->ebi)
				icc_set_bw(ka->ebi, 0, 0);
			if (ka->clkctl)
				icc_set_bw(ka->clkctl, 0, 0);
		}
		if ((ka->on_mask & 2) && ka->xo)
			clk_disable_unprepare(ka->xo);
		if (ka->on_mask & 1) {
			for (i = 0; ka->pds && i < ka->pds->num_pds; i++) {
				pm_runtime_put_sync(ka->pds->pd_devs[i]);
				dev_pm_genpd_set_performance_state(ka->pds->pd_devs[i], 0);
			}
		}
	}
	ka->on = on;
	dev_info(ka->dev, "voti CDSP %s (mask %u, livello %u)\n", on ? "ATTIVI" : "rilasciati", ka->on_mask, level);
out:
	mutex_unlock(&ka->lock);
	return ret;
}

static ssize_t active_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct keepalive *ka = dev_get_drvdata(dev);

	return sysfs_emit(buf, "%d\n", ka->on);
}

static ssize_t active_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
	struct keepalive *ka = dev_get_drvdata(dev);
	bool on;
	int ret;

	ret = kstrtobool(buf, &on);
	if (ret)
		return ret;
	ret = keepalive_set(ka, on);
	return ret ? ret : count;
}
static DEVICE_ATTR_RW(active);

static struct attribute *keepalive_attrs[] = {
	&dev_attr_active.attr,
	NULL
};
ATTRIBUTE_GROUPS(keepalive);

static void keepalive_off(void *data)
{
	keepalive_set(data, false);
}

static int keepalive_probe(struct platform_device *pdev)
{
	static const struct dev_pm_domain_attach_data pd_data = { .pd_flags = PD_FLAG_NO_DEV_LINK };
	struct device *dev = &pdev->dev;
	struct keepalive *ka;
	int ret;

	ka = devm_kzalloc(dev, sizeof(*ka), GFP_KERNEL);
	if (!ka)
		return -ENOMEM;
	ka->dev = dev;
	mutex_init(&ka->lock);
	platform_set_drvdata(pdev, ka);

	ret = devm_pm_domain_attach_list(dev, &pd_data, &ka->pds);
	if (ret < 0)
		return dev_err_probe(dev, ret, "power domain non disponibili\n");

	ka->xo = devm_clk_get_optional(dev, "xo");
	if (IS_ERR(ka->xo))
		return dev_err_probe(dev, PTR_ERR(ka->xo), "clock xo\n");

	ka->ebi = devm_of_icc_get(dev, "ebi");
	if (IS_ERR(ka->ebi)) {
		if (PTR_ERR(ka->ebi) == -EPROBE_DEFER)
			return -EPROBE_DEFER;
		dev_warn(dev, "percorso bus ebi non disponibile (%ld)\n", PTR_ERR(ka->ebi));
		ka->ebi = NULL;
	}
	ka->clkctl = devm_of_icc_get(dev, "clkctl");
	if (IS_ERR(ka->clkctl)) {
		if (PTR_ERR(ka->clkctl) == -EPROBE_DEFER)
			return -EPROBE_DEFER;
		dev_warn(dev, "percorso bus clkctl non disponibile (%ld)\n", PTR_ERR(ka->clkctl));
		ka->clkctl = NULL;
	}

	ret = devm_add_action_or_reset(dev, keepalive_off, ka);
	if (ret)
		return ret;

	dev_info(dev, "pronto: %d rail, xo %s, bus ebi %s clkctl %s\n", ka->pds ? ka->pds->num_pds : 0,
		 ka->xo ? "si" : "no", ka->ebi ? "si" : "no", ka->clkctl ? "si" : "no");
	return active ? keepalive_set(ka, true) : 0;
}

static const struct of_device_id keepalive_of_match[] = {
	{ .compatible = "lenovo,83hl-cdsp-keepalive" },
	{ }
};
MODULE_DEVICE_TABLE(of, keepalive_of_match);

static struct platform_driver keepalive_driver = {
	.probe = keepalive_probe,
	.driver = {
		.name = "cdsp-keepalive-83hl",
		.of_match_table = keepalive_of_match,
		.dev_groups = keepalive_groups,
	},
};
module_platform_driver(keepalive_driver);

MODULE_DESCRIPTION("83HL: voti rail/clock/bus che Windows mantiene per il CDSP (NPU)");
MODULE_LICENSE("GPL");
