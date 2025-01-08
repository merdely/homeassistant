#!/bin/sh

print_log() { date +"%b %e %H:%M:%S $(hostname -s) $(basename $0 .sh)[$$]: $*"; }

ca_url=https://ca.erdelynet.com
fullchain=/ssl/fullchain.pem

usage() {
  echo "usage: ${0##*/} [-h] [-f]"
  echo "        -h              : This help text"
  echo "        -f              : Download and copy $fullchain.new even if cert has not changed"
  exit 1
}

force=0

while getopts ":hf" opt; do
  case $opt in
    f)
      force=1
      ;;
    h|\?) usage
      ;;
  esac
done
shift $((OPTIND -1))

newcrt=$(mktemp /tmp/newcrt.XXXXXXXXXXXXXXXXXXXX)
new_ca=$(mktemp /tmp/new_ca.XXXXXXXXXXXXXXXXXXXX)

curl -sLo $newcrt $ca_url/homeassistant.home.erdelynet.com.crt
curl -sLo $new_ca $ca_url/homeassistant.home.erdelynet.com_ca.crt

if ! grep -q -- "-----BEGIN CERTIFICATE-----" $newcrt; then
  print_log "Error: Invalid certificate downloaded ($ca_url available?)"
  rm -f $newcrt $new_ca
  exit 1
fi
if ! grep -q -- "-----BEGIN CERTIFICATE-----" $new_ca; then
  print_log "Error: Invalid CA certificate downloaded ($ca_url available?)"
  rm -f $newcrt $new_ca
  exit 1
fi

cat $new_ca >> $newcrt

if [ x$force = x1 ] || ! cmp -s $fullchain $newcrt || ! test -f $fullchain; then

  print_log "Creating $fullchain.new"
  cp -f $newcrt $fullchain.new
  chmod 644 $fullchain.new

fi

rm -f $newcrt $new_ca
