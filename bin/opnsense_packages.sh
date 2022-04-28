#!/bin/sh

tmpfile=$(mktemp)
if [ -n "$2" ]; then
  status="http_status_code=$(curl -w %{http_code} -sfo $tmpfile "https://pkg.opnsense.org/$1/$2/latest/All/"); sys_abi=$1; core_abi=$2"
else
  status="command usage: ${0##*/} opnsense_sys_abi opnsense_core_abi"
fi
cat $tmpfile | awk -v status="$status" -F'[<>]' '
  BEGIN {
    "date \"+%FT%H:%M:%S%z\""|getline date;
    date=substr(date,1,length(date)-2) ":" substr(date,length(date)-1);
    print "{";
    printf "  \"timestamp\": \"%s\",\n", date;
    printf "  \"status\": \"%s\",\n", status;
    print "  \"plugins\": {";
    d=""
  }
  $13 ~ /^(opnsense|os)-.*\.txz$/ {
    p=substr($13,1,length($13)-4);
    split(p,a,"-");
    v=a[length(a)];
    delete a[length(a)];
    printf "%s    \"%s\": \"%s\"", d,substr(p,1,length(p)-length(v)-1),v;
    d=",\n"
  }
  END {
    print "\n  }\n}"
  }
'

rm -f $tmpfile
