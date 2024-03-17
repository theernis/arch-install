#!/bin/bash

case $(id -u) in
	0)
		;;
	*)
		echo "this script needs root privileges, please run this script with sudo" ;;
esac

print_help() {
	echo "options:"
	echo "-h, --help	show this"
}

errors=0

while test $# -gt 0; do
	case "$1" in
		-h|--help)
			print_help
			errors=$((errors+1))
			shift
			;;
		*)
			echo "unknown argument \"$1\""
			errors=$((errors+1))
			shift
			;;
	esac
done

if [[ errors != 0 ]]; then
	echo "exiting"
	unset errors
	exit 0
fi
