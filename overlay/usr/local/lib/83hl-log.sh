# Funzione comune: monta la partizione 83HL-LOG della chiavetta e ne stampa il punto di montaggio.
# Il sistema live monta il disco INTERO su /cdrom, quindi la partizione non si puo' montare in modo normale
# ("Can't open blockdev"): in quel caso si passa da un loop con offset sullo stesso disco. MAI staccare la chiavetta.
log83_mount() {
  local dev m p d start size
  dev=$(blkid -L 83HL-LOG 2>/dev/null); [ -n "$dev" ] || return 1
  m=$(findmnt -nro TARGET -S "$dev" | head -1); [ -n "$m" ] && { echo "$m"; return 0; }
  m=$(findmnt -nro TARGET /mnt/83hl-log); [ -n "$m" ] && { echo "$m"; return 0; }
  mkdir -p /mnt/83hl-log
  mount "$dev" /mnt/83hl-log 2>/dev/null && { echo /mnt/83hl-log; return 0; }
  p=${dev##*/}; d=$(basename "$(readlink -f "/sys/class/block/$p/..")")
  start=$(cat "/sys/class/block/$p/start"); size=$(cat "/sys/class/block/$p/size")
  mount -o loop,offset=$((start*512)),sizelimit=$((size*512)) "/dev/$d" /mnt/83hl-log 2>/dev/null && { echo /mnt/83hl-log; return 0; }
  return 1
}
