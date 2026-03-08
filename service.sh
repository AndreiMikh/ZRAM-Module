MODDIR=${0%/*}
LOG_FILE="$MODDIR/zram_module.log"
CONFIG_FILE="$MODDIR/config.prop"
TEE=/system/bin/tee
[ -x "$TEE" ] || TEE=tee

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | $TEE -a "$LOG_FILE"
}

log "======================================="
log "====== service start：$(date '+%Y-%m-%d %H:%M:%S') ======"
log "======================================="

# ---------- reading configuration ----------
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    ZRAM_ALGO="lz4"
    ZRAM_SIZE="8589934592"
fi

log "read configuration: ZRAM_ALGO=$ZRAM_ALGO, ZRAM_SIZE=$ZRAM_SIZE"
log "=== service start ==="
log "wait for the system initialization to complete..."
sleep 30

log "load zstdn.ko..."
if insmod $MODDIR/zram/zstdn.ko 2>>"$LOG_FILE"; then
  log "zstdn.ko loaded successfully"
else
  log "zstdn.ko load failed"
fi

log "swapoff /dev/block/zram0"
if swapoff /dev/block/zram0 2>>"$LOG_FILE"; then
  log "swapoff loaded successfully"
else
  log "swapoff failed or ineffective"
fi

log "rmmod zram"
if rmmod zram 2>>"$LOG_FILE"; then
  log "rmmod zram successfull"
else
  log "rmmod zram failed or builtin"
fi

log "wait for 5 seconds..."
sleep 5

log "insmod zram.ko"
if insmod $MODDIR/zram/zram.ko 2>>"$LOG_FILE"; then
  log "zram.ko loaded successfully"
else
  log "zram.ko failed to load"
fi

log "please wait..."
sleep 5

log "zram0 reset..."
if echo '1' > /sys/block/zram0/reset 2>>"$LOG_FILE"; then
  log "zram0 reset successfully"
else
  log "zram0 reset failed"
fi

log "zram0 disksize 0..."
if echo '0' > /sys/block/zram0/disksize 2>>"$LOG_FILE"; then
  log "zram0 disksize was successful"
else
  log "zram0 disksize clearance failed, neglegible"
fi

log "zram0 maximum compression streams 8..."
if echo '8' > /sys/block/zram0/max_comp_streams 2>>"$LOG_FILE"; then
  log "zram0 maximum compression streams set successfully"
else
  log "zram0 maximum compression streams failed to set up"
fi

log "set compression algorithm $ZRAM_ALGO"
if echo "$ZRAM_ALGO" > /sys/block/zram0/comp_algorithm 2>>"$LOG_FILE"; then
  log "compression algorithm has been set $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
else
  log "compression algorithm setting failed，current: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
fi

log "zram0 disksize $ZRAM_SIZE"
if echo "$ZRAM_SIZE" > /sys/block/zram0/disksize 2>>"$LOG_FILE"; then
  log "zram0 disksize setting successfully"
else
  log "zram0 disksize setting failed"
fi

log "mkswap /dev/block/zram0"
if mkswap /dev/block/zram0 > /dev/null 2>>"$LOG_FILE"; then
  log "mkswap success"
else
  log "mkswap failed"
fi

log "swapon /dev/block/zram0"
if swapon /dev/block/zram0 > /dev/null 2>>"$LOG_FILE"; then
  log "swapon success"
else
  log "swapon failed"
fi

# ------------- key optimization: clean up the excess zram -------------
log "=== finally, clean up excess zram（zram1/zram2） ==="
for zdev in /dev/block/zram*; do
  [ "$zdev" = "/dev/block/zram0" ] && continue
  [ -b "$zdev" ] || continue
  log "treatment $zdev ..."
  i=0
  while grep -qw "$zdev" /proc/swaps && [ $i -lt 5 ]; do
    log "swapoff $zdev (first$((i+1))second)"
    swapoff "$zdev"
    sleep 1
    i=$((i+1))
  done
  zname=$(basename "$zdev")
  [ -e "/sys/block/$zname/reset" ] && echo 1 > "/sys/block/$zname/reset" && log "reset $zname"
  [ -e "/sys/block/$zname/hot_remove" ] && echo 1 > "/sys/block/$zname/hot_remove" && log "hot_remove $zname"
done
log "The excess zram equipment is cleaned up"

# --------- zram and memory status logs ---------
log "--------- zram vs memory state ---------"
log "zram0 algorithms are currently supported: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"

if grep -q zram0 /proc/swaps; then
  awk '/zram0/ {printf "zram0 Swap: equipment=%s type=%s total=%.2fGiB used=%.2fMiB priority=%s", $1, $2, $3/1048576, $4/1024, $5}' /proc/swaps | while read line; do log "$line"; done
else
  log "zram0 not there /proc/swaps"
fi

MEM_LINE="$(free -h | awk '/^Mem:/ {printf "Mem: total=%s used=%s available=%s", $2, $3, $7}')"
SWAP_LINE="$(free -h | awk '/^Swap:/ {printf "Swap: total=%s used=%s available=%s", $2, $3, $4}')"
log "$MEM_LINE"
log "$SWAP_LINE"
log "----------------------------------"
log "=== service complete ==="
