#!/bin/sh

if [ -z "$2" ]; then
  sys_abi=$($(dirname "$(realpath "$0")")/opnsense_snmp_versions.py | jq -r '."sys-abi"')
else
  sys_abi=$1
fi

# echo sys_abi=$sys_abi >> /dev/stderr

curl -s "https://pkg.opnsense.org/$sys_abi/" | awk -F '[><]' '/\[DIR\]/ && $13 ~ /^[0-9]/ {sub(/\/$/,"",$13);print $13}' | sort -Vr | head -n1
