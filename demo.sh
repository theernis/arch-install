#!/bin/bash

case $(id -u) in
	0) ;;
	*) echo "this script needs root privileges, please run this script with sudo" ;;
esac
