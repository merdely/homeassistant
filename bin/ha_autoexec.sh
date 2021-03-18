#!/bin/sh

print_log() { date +"%b %e %H:%M:%S $(hostname -s) $(basename $0 .sh)[$$]: $*"; }

usage() {
  echo "usage: ${0##*/} [-h] [-f]"
  echo "        -h              : This help text"
  exit 1
}

while getopts ":hf" opt; do
  case $opt in
    h|\?) usage
      ;;
  esac
done
shift $((OPTIND -1))

hapath=/srv/docker/homeassistant
[ -f /config/.HA_VERSION ] && hapath=/config

rm -f $hapath/.newtvshowfile

if [ -f /ssl/fullchain.pem.new ]; then
  mv /ssl/fullchain.pem.new /ssl/fullchain.pem
  chmod 644 /ssl/fullchain.pem
fi
