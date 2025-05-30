#!/bin/bash

check_prereqs() {
  which $1 > /dev/null 2>&1
  if [ $? != 0 ]; then
    echo "Error: '$1' is required for this program"
    exit 1
  fi
}

check_prereqs dig
check_prereqs curl
check_prereqs ping

admin_token=zjhJFE4Ev1HQp1xVj81N
user_token=kUYzEUnf4a-ifoNZQ9w3
plex_prot=https
plex_server=plex.erdely.in
plex_port=32400

rokuport=${rokuport:=8060}

declare -A clientid=()
clientid[roku-bedroom.erdely.in]=7ebd1750040e78ba5cda8494e65fcd42
clientid[roku-office.erdely.in]=4bcec4bd2db5a14d2a45c255082fcfef
clientid[roku-living-room.erdely.in]=ed0405ae97d60d909aba20599ae5a187
clientid[roku-god-damn.erdely.in]=d666057fd996ebd612b624acb52dd5e2

declare -A rokuname=()
rokuname[roku-bedroom.erdely.in]="Bedroom Roku"
rokuname[roku-office.erdely.in]="Office Roku TV"
rokuname[roku-living-room.erdely.in]="Living Room Roku TV"
rokuname[roku-god-damn.erdely.in]="God Damn Roku"

testmode=0
debug=0
if [ "$1" = "-h" ] || [ -z "$2" ]; then
  echo "usage: $0 [-h] [-t] [-d] roku show"
  echo "Roku List:"
  echo "  - [roku-]bedroom[.erdely.in]"
  echo "  - [roku-]office[.erdely.in]"
  echo "  - [roku-]living-room[.erdely.in]"
  echo "  - [roku-]god-damn[.erdely.in]"
  exit
fi
[ "$1" = "-d" ] && shift && debug=1
[ "$1" = "-t" ] && shift && testmode=1
[ "$1" = "-d" ] && shift && debug=1

roku=$(echo $1 | sed -r 's/^(roku-)?/roku-/;s/(\.erdely\.in)?$/.erdely.in/')
rokuip=$(dig +short $roku)
rokuslug=${roku%%.*}
show=$2
show_encoded=$(echo $show | sed "s/ /%20/g;s/\&/%26/g;s/'/\&#39;/g")

ping -c 2 $rokuip > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "Error: ${roku%%.*} ($rokuip) is down"
  exit 1
fi

# Determine Plex app on Roku
plexappid=$(curl -s http://$rokuip:$rokuport/query/apps|awk -F '"' '/>Plex/{print $2}')

# Determine machine ID for Plex
plexid=$(curl -s -G -d "X-Plex-Token=$admin_token" "$plex_prot://$plex_server:$plex_port/" | awk "/<MediaContainer .*machineIdentifier/{for (i=1;i<NF;i++) {if(\$i~/^machineIdentifier=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))};exit}")

# Determine client ID for Roku on Plex
clientid=$(curl -s -G -d "X-Plex-Token=$admin_token" "$plex_prot://$plex_server:$plex_port/devices" | awk "/<Device .*name=\"${rokuname[$roku]}\"/{for (i=1;i<NF;i++) {if(\$i~/^clientIdentifier=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))};exit}")

# Determine TV Shows library ID
libraryid=$(curl -s -G -d "X-Plex-Token=$admin_token" "$plex_prot://$plex_server:$plex_port/library/sections" | awk '/<Directory .*title="TV Shows"/{for (i=1;i<NF;i++) {if($i~/^key=/)print gensub(/"$/,"",1,gensub(/^.*="/,"",1,$i))};exit}')

# Determine TV Show ID
showid=$(curl -s -G -d "X-Plex-Token=$user_token" "$plex_prot://$plex_server:$plex_port/library/sections/$libraryid/all?title=$show_encoded" | awk "/<Directory .*title=/{for (i=1;i<NF;i++) {if(\$i~/ratingKey=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))};exit}")

# Determine OnDeck ID for Show (if it exists)
ondeck=1
#if [ $debug = 1 ]; then
#  curl -s -G -d "X-Plex-Token=$user_token" "$plex_prot://$plex_server:$plex_port/library/onDeck"
#fi
nextepisode=$(curl -s -G -d "X-Plex-Token=$user_token" "$plex_prot://$plex_server:$plex_port/library/onDeck" | awk "/<Video .*grandparentTitle=\"$show\"/{for (i=1;i<NF;i++) {if(\$i~/key=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))};exit}")

# If show is not OnDeck, get Season 1, Episode 1
if [ -z "$nextepisode" ]; then
  ondeck=0
  season1=$(curl -s -G -d "X-Plex-Token=$user_token" "$plex_prot://$plex_server:$plex_port/library/metadata/$showid/children" | awk "/<Directory .*parentKey=\"\/library\/metadata\/$showid\"/{for (i=1;i<NF;i++) {if(\$0~/index=\"1\"/&&\$i~/ratingKey=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))};exit}")
  nextepisode=$(curl -s -G -d "X-Plex-Token=$user_token" "$plex_prot://$plex_server:$plex_port/library/metadata/$season1/children" | awk "/<Video .*parentRatingKey=\"$season1\"/{for (i=1;i<NF;i++) {if(\$0~/index=\"1\"/&&\$i~/ratingKey=/)print \"/library/metadata/\" gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))};exit}")
fi

if [ -n "$debug" ] || [ $debug = 1 ]; then
  echo roku=$roku
  echo rokuip=$rokuip
  echo rokuslug=$rokuslug
  echo plexid=$plexid
  echo show=$show
  echo show_encoded=$show_encoded
  echo plexappid=$plexappid
  echo clientid[$roku]=${clientid[$roku]}
  echo clientid=$clientid
  echo libraryid=$libraryid
  echo showid=$showid
  echo ondeck=$ondeck
  echo nextepisode=$nextepisode
fi

if [ -z "$libraryid" ]; then
  echo "Error: Could not determine library for TV Shows"
  exit 1
fi

if [ -z "$showid" ]; then
  echo "Error: Could not determine showid for '$show'"
  exit 1
fi

if [ -z "$nextepisode" ]; then
  echo "Error: Could not determine next episode for '$show'"
  exit 1
fi

# Open Plex app on Roku
curl -s -d '' http://$rokuip:$rokuport/launch/$plexappid

if [ $testmode = 0 ]; then
  # Give the Plex app a few seconds to start
  [ $debug = 1 ] && echo "Sleeping 5 seconds"
  sleep 5

  # Add show to PlayQueues on Plex
  output=$(curl -s -G -X POST -H "X-Plex-Token: $admin_token" -H "X-Plex-Client-Identifier: $rokuslug" -d "type=video" -d "shuffle=0" -d "repeat=0" -d "continuous=1" -d "own=1" -d "uri=server://$plexid/com.plexapp.plugins.library${nextepisode}" "$plex_prot://$plex_server:$plex_port/playQueues")
  # [ $debug = 1 ] && echo output=$output

  playqueueid=$(echo $output | awk "/<MediaContainer .*playQueueID=/{for (i=1;i<NF;i++) {if(\$i~/^playQueueID=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))}}")
  [ $debug = 1 ] && echo playqueueid=$playqueueid
  playqueueselectedmetadataitemid=$(echo $output | awk "/<MediaContainer .*playQueueSelectedMetadataItemID=/{for (i=1;i<NF;i++) {if(\$i~/^playQueueSelectedMetadataItemID=/)print gensub(/\"\$/,\"\",1,gensub(/^.*=\"/,\"\",1,\$i))}}")
  [ $debug = 1 ] && echo playqueueselectedmetadataitemid=$playqueueselectedmetadataitemid

  # Play the Queue
  playoutput=$(curl -s -G -H "X-Plex-Client-Identifier: $rokuslug" -H "X-Plex-Target-Client-Identifier: $clientid" -d "protocol=$plex_prot" -d "address=$plex_server" -d "port=52400" -d "containerKey=/playQueues/$playqueueid" -d "key=/library/metadata/$playqueueselectedmetadataitemid" -d "offset=0" -d "commandID=1" -d "type=video" -d "machineIdentifier=$plexid" -d "token=$user_token" "http://$rokuip:8324/player/playback/playMedia")
  [ $debug = 1 ] && echo playoutput=$playoutput
fi

