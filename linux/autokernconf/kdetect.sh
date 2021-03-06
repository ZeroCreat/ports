#!/bin/bash
#
#  kdetect.sh : hardware detection
#
#  Copyright (C) 2000,2001,2007  Giacomo Catenazzi  <cate@debian.org>
#  This is free software, see GNU General Public License v2 for details.
#
#  Version: 2.0 (21.IX.2007)
#  Maintainer: Giacomo Catenazzi <cate@debian.org>
#  Mirror: http://people.debian.org/~cate/files/kernautoconfig/
#  Mailing List: kautoconfigure-devel@lists.sourceforge.net
#  Credits:
#    Peter Samuelson [scan_PCI function]
#    William Stearns and Andreas Schwab [bash v.1 support]
#    Andreas Jellinghaus
#
# This script try to autoconfigure the Linux kernel, detecting the
# hardware (devices, ...) and software (protocols, filesystems, ...).
# It uses soft detections: no direct IO access to unknow devices, thus
# it is always safe to run this script and it never hangs, but it cannot
# detect all hardware (mainly some very old hardware).
#
# Report errors, bugs, additions, wishes and comments <cate@debian.org>.
# 
# Usage:
#   General Hints:
#     you don't need super user privileges.
#     you can run this script on a target machine without the need of
#       the kernel sources.
#
# Extra information for the developers:
#   There are a lots of redundance: because user maybe has not already
#     installed the drivers (thus we use smart detection on PCI, USB,..)
#     and not all file methods are usable ('lspci' not installed,
#     '/proc' not mounted or 'dmesg' not usable).
#   We want to check the drivers that system needs, not the drivers
#     actually installed on actual system (in this case you should
#     simply check the 'System.map').
#
# This is a simple bash shell script. It use only the following external
#  program:
#   Req: bash[if,echo,test], grep/egrep, sed, uname, which, cp,mv,rm
#   Opt: dmesg
# and read this files:
#   Opt: /proc/*; /var/log/dmesg; /etc/fstab; linux/drivers/pci/pci.ids


#--- Configuration of kernautoconf ---#
IFS_orig="$IFS"
LANG=C
#--- (Configuration of Autoconfigure) ---#



#--- PCI ---#

echo '# PCI detection with lspci'
lspci -n -m | awk '\
BEGIN {FS=" " ; OFS=" "; } {
ORS=" "; print "pci"; pci_progif="00";
for (i = 3; i + offset <= NF; i = i + 1)  {
    if ($i ~ /^[^-]/) {
	if ($i ~ /\"\"/)
	    { print "0000"; }
        else
            { print $i;};
    } else if ($i ~ /^-p/) {
	pci_progif=substr($i,3,2);
    }
};
ORS="\n"; print $2 pci_progif;
}' | tr -d '"'


echo '# PCI detection with /sys'
[ -d /sys/bus/pci/devices/ ] && \
for dev in $(ls -U /sys/bus/pci/devices/) ; do
    vendor=$(cat "/sys/bus/pci/devices/$dev/vendor" | sed -ne 's/0x\([0-90-f]\{4\}\)/\1/p' -)
    device=$(cat "/sys/bus/pci/devices/$dev/device" | sed -ne 's/0x\([0-90-f]\{4\}\)/\1/p' -)
    svendor=$(cat "/sys/bus/pci/devices/$dev/subsystem_vendor" | sed -ne 's/0x\([0-90-f]\{4\}\)/\1/p' -)
    sdevice=$(cat "/sys/bus/pci/devices/$dev/subsystem_device" | sed -ne 's/0x\([0-90-f]\{4\}\)/\1/p' -)
    class=$(cat "/sys/bus/pci/devices/$dev/class" | sed -ne 's/0x\([0-90-f]\{6\}\)/\1/p' -)
    echo "pci $vendor $device $svendor $sdevice $class"
done

#--- USB ---#

echo '# USB detection using /sys'
[ -d /sys/bus/usb/devices/ ] && \
for dev in $(ls -U /sys/bus/usb/devices/) ; do
    vend="...."; product="...."; bcd="....";
    d_class=".."; d_subcl=".."; d_prot=".."; i_class=".."; i_subcl=".."; i_prot=".."
    [ -f "/sys/bus/usb/devices/$dev/idVendor" ]  &&  vend=$(cat "/sys/bus/usb/devices/$dev/idVendor")
    [ -f "/sys/bus/usb/devices/$dev/idProduct" ]  &&  product=$(cat "/sys/bus/usb/devices/$dev/idProduct")
    [ -f "/sys/bus/usb/devices/$dev/bcdDevice" ]  &&  bcd=$(cat "/sys/bus/usb/devices/$dev/bcdDevice")

    [ -f "/sys/bus/usb/devices/$dev/bDeviceClass" ] && d_class=$(cat "/sys/bus/usb/devices/$dev/bDeviceClass")
    [ -f "/sys/bus/usb/devices/$dev/bDeviceSubClass" ] && d_subcl=$(cat "/sys/bus/usb/devices/$dev/bDeviceSubClass")
    [ -f "/sys/bus/usb/devices/$dev/bDeviceProtocol" ] && d_prot=$(cat "/sys/bus/usb/devices/$dev/bDeviceProtocol")
    [ -f "/sys/bus/usb/devices/$dev/bInterfaceClass" ] && i_class=$(cat "/sys/bus/usb/devices/$dev/bInterfaceClass")
    [ -f "/sys/bus/usb/devices/$dev/bInterfaceSubClass" ] && i_subcl=$(cat "/sys/bus/usb/devices/$dev/bInterfaceSubClass")
    [ -f "/sys/bus/usb/devices/$dev/bInterfaceProtocol" ] && i_prot=$(cat "/sys/bus/usb/devices/$dev/bInterfaceProtocol")

   echo "usb $vend $product $d_class$d_subcl$d_prot $i_class$i_subcl$i_prot $bcd"
done


#-- IEEE1394 -- #

echo '# IEEE1394 detection with /sys'
[ -d  /sys/bus/ieee1394/devices/ ] && \
for dev in $(ls -U /sys/bus/ieee1394/devices/) ; do
    if [ -f "/sys/bus/ieee1394/devices/$dev/vendor_id" ] ; then
        vend=$(cat "/sys/bus/ieee1394/devices/$dev/vendor_id" | tail -c +3 -)
        echo "ieee1394 $vend xxxxxx xxxxxx xxxxxx"
    fi
done

#

#-- ACPI -- #

echo '# ACPI detection with /sys'
[ -d  /sys/bus/acpi/devices/ ] && \
for dev in $(ls -U /sys/bus/acpi/devices/) ; do
    if [ -f "/sys/bus/acpi/devices/$dev/hid" ] ; then
	id=$(cat "/sys/bus/acpi/devices/$dev/hid")
        echo "acpi $id"
    fi
done

#-- PNP -- #

echo '# PNP detection with /sys'
[ -d  /sys/bus/pnp/devices/ ] && \
for dev in $(ls -U /sys/bus/pnp/devices/) ; do
    id=$(cat "/sys/bus/pnp/devices/$dev/id")
    echo "pnp $id"
done


#-- serio -- #

echo '# serio detection with /sys'
[ -d /sys/bus/serio/devices/ ] && \
for dev in $(ls -U /sys/bus/serio/devices/) ; do
    typ=$(cat "/sys/bus/serio/devices/$dev/id/type")
    proto=$(cat "/sys/bus/serio/devices/$dev/id/proto")
    id=$(cat "/sys/bus/serio/devices/$dev/id/id")
    extra=$(cat "/sys/bus/serio/devices/$dev/id/extra")
    echo "serio $typ $proto $id $extra"
done



#--- FS ---#

echo '# FS detection using mount'
for fs in $(mount | sed -ne 's/^.*type \([^ ]*\).*$/\1/p' -  | sort -u ) ; do
    echo "fs $fs"
done
echo '# FS detection using /etc/fstab'
[ -f /etc/fstab ] && \
for fs in $(grep -v '^#' /etc/fstab | sed -nre 's/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+)[[:space:]]+.*$/\1/p' - | sort -u ) ; do
    echo "fs $fs"
done


#--- kernel modules ---#

echo '# kernel modules detection using lsmod and /proc/modules'
for module in $( (cat /proc/modules; /sbin/lsmod) | tail -n +2 | cut -d " " -f 1 | sort -u ) ; do
    echo "module $module"
done


#--- Check files ---#
if [ ! -d /proc ]; then
    comment_err '*** Warning: /proc not found!'
fi
if [ ! -d /sys ]; then
    comment_err '*** Warning: /sys not found!'
fi

#--- (Check files) ---#
