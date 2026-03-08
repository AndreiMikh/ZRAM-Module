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
    ZRAM_ALGO="lz4kd"
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
  log "swapoff success"
else
  log "swapoff failed or ineffective"
fi

log "rmmod zram"
if rmmod zram 2>>"$LOG_FILE"; then
  log "rmmod zram success"
else
  log "rmmod zram failed or builtin"
fi

log "wait for 5 seconds..."
sleep 5

log "insmod zram.ko"
if insmod $MODDIR/zram/zram.ko 2>>"$LOG_FILE"; then
  log "zram.ko 加载成功"
else
  log "zram.ko 加载失败"
fi

log "等待5秒..."
sleep 5

log "zram0 reset"
if echo '1' > /sys/block/zram0/reset 2>>"$LOG_FILE"; then
  log "zram0 reset 成功"
else
  log "zram0 reset 失败"
fi

log "zram0 disksize 0"
if echo '0' > /sys/block/zram0/disksize 2>>"$LOG_FILE"; then
  log "zram0 disksize 清零成功"
else
  log "zram0 disksize 清零失败（可忽略）"
fi

log "zram0 max_comp_streams 8"
if echo '8' > /sys/block/zram0/max_comp_streams 2>>"$LOG_FILE"; then
  log "zram0 max_comp_streams 设置成功"
else
  log "zram0 max_comp_streams 设置失败"
fi

log "设置压缩算法 $ZRAM_ALGO"
if echo "$ZRAM_ALGO" > /sys/block/zram0/comp_algorithm 2>>"$LOG_FILE"; then
  log "压缩算法已设置 $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
else
  log "压缩算法设置失败，当前: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"
fi

log "zram0 disksize $ZRAM_SIZE"
if echo "$ZRAM_SIZE" > /sys/block/zram0/disksize 2>>"$LOG_FILE"; then
  log "zram0 disksize 设置成功"
else
  log "zram0 disksize 设置失败"
fi

log "mkswap /dev/block/zram0"
if mkswap /dev/block/zram0 > /dev/null 2>>"$LOG_FILE"; then
  log "mkswap 成功"
else
  log "mkswap 失败"
fi

log "swapon /dev/block/zram0"
if swapon /dev/block/zram0 > /dev/null 2>>"$LOG_FILE"; then
  log "swapon 成功"
else
  log "swapon 失败"
fi

# ------------- 重点优化：最后再清理多余zram设备 -------------
log "=== 最后清理多余zram设备（zram1/zram2…） ==="
for zdev in /dev/block/zram*; do
  [ "$zdev" = "/dev/block/zram0" ] && continue
  [ -b "$zdev" ] || continue
  log "处理 $zdev ..."
  i=0
  while grep -qw "$zdev" /proc/swaps && [ $i -lt 5 ]; do
    log "swapoff $zdev (第$((i+1))次)"
    swapoff "$zdev"
    sleep 1
    i=$((i+1))
  done
  zname=$(basename "$zdev")
  [ -e "/sys/block/$zname/reset" ] && echo 1 > "/sys/block/$zname/reset" && log "reset $zname"
  [ -e "/sys/block/$zname/hot_remove" ] && echo 1 > "/sys/block/$zname/hot_remove" && log "hot_remove $zname"
done
log "多余zram设备清理完成"

# --------- ZRAM与内存状态日志 ---------
log "--------- ZRAM与内存状态 ---------"
log "zram0 当前支持算法: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null)"

if grep -q zram0 /proc/swaps; then
  awk '/zram0/ {printf "zram0 Swap: 设备=%s 类型=%s 总=%.2fGiB 已用=%.2fMiB 优先级=%s", $1, $2, $3/1048576, $4/1024, $5}' /proc/swaps | while read line; do log "$line"; done
else
  log "zram0 不在 /proc/swaps"
fi

MEM_LINE="$(free -h | awk '/^Mem:/ {printf "Mem: 总=%s 已用=%s 可用=%s", $2, $3, $7}')"
SWAP_LINE="$(free -h | awk '/^Swap:/ {printf "Swap: 总=%s 已用=%s 可用=%s", $2, $3, $4}')"
log "$MEM_LINE"
log "$SWAP_LINE"
log "----------------------------------"
log "=== ZRAM-Module 服务完成 ==="
