#!/bin/bash

### functions
###----------

default_yes() {
	TEXT=$1
	ANSWER=""
	read -p "$TEXT (Y/n): " ANSWER
	case "$ANSWER" in
		[yY] ) ANSWER="y";;
		[nN] ) ANSWER="n";;
		*    ) ANSWER="y";;
	esac
	eval "$2='$ANSWER'"
}

default_no() {
	TEXT=$1
	ANSWER=""
	read -p "$TEXT (N/y): " ANSWER
	case "$ANSWER" in
		[yY] ) ANSWER="y";;
		[nN] ) ANSWER="n";;
		*    ) ANSWER="n";;
	esac
	eval "$2='$ANSWER'"
}

yes_or_no() {
	TEXT=$1
	ANSWER=""
	read -p "$TEXT (y/n): " ANSWER
	case "$ANSWER" in
		[yY] ) ANSWER="y";;
		[nN] ) ANSWER="n";;
		*    ) yes_or_no $TEXT ANSWER;;
	esac
	eval "$2='$ANSWER'"
}

ask_default() {
	TEXT=$1
	DEFAULT=$2
	ANSWER=""
	read -p "$TEXT (default $DEFAULT): " ANSWER
	case "$ANSWER" in
		"" ) ANSWER=$DEFAULT;;
		*  ) ;;
	esac
	eval "$3='$ANSWER'"
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

read_password() {
	NAME=$1
	DEFAULT=$2
	PASSWORD=""

	read -p "enter $NAME password (default $DEFAULT)" -s PASSWD1
	echo
	if [ -z "$PASSWD1" ]; then
		PASSWORD=$DEFAULT
	else
		read -p "enter password again" -s PASSWD2
		echo
		if [ "$PASSWD1" = "$PASSWD2" ]; then
			PASSWORD=$PASSWD1
		else
			echo "passwords do not match, try again"
			read_password $NAME $DEFAULT PASSWORD
		fi
	fi

	eval "$3='$PASSWORD'"
}


### inputs
###-------

#debug mode
default_yes "debug mode" debug_mode

#selecting disk for installation
lsblk
ask_default "select device to install on" "/dev/sdb" disk
disk_check $disk

#wipe (N/y)
default_no "wipe disk before installation" wipe

#region and city
ls -l /usr/share/zoneinfo/ | grep '^d' | awk '{print $NF}'
ask_default "region" "Europe" region
if [ ! -d /usr/share/zoneinfo/$region/ ]; then
	exit
fi
ls /usr/share/zoneinfo/$region/
ask_default "city" "Vilnius" city
if [ ! -f /usr/share/zoneinfo/$region/$city ]; then
	exit
fi

#localine
cat /etc/locale.gen | sed 's/#//g' | grep -E ' UTF-8' | cut -d " " -f 1
ask_default "localine" "en_US.UTF-8" localine
localine_found=0
while read -r line; do
	if [ "$line" = "$localine" ]; then
		localine_found=1
	fi
done < <(cat /etc/locale.gen | sed 's/#//g' | grep -E ' UTF-8' | cut -d " " -f 1)
case "$localine_found" in
	1 ) ;;
	* ) echo "unexpected input, exiting"; exit;;
esac

#hostname
ask_default "hostname" "archlinux" hostname
if [[ ! "$hostname" =~ ^[a-zA-Z0-9]+$ ]]; then
	echo "unexpected formatting, exiting"
	exit
fi

#root password
read_password "root" "password" root_password

#username
ask_default "username" "user" user_name

#user password
read_password "user" "user" user_password

#noatime
default_no "noatime configuration" noatime

#journal
default_no "journal configurations" journal

#mkinitcpio
default_no "mkinitcpio configurations" mkinitcpio

#nomodoset
default_no "nomodoset configurations" nomodoset

#microcode
default_no "microcode configurations" microcode

#interface names
default_no "interface names configurations" interface_names


### Install Base System
###--------------------

#wipe
case "$wipe" in
	y ) dd if=/dev/zero of=$disk bs=1M status=progress && sync ; [[ $debug_mode == "y" ]] && sleep 10 ;;
	* ) ;;
esac

#partition
sgdisk -o -n 1:0:+10M -t 1:EF02 -n 2:0:+500M -t 2:EF00 -n 3:0:0 -t 3:8300 $disk
partprobe
[[ $debug_mode == "y" ]] && sleep 10

#format
umount $disk"2"
umount $disk"3"
mkfs.fat -F32 $disk"2"
mkfs.ext4 -F  $disk"3"
[[ $debug_mode == "y" ]] && sleep 10

#mount
mkdir -p /mnt/usb
mount $disk"3" /mnt/usb
mkdir /mnt/usb/boot
mount $disk"2" /mnt/usb/boot
[[ $debug_mode == "y" ]] && sleep 10

#pacstrap
pacstrap /mnt/usb linux linux-firmware base vim
[[ $debug_mode == "y" ]] && sleep 10

#fstab
genfstab -U /mnt/usb > /mnt/usb/etc/fstab
[[ $debug_mode == "y" ]] && sleep 10


### Configure Base System
###----------------------

#locale
arch-chroot /mnt/usb ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime
current_locale=$(arch-chroot /mnt/usb/ cat /etc/locale.gen)
new_locale=""
while IFS= read -r line; do
	if [[ $line == *"$localine"* ]]; then
		new_locale+="$localine UTF-8\n"
	else
		if [[ $line == \#* ]]; then
			new_locale+="$line\n"
		else
			new_locale+="#$line\n"
		fi
	fi
done <<< "$current_locale"
echo -e "$new_locale" > arch-chroot /mnt/usb /etc/locale.gen
arch-chroot /mnt/usb locale-gen
echo LANG=$localine > arch-chroot /mnt/usb /etc/locale.conf
[[ $debug_mode == "y" ]] && sleep 10

#time/date
arch-chroot /mnt/usb hwclock --systohc

#hostname
echo $hostname > arch-chroot /mnt/usb /etc/hostname
hosts_file=""
hosts_file+="127.0.0.1  localhost\n"
hosts_file+="::1        localhost\n"
hosts_file+="127.0.1.1  hostname.localdomain  hostname\n"
echo -e $hosts_flie > arch-chroot /mnt/usb /etc/hosts

#password
echo -e "$root_password\n$root_password\n" | arch-chroot /mnt/usb passwd root
[[ $debug_mode == "y" ]] && sleep 10

#bootloader
arch-chroot /mnt/usb pacman --noconfirm -S grub efibootmgr
arch-chroot /mnt/usb grub-install --target=i386-pc --recheck $disk
arch-chroot /mnt/usb grub-install --target=x86_64-efi --efi-directory /boot --recheck --removable
arch-chroot /mnt/usb grub-mkconfig -o /boot/grub/grub.cfg
[[ $debug_mode == "y" ]] && sleep 10

#networking
ethernet_network=""
ethernet_network+="[Match]\n"
ethernet_network+="Name=en*\n"
ethernet_netwokr+="Name=eth*\n\n"
ethernet_network+="[Network]\n"
ethernet_network+="DHCP=yes\n"
ethernet_network+="IPv6PrivacyExtensions=yes\n\n"
ethernet_network+="[DHCPv4]\n"
ethernet_network+="RouteMetric=10\n\n"
ethernet_network+="[IPv6AcceptRA]\n"
ethernet_network+="RouteMetric=10\n"
echo -e $ethernet_network > arch-chroot /mnt/usb /etc/systemd/network/10-ethernet.network
arch-chroot /mnt/usb systemctl enable systemd-networkd.service
arch-chroot /mnt/usb pacman --noconfirm -S iwd
arch-chroot /mnt/usb systemctl enable iwd.service
wireless_network=""
wireless_network+="[Match]\n"
wireless_network+="Name=wl*\n\n"
wireless_network+="[Network]\n"
wireless_network+="DHCP=yes\n"
wireless_network+="IPv6PrivacyExtensions=yes\n\n"
wireless_network+="[DHCPv4]\n"
wireless_network+="RouteMetric=20\n\n"
wireless_network+="[IPv6AcceptRA]\n"
wireless_network+="RouteMetric=20\n"
echo -e $wireless_network > arch-chroot /mnt/usb /etc/systemd/network/20-wifi.network
arch-chroot /mnt/usb systemctl enable systemd-resolved.service
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/usb/etc/resolv.conf
arch-chroot /mnt/usb systemctl enable systemd-timesyncd.service
[[ $debug_mode == "y" ]] && sleep 10

#user
arch-chroot /mnt/usb useradd -m $user_name
echo -e "$user_password\n$user_password\n" | arch-chroot /mnt/usb passwd $user_name
arch-chroot /mnt/usb groupadd wheel
arch-chroot /mnt/usb usermod -aG wheel user
[[ $debug_mode == "y" ]] && sleep 10

#sudo
arch-chroot /mnt/usb pacman --noconfirm -S sudo
echo "%sudo ALL=(ALL) ALL" > arch-chroot /mnt/usb tee -a /etc/sudoers.d/10-sudo 
arch-chroot /mnt/usb groupadd sudo
arch-chroot /mnt/usb usermod -aG sudo $user_name
arch-chroot /mnt/usb pacman --noconfirm -S polkit
[[ $debug_mode == "y" ]] && sleep 10


### Optional configurations
###------------------------

#noatime
if [[ $noatime == "y" ]]; then
	arch-chroot /mnt/usb sed -i "s/relatime/noatime/g" /etc/fstab
	arch-chroot /mnt/usb sed -i "s/atime/noatime/g" /etc/fstab
	[[ $debug_mode == "y" ]] && sleep 10
fi

#journal
if [[ $journal == "y" ]]; then
	journal_file=""
	journal_file+="[Journal]\n"
	journal_file+="Storage=volatile\n"
	journal_file+="SystemMaxUse=16M"
	journal_file+="RuntimeMaxUse=32M"
	arch-chroot /mnt/usb mkdir -p /etc/systemd/journald.conf.d
	arch-chroot /mnt/usb touch /etc/systemd/journald.conf.d/10-volatile.conf

	[[ $debug_mode == "y" ]] && sleep 10
fi

#mkinitcpio
if [[ $mkinitcpio == "y" ]]; then
	arch-chroot /mnt/usb sed -i "/^HOOKS=/ s/.*HOOKS=(base udev modconf block filesystems keyboard fsck)/" /etc/mkinitcpio.conf
	arch-chroot /mnt/usb sed -i "/^PRESETS=/ s/.*PRESETS=('default')/" /etc/mkinitcpio.d/linux.preset
	arch-chroot /mnt/usb rm /boot/initramfs-linux-fallback.img
	arch-chroot /mnt/usb mkinitcpio -P
	arch-chroot /mnt/usb grub-mkconfig -o /boot/grub/grub.cfg
fi

#nomodoset
if [[ $nomodoset == "y" ]]; then
	arch-chroot /mnt/usb cp /boot/grub/grub.cfg /etc/grub.d/40_custom
	arch-chroot /mnt/usb sed -i 's|menuentry \x27Arch\(.*)\x27 \(.*)|menuentry \x27Arch \x27\1 (nomodeset)\x27 \2|' /etc/grub.d/40_custom
	arch-chroot /mnt/usb sed -i '/\/vmlinuz-linux/ s/$/ nomodeset/' /etc/grub.d/40_custom
	arch-chroot /mnt/usb grub-mkconfig -o /boot/grub/grub.cfg
fi

#microcode
if [[ $microcode == "y" ]]; then
	[[ $nomodeset != "y" ]] && arch-chroot /mnt/usb cp /boot/grub/grub.cfg /etc/grub.d/40_custom #copy only if it wasnt already copied for nomodeset
	arch-chroot /mnt/usb pacman -S amd-ucode intel-ucode
	arch-chroot /mnt/usb -i 's/initrd/initrd \/intel-ucode.img \/amd-ucode.img/g' /etc/grub.d/40_custom
	arch-chroot /mnt/usb grub-mkconfig -o /boot/grub/grub.cfg
fi

#inteface names
if [[ $interface_names == "y" ]]; then
	arch-chroot /mnt/usb ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
fi
