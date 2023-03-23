#!/bin/sh

print_log() { date +"%b %e %H:%M:%S $(hostname -s) $(basename $0 .sh)[$$]: $*"; }

usage() {
  echo "usage: ${0##*/} [-h] [-f]"
  echo "        -h              : This help text"
  echo "        -f              : Update TV Show File even if no change"
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

unset config_file
hapath=/srv/docker/homeassistant
[ -f /config/.HA_VERSION ] && hapath=/config
[ -f /config/bin/.plexapi_rc ] && config_file=/config/bin/.plexapi_rc
showfile=$hapath/tv_shows.yaml

newshows=$(mktemp /tmp/newshows.XXXXXXXXXXXXXXXXXXXXXXXXXXXX)

{ echo '  - Select Show'; \
  /config/bin/plex_list_shows $config_file | \
  sed -r "s/^(Battlestar Galactica) \(2003\)$/\1 mwe/;s/ \([0-9][0-9][0-9][0-9]\)$//;s/ mwe$/ 2003/;s/(^DC's |^Marvel's |^Phillip K. Dick's |^Tom Clancy's | Motion Comic$)//;s/[^a-zA-Z0-9[:space:]'-]//g;s/^/  - /" | \
  sort -u; } > $newshows

if [ x$force = x1 ] || ! cmp -s $showfile $newshows || ! test -e $showfile; then
  cp $newshows $showfile.new
  mv $showfile.new $showfile
  chgrp 1013 $showfile
  chmod 660 $showfile
  touch $hapath/.newtvshowfile
fi

rm -f $newshows

