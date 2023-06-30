#!/bin/sh

if [ -z "$2" ]; then
  eval $($(dirname "$(realpath "$0")")/opnsense_snmp_versions.py | jq  -r | awk -F'"' '$2=="core-abi"||$2=="sys-abi"{printf "%s=%s\n",gensub(/-/,"_","g",$2),$4}')
else
  sys_abi=$1
  core_abi=$2
fi

#echo sys_abi=$sys_abi >> /dev/stderr
#echo core_abi=$core_abi >> /dev/stderr

tmpfile=$(mktemp)
# Get mimugmail repo info
cp /dev/null $tmpfile
if [ -n "$sys_abi" ]; then
  http_status_code=$(curl -w %{http_code} -sfo $tmpfile "https://opn-repo.routerperformance.net/repo/$sys_abi/packagesite.txz")
  tmpdir=$(mktemp -d)
  tar -C $tmpdir -xf $tmpfile
  mimugmail=$(cat $tmpdir/packagesite.yaml|jq -r .|awk '/^  "name":/{n=$2;if(substr(n,2,3)!="os-")n=""}/^  "version":/&&n!=""{printf "    %s: %s\n",substr(n,1,length(n)-1),$2}')
  rm -Rf $tmpdir
fi

# Get opnsense repo info
cp /dev/null $tmpfile
if [ -n "$core_abi" ]; then
  status="http_status_code=$(curl -w %{http_code} -sfo $tmpfile "https://pkg.opnsense.org/$sys_abi/$core_abi/latest/All/"); sys_abi=$sys_abi; core_abi=$core_abi"
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
