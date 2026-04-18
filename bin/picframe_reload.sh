#!/bin/sh

unset SSH_AUTH_SOCK

/usr/bin/ssh -a -o ConnectTimeout=7 -o IdentitiesOnly=yes -o UserKnownHostsFile=/config/.ssh/known_hosts -i /config/.ssh/homeassistant mike@sinope.erdely.in reload 2> /dev/null
