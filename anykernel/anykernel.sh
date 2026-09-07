# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
properties() { '
kernel.string=Peridot Kernel (Droidspaces) by ZxAlif-ID
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=peridot
device.name2=peridot_global
supported.versions=
supported.patchlevels=
'; }

## AnyKernel install
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto

. tools/ak3-core.sh;

# init_boot detection (peridot pakai init_boot ramdisk)
if [ -L "/dev/block/bootdevice/by-name/init_boot_a" ] || \
   [ -L "/dev/block/by-name/init_boot_a" ]; then
    split_boot
    flash_boot
else
    dump_boot
    write_boot
fi
