#!/bin/bash

case $(id -u) in
	0)
		;;
	*)
		echo "this script needs root privileges, please run this script with sudo" ;;
esac

print_help() {
	echo "options:"
	echo "-h, --help		show this"
	echo "-d, --debug=[yYnN]	turn on debug mode"
	echo "--disk=*			set install disk path (example /dev/sdb)"
}

check_disk() {
	path=$1
	if [[ $path != "/dev/sd"? ]]; then
		echo "$path unexpected disk format"
		unset path
		return 1
	fi
	if lsblk "$path" > /dev/null 2>&1; then
		unset path
	else
		echo "disk not found"
		unset path
		return 1
	fi
}

errors=0
debug_mode=0
disk_path=""

unset_all() {
	unset disk_path
	unset debug_mode
	unset errors
}

while test $# -gt 0; do
	case "$1" in
		-h|--help)
			print_help
			errors=$((errors+1))
			shift
			;;
		-d|--debug)
			debug_mode=1
			shift
			;;
		--debug=*)
			tmp=$1
			tmp="${tmp#--debug=}"
			[[ $tmp =~ [yY] ]] && debug_mode=1 || debug_mode=0
			unset tmp
			shift
			;;
		--disk=*)
			tmp=$1
			tmp="${tmp#--disk=}"
			check_disk $tmp && tmp=""
			[[ tmp == "" ]] && errors=$((errors+1))
			unset tmp
			shift
			;;
		*)
			echo "unknown argument \"$1\""
			errors=$((errors+1))
			shift
			;;
	esac
done

if [[ $errors != 0 ]]; then
	echo "exiting"
	unset_all
	exit 0
fi

[[ $debug_mode != 0 ]] && sleep 10
unset_all
