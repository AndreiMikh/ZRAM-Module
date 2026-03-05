MODDIR="/data/adb/modules/ZRAM-Module"
CONFIG_FILE="$MODDIR/config.prop"

# Load Configuration
if [ -f "$CONFIG_FILE" ]; then
  . "$CONFIG_FILE"
else
  echo "Config.prop is Not Found, Exit" >&2
  exit 1
fi

# Overload ZRAM
echo "Deactivate the Current ZRAM..."
swapoff /dev/block/zram0

echo "Reset ZRAM Parameters..."
echo 1 > /sys/block/zram0/reset
echo 0 > /sys/block/zram0/disksize
echo 8 > /sys/block/zram0/max_comp_streams
echo "$ZRAM_ALGO" > /sys/block/zram0/comp_algorithm
echo "$ZRAM_SIZE" > /sys/block/zram0/disksize

echo "Create a ZRAM and Enable it..."
mkswap /dev/block/zram0
swapon /dev/block/zram0

echo "ZRAM Thermal Heavy Load Complete"
