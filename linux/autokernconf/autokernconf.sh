#!/bin/bash
#
#  autoikernconf.sh : Kernal Automagical Configuration.
#
#  Copyright (C) 2000,2001,2007  Giacomo Catenazzi  <cate@debian.org>
#  This is free software, see GNU General Public License v2 for details.
#
#  Version: 3.1 (30.X.2007)
#  Maintainer: Giacomo Catenazzi <cate@debian.org>
#  Mirror: http://cateee.net/autokernconf/
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

CONF_AUTO=config.auto
AUTO_KAC=${1-detection.list}

IFSorig="$IFS"
LANG=C

Null=/dev/null
echo "#" > $CONF_AUTO
echo "# Automagically generated file. Do not edit!" >> $CONF_AUTO
echo "# (autoprobe v1.4)" >> $CONF_AUTO
echo "#" >> $CONF_AUTO
#--- (Configuration of Autoconfigure) ---#


#--- Definition of the Configuration Interface ---#

# 'comment'      writes comments on output file
# 'comment_warn' writes comments on output file and stdout
# 'debug'        writes comments in debug mode
#
# comment 'some comment'
# comment_warn 'some IMPORTANT comment and warnings'
# debug 'some usefull information for debug'
#
comment() {
    if [ "$PROVIDE_DEBUG" = "y" ]; then
	echo "# --- $@ ---" >> $CONF_AUTO
    fi
    echo "$@"
}
comment_err() {
    if [ "$PROVIDE_DEBUG" = "y" ]; then
	echo "# --- $@ ---" >> $CONF_AUTO
    fi
    echo "$@" 1>&2
}
debug() {
    if [ "$PROVIDE_DEBUG" =  "y" ]; then
	echo "## --- $@ ---" >> $CONF_AUTO
    fi
}
#
# 'define'    sets configuration (general funcions)
# 'found'     sets the value 'y/m' (driver detected)
# 'found_y'   sets the value 'y' (driver detected, forces built-in)
# 'found_m'   sets the value 'm' (driver detected, build as module)
# 'found_n'   sets the value 'n' (driver not needed)
# 'provide'   sets a PROVIDE_ variable (internal variable)
#
#  The priority is: y > m > n > 'other'
#
#  Rules:
#   string and and numeric variables: 'define'
#   important configuration (needed to boot): 'found_y'
#   normal detection: 'found'
#   ...: 'found_m'
#   not needed configuration: 'found_n'
#   not detected: '' (nothing)
#   internal uses: 'provide'
#
#  define    CONF  value
#  found     VAR
#  found_y   VAR_FOO
#  found_m   VAR_BAR
#  found_n   VAR_OTHER
#  provide   VAR_FOO_AND_BAR
#
define () {
    echo "$1=$2" >> $CONF_AUTO
    eval "$1=$2"
}
# "${!conf}" is available only on bash2. Too new for us!
found () {
    for conf in "$@" ; do
	if [ "$(eval echo \$$conf)" != "y" ]; then
	    define "$conf" y
	else
	    debug "$conf=y"
        fi
    done
}
found_y () {
    for conf in "$@" ; do
    	if [ "$(eval echo \$$conf)" != "y" ]; then
	    define "$conf" y
    	else
	    debug "$conf=y"
    	fi
    done
}
found_m () {
    for conf in "$@" ; do
    	if [ "$(eval echo \$$conf)" != "y"  -a  "$(eval echo \$$conf)" != "m" ]; then
	    define "$conf" m
    	else
	    debug "$conf=m"
    	fi
    done
}
found_n () {
    for conf in "$@" ; do
    	if [ -z "$(eval echo \$$conf)" ]; then
	    define "$conf" n
    	else
	    debug "$conf=n"
    	fi
    done
}
provide () {
    if [ "$(eval echo \$PROVIDE_$1)" != "y" ]; then
        eval "PROVIDE_$1=y"
	debug "PROVIDE_$1"
    fi
}
#--- (Definition of Configuration Interface) ---#


is_mid () {
    [ $( (echo "$1"; echo "$2"; echo "$3") | sort -n | head -2 | tail -1 ) = "$2" ]
}


#--- Parse "autoconfig.rules" ---#
debug 'Parse "autoconfig.rules"'


if grep -sqi '^pci [0-9]' $AUTO_KAC; then
    provide CONFIG_PCI
    found CONFIG_PCI
fi

pci () {
    if grep -sqe "^pci $1" $AUTO_KAC ; then
	shift
	found "$@"
    fi
}

usb () {
    line=$(grep -oe "^usb $1" $AUTO_KAC )
    if [ -n "$line" ] ; then
	bcd=$(echo "$line" | grep -o '....$' )
	if [ "$bcd" = "...." ] ; then
	    shift 3
	    found "$@"
	else
	    if is_mid "$bcd" "$2" "$3" ; then
	        shift 3
	        found "$@"
	    fi
	fi
    fi
}

ieee1394 () {
    if grep -sqe "^ie394 $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

ccw () {
    if grep -sqe "^ccw $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

ap () {
    if grep -sqe "^ap $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

acpi () {
    if grep -sqe  "^acpi $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

pnp () {
    if grep -sqe  "^pnp $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

serio () {
    if grep -sqe  "^serio $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

of () {
    if grep -sqe  "^of $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

vio () {
    if grep -sqe  "^vio $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}

pcmcia () {
    debug "pcmcia not implemented"
}

fs () {
    if grep -sqe  "^fs $1" $AUTO_KAC ; then
	shift
        found "$@"
    fi
}


module () {
    if grep -sqe  "^module $1" $AUTO_KAC ; then
        shift 2
        found "$@"
    fi
}


#----------#


drv () {
   [ "$1" = "pci"       ] && ( shift; pci	"$@" ; return )
   [ "$1" = "usb"       ] && ( shift; usb	"$@" ; return )
   [ "$1" = "ieee1394"  ] && ( shift; ieee1394	"$@" ; return )
   [ "$1" = "ccw"       ] && ( shift; ccw	"$@" ; return )
   [ "$1" = "ap"   	] && ( shift; ap 	"$@" ; return )
   [ "$1" = "acpi" 	] && ( shift; acpi 	"$@" ; return )
   [ "$1" = "pnp"  	] && ( shift; pnp 	"$@" ; return )
   [ "$1" = "serio" 	] && ( shift; serio 	"$@" ; return )
   [ "$1" = "of"   	] && ( shift; of 	"$@" ; return )
   [ "$1" = "vio"  	] && ( shift; vio 	"$@" ; return )
   [ "$1" = "fs"   	] && ( shift; fs 	"$@" ; return )
   [ "$1" = "module"    ] && ( shift; module    "$@" ; return )
}

comment 'Parsing configuration database....'
comment '.... [please wait] ....'
. /var/lib/lkddb/lkddb.data
comment 'Main detection finished'
#--- (Parse "autoconfig.rules") ---#



comment 'End of Autodetection'

exit 0


