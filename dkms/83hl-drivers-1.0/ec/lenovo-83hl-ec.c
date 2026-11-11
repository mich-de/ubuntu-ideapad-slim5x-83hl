// SPDX-License-Identifier: GPL-2.0-only
/*
 * Lenovo IdeaPad Slim 5x 14Q8X9 (83HL) embedded controller: monitor di sola lettura (hwmon).
 *
 * Protocollo ricavato dal DSDT (\_SB.I2C6, connessione ENE9, I2C 0x60 a 100 kHz, metodi ECNR/ECNW):
 *   lettura registro:  write [0x62, 0xB0, reg, 0, 0, 0]  poi  read 6 byte dal comando 0x61 (byte 0 = valore)
 *   scrittura:         write [0x62, 0xB1, reg, val, 0, 0]   (NON usata: il driver non scrive mai registri)
 * Registri: 0x90-0x95 temperature (gradi C), 0x9A/0x9B giri ventola 1, 0x9C/0x9D giri ventola 2,
 *           0x9E/0x9F e 0xA0/0xA1 giri obiettivo. La ventola resta gestita dall'EC.
 */
#include <linux/hwmon.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/delay.h>

#define EC_CMD_WRITE	0x62
#define EC_CMD_READ	0x61
#define EC_OP_RDREG	0xb0

#define EC_REG_TEMP(n)	(0x90 + (n))	/* n = 0..5 */
#define EC_REG_FAN_L(n)	(0x9a + 2 * (n))
#define EC_REG_TGT_L(n)	(0x9e + 2 * (n))

static unsigned int delay_us = 10000;
module_param(delay_us, uint, 0644);
MODULE_PARM_DESC(delay_us, "pausa tra scrittura richiesta e lettura risposta (us)");

struct l83hl_ec {
	struct i2c_client *client;
	struct mutex lock;
};

static int l83hl_ec_read(struct l83hl_ec *ec, u8 reg, u8 *raw)
{
	u8 req[5] = { EC_OP_RDREG, reg, 0, 0, 0 };
	u8 buf[6];
	int ret;

	mutex_lock(&ec->lock);
	ret = i2c_smbus_write_i2c_block_data(ec->client, EC_CMD_WRITE, sizeof(req), req);
	if (ret >= 0) {
		/* l'EC (firmware ENE) ha bisogno di tempo per preparare la risposta: senza pausa legge solo zeri */
		usleep_range(delay_us, delay_us + 2000);
		ret = i2c_smbus_read_i2c_block_data(ec->client, EC_CMD_READ, sizeof(buf), buf);
	}
	mutex_unlock(&ec->lock);
	if (ret < 0)
		return ret;
	if (ret != sizeof(buf))
		return -EIO;
	if (raw)
		memcpy(raw, buf, sizeof(buf));
	return buf[0];
}

static int l83hl_ec_read16(struct l83hl_ec *ec, u8 reg_lo)
{
	int lo, hi;

	lo = l83hl_ec_read(ec, reg_lo, NULL);
	if (lo < 0)
		return lo;
	hi = l83hl_ec_read(ec, reg_lo + 1, NULL);
	if (hi < 0)
		return hi;
	return (hi << 8) | lo;
}

static umode_t l83hl_ec_is_visible(const void *data, enum hwmon_sensor_types type, u32 attr, int ch)
{
	return 0444;
}

static int l83hl_ec_hwmon_read(struct device *dev, enum hwmon_sensor_types type, u32 attr, int ch, long *val)
{
	struct l83hl_ec *ec = dev_get_drvdata(dev);
	int ret;

	switch (type) {
	case hwmon_temp:
		ret = l83hl_ec_read(ec, EC_REG_TEMP(ch), NULL);
		if (ret < 0)
			return ret;
		*val = ret * 1000;
		return 0;
	case hwmon_fan:
		ret = l83hl_ec_read16(ec, attr == hwmon_fan_target ? EC_REG_TGT_L(ch) : EC_REG_FAN_L(ch));
		if (ret < 0)
			return ret;
		*val = ret;
		return 0;
	default:
		return -EOPNOTSUPP;
	}
}

static const struct hwmon_channel_info * const l83hl_ec_info[] = {
	HWMON_CHANNEL_INFO(temp, HWMON_T_INPUT, HWMON_T_INPUT, HWMON_T_INPUT,
			   HWMON_T_INPUT, HWMON_T_INPUT, HWMON_T_INPUT),
	HWMON_CHANNEL_INFO(fan, HWMON_F_INPUT | HWMON_F_TARGET, HWMON_F_INPUT | HWMON_F_TARGET),
	NULL
};

static const struct hwmon_ops l83hl_ec_ops = {
	.is_visible = l83hl_ec_is_visible,
	.read = l83hl_ec_hwmon_read,
};

static const struct hwmon_chip_info l83hl_ec_chip = {
	.ops = &l83hl_ec_ops,
	.info = l83hl_ec_info,
};

static int l83hl_ec_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct device *hwmon;
	struct l83hl_ec *ec;
	u8 raw[6];
	int ret;

	ec = devm_kzalloc(dev, sizeof(*ec), GFP_KERNEL);
	if (!ec)
		return -ENOMEM;
	ec->client = client;
	mutex_init(&ec->lock);

	ret = l83hl_ec_read(ec, EC_REG_TEMP(0), raw);
	if (ret < 0)
		return dev_err_probe(dev, ret, "EC non risponde\n");
	dev_info(dev, "EC Lenovo 83HL: reg 0x90 -> %6ph, ventola1 %d giri/min\n", raw,
		 l83hl_ec_read16(ec, EC_REG_FAN_L(0)));

	hwmon = devm_hwmon_device_register_with_info(dev, "lenovo_83hl_ec", ec, &l83hl_ec_chip, NULL);
	return PTR_ERR_OR_ZERO(hwmon);
}

static const struct of_device_id l83hl_ec_of_match[] = {
	{ .compatible = "lenovo,ideapad-slim5x-83hl-ec" },
	{ }
};
MODULE_DEVICE_TABLE(of, l83hl_ec_of_match);

static const struct i2c_device_id l83hl_ec_id[] = {
	{ "83hl-ec" },
	{ }
};
MODULE_DEVICE_TABLE(i2c, l83hl_ec_id);

static struct i2c_driver l83hl_ec_driver = {
	.driver = {
		.name = "lenovo-83hl-ec",
		.of_match_table = l83hl_ec_of_match,
	},
	.probe = l83hl_ec_probe,
	.id_table = l83hl_ec_id,
};
module_i2c_driver(l83hl_ec_driver);

MODULE_DESCRIPTION("Lenovo IdeaPad Slim 5x (83HL) EC: temperature e giri ventola (sola lettura)");
MODULE_LICENSE("GPL");
