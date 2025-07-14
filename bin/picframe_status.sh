#!/bin/sh

unset SSH_AUTH_SOCK

output=$(/usr/bin/ssh -a -o ConnectTimeout=7 -o UserKnownHostsFile=/config/.ssh/known_hosts -i /config/.ssh/homeassistant picframe@sinope.erdely.in status 2> /dev/null)

if [ $? != 0 ]; then
  echo "{ \"status\": \"unavailable\" }"
else
  echo "{ \"status\": \"$output\" }"
fi

