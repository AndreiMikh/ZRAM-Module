OUT_DIR="/data/adb/modules/ZRAM-Module/webroot/tmp"
OUT_FILE="$OUT_DIR/status.json"

mkdir -p "$OUT_DIR"

algo_raw=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)
algorithm=$(echo "$algo_raw" | grep -o '\[[^]]*\]' | tr -d '[]')

swaps_line=$(grep zram0 /proc/swaps)
size=$(echo "$swaps_line" | awk '{print $3}')
used=$(echo "$swaps_line" | awk '{print $4}')

size_mb=$(echo "$size * 4 / 1024" | bc)
used_mb=$(echo "$used * 4 / 1024" | bc)

if [ "$used_mb" -gt 0 ]; then
  ratio=$(echo "scale=2; $size_mb / $used_mb" | bc)
else
  ratio="N/A"
fi

cat <<EOF > "$OUT_FILE"
{
  "algorithm": "${algorithm:-Unknown}",
  "size": "${size_mb:-0} MB",
  "used": "${used_mb:-0} MB",
  "ratio": "${ratio} : 1"
}
EOF
