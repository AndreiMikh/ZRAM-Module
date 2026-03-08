# Automatically Obtain the Module Name and Path
MODNAME="$(basename "$MODPATH")"
OLD_MODPATH="/data/adb/modules/$MODNAME"

# The Current and Legacy Module ZRAM Paths
ZRAM_DIR="$MODPATH/zram"
OLD_ZRAM_DIR="$OLD_MODPATH/zram"

ui_print "============="
ui_print "ZRAM Addon Module"
ui_print "============="

ui_print ">> Check if the ZRAM Folder for the Installed Module Exists..."

if [ -d "$OLD_ZRAM_DIR" ]; then
  ui_print ">> The Old Module ZRAM Folder has been Detected, Copied to the Retained File..."
  mkdir -p "$ZRAM_DIR"
  cp -af "$OLD_ZRAM_DIR/." "$ZRAM_DIR/"
  ui_print ">> ✅ File Copied"
else
  ui_print ">> The Old Module ZRAM Folder is Not Detected, Skipping Copying"
fi
