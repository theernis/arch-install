#!/bin/bash

### functions
###----------

default_yes() {
	ANSWER=""
	read -p "$1 (Y/n): " ANSWER
	case "$ANSWER" in
		[yY] ) ANSWER="y";;
		[nN] ) ANSWER="n";;
		*    ) ANSWER="y";;
	esac
	eval "$2='$ANSWER'"
}

default_no() {
	ANSWER=""
	read -p "$1 (N/y): " ANSWER
	case "$ANSWER" in
		[yY] ) ANSWER="y";;
		[nN] ) ANSWER="n";;
		*    ) ANSWER="n";;
	esac
	eval "$2='$ANSWER'"
}

yes_or_no() {
	ANSWER=""
	read -p "$1 (y/n): " ANSWER
	case "$ANSWER" in
		[yY] ) ANSWER="y";;
		[nN] ) ANSWER="n";;
		*    ) yes_or_no $1 ANSWER;;
	esac
	eval "$2='$ANSWER'"
}

disk_check() {
	DISK=$1

	if [[ "$DISK" != "/dev/sd"? ]]; then
		echo "$DISK unexpected format, exiting"
		exit
	fi

	if lsblk "$DISK" > /dev/null 2>&1; then
		echo "$DISK exists, success"
	else
		echo "$DISK NOT FOUND"
		echo "exiting"
		exit
	fi
}


### inputs
###-------

#debug mode
default_yes "debug mode" debug_mode

#selecting disk for installation
lsblk
read -p "select device to install on (example and default /dev/sdb): " disk
echo $disk
case "$disk" in
	"" ) disk="/dev/sdb";;
	*  ) disk_check $disk;;
esac

#wipe (N/y)
default_no "wipe disk before installation" wipe

#region and city
ls -l /usr/share/zoneinfo/ | grep '^d' | awk '{print $NF}'
read -p "region (default Europe): " region
if [ -z "$region"]; then
	region="Europe"
fi
if [ ! -d /usr/share/zoneinfo/$region/ ]; then
	exit
fi
ls /usr/share/zoneinfo/$region/
read -p "city (default Vilnius): " city
if [ -z "$city" ]; then
	city="Vilnius"
fi
if [ ! -f /usr/share/zoneinfo/$region/$city ]; then
	exit
fi

#localine
cat /etc/locale.gen | sed 's/#//g' | grep -E ' UTF-8' | cut -d " " -f 1
read -p "localine (default en_US.UTF-8):"

case "$debug_mode" in 
	y ) exit ;;
	* ) ;;
esac
### Install Base System
###--------------------

#wipe
case "$wipe" in
	y ) dd if=/dev/zero of=$disk status=progress && sync;;
	* ) ;;
esac

#partition
sgdisk -o -n 1:0:+10M -t 1:EF02 -n 2:0:+500M -t 2:EF00 -n 3:0:0 -t 3:8300 $disk

#format
mkfs.fat -F32 $disk"2"
mkfs.ext4 -F $disk"3"

#mount
mkdir -p /mnt/usb
umount $disk"3"
mount $disk"3" /mnt/usb
mkdir /mnt/usb/boot
umount $disk"2"
mount $disk"2" /mnt/usb/boot

#pacstrap
pacstrap /mnt/usb linux linux-firmware base vim 

#fstab
genfstab -U /mnt/usb > /mnt/usb/etc/fstab


### Configure Base System
###----------------------


### Optional configurations
###------------------------