#!/bin/sh

tmpfile=$(mktemp)
# Get mimugmail repo info
cp /dev/null $tmpfile
if [ -n "$1" ]; then
  http_status_code=$(curl -w %{http_code} -sfo $tmpfile "https://opn-repo.routerperformance.net/repo/$1/packagesite.txz")
  tmpdir=$(mktemp -d)
  tar -C $tmpdir -xf $tmpfile
  mimugmail=$(cat $tmpdir/packagesite.yaml|jq -r .|awk '/^  "name":/{n=$2;if(substr(n,2,3)!="os-")n=""}/^  "version":/&&n!=""{printf "    %s: %s\n",substr(n,1,length(n)-1),$2}')
  rm -Rf $tmpdir
fi

# Get opnsense repo info
cp /dev/null $tmpfile
if [ -n "$2" ]; then
  status="http_status_code=$(curl -w %{http_code} -sfo $tmpfile "https://pkg.opnsense.org/$1/$2/latest/All/"); sys_abi=$1; core_abi=$2"
else
  status="command usage: ${0##*/} opnsense_sys_abi opnsense_core_abi"
fi

# Print 
echo "{"
echo "  \"timestamp\": \"$(date "+%FT%H:%M:%S%z")\","
echo "  \"status\": \"$status\","
echo "  \"plugins\": {"
echo "$mimugmail"
cat $tmpfile | awk -v status="$status" -F'[<>]' '
  $13 ~ /^(opnsense|os)-.*\.(txz|pkg)$/ {
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
