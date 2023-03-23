#!/bin/bash

# Determine public IP address using one of three web sites (checkip.dyndns.org, ip.me, or ifconfig.co)
# If the public IP address is different than the IP address in DNS for the configured hostname, update
# it in LUADNS

unset insecure
insecure="-k"

usage() {
  echo "usage: ${0##*/} [-h] [-d] [-f]"
  exit
}

unset debug
force_update=0
while getopts ":hdf" opt; do
  case $opt in
    d)
      debug=1
      ;;
    f)
      force_update=1
      ;;
    h|\?) usage
      ;;
  esac
done
shift $((OPTIND -1))

print_json() {
  # $1: public ip
  # $2: dns record
  # $3: dynamic hostname
  # $4: status
  # $5: updated_at
  echo "{"
  echo "  \"public_ip\": \"$1\","
  echo "  \"dns_record\": \"$2\","
  echo "  \"dynamic_hostname\": \"$3\","
  echo "  \"status\": \"$4\","
  echo "  \"updated_at\": \"$5\""
  echo "}"
}

# Read Domain info & LUADNS credentials from /config/secrets.yaml
secrets_file="$(readlink -f $(dirname "$0")/../secrets.yaml)"
[[ ! -f "$secrets_file" ]] && echo "Error: Could not find secrets.yaml" && exit 1
domain_name=$(awk "\$1 == \"luadns_domain:\" { print \$2 }" $secrets_file)
host=$(awk "\$1 == \"luadns_host:\" { print \$2 }" $secrets_file)
user=$(awk "\$1 == \"luadns_email:\" { print \$2 }" $secrets_file)
pass=$(awk "\$1 == \"luadns_token:\" { print \$2 }" $secrets_file)

dynamic_name=$host.$domain_name

# Determine pubip
pubip=$(curl -s $insecure http://checkip.dyndns.org | sed -r 's/.*: ([0-9]{1,3}(\.[0-9]{1,3}){3}).*$/\1/')
# Verify pubip is valid (no errors from the curl command)
if ! [[ $pubip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  pubip=$(curl -s $insecure http://ip.me)
  if ! [[ $pubip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    pubip=$(curl -s $insecure http://ifconfig.co)
    if ! [[ $pubip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
      pubip="Error with checkip.dyndns.org"
    fi
  fi
fi

# Determine current DNS IP
dnsip=$(dig +short $dynamic_name 2> /dev/null)
# Verify dnsip is valid (no errors from the dig command)
if ! [[ $dnsip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  dnsip="Error getting IP for $dynamic_name"
fi

if [[ $pubip =~ ^Error ]] || [[ $dnsip =~ ^Error ]]; then
  print_json "$pubip" "$dnsip" "$dynamic_name" "Error" "Unavailable"
  exit
fi

# Be silent unless -d/debug
unset silent
[ -z "$debug" ] && silent=-s

# Get Zone Number for domain
[ -n "$debug" ] && echo "Determining Zone Number for $domain_name"
[ -n "$debug" ] && echo curl $silent $insecure -f -u "$user:$pass" -H 'Accept: application/json' https://api.luadns.com/v1/zones \| \
           jq '.[] \| select(.name=="'"$domain_name"'").id'
zone_num=$(curl $silent $insecure -f -u "$user:$pass" -H 'Accept: application/json' https://api.luadns.com/v1/zones | \
           jq '.[] | select(.name=="'"$domain_name"'").id')
[ -z "$zone_num" ] && echo "Error: Could not determine the Zone ID for $domain_name" && exit 1

# If the IPs are different OR force is specified
if [[ $pubip != $dnsip ]] || [[ $force_update = 1 ]]; then
  # Get Record number for host
  [ -n "$debug" ] && echo "Determining Record Number and TTL for $dynamic_name"
  [ -n "$debug" ] && echo curl $silent $insecure -f -u "$user:$pass" -H 'Accept: application/json' \
             https://api.luadns.com/v1/zones/52069/records \| \
             jq -r '.[] | select(.name=="'"$dynamic_name"'." and .type=="A")|.id,.ttl'
  read -d "\n" record_num ttl <<< $(curl $silent $insecure -f -u "$user:$pass" -H 'Accept: application/json' \
             https://api.luadns.com/v1/zones/52069/records | \
             jq -r '.[] | select(.name=="'"$dynamic_name"'." and .type=="A")|.id,.ttl')
  [ -z "$record_num" -o -z "$ttl" ] && echo "Error: Could not determine the Record ID or TTL for $dynamic_name" && exit 1

  # Update IP address
  [ -n "$debug" ] && echo "Updating IP address for $dynamic_name"
  [ -n "$debug" ] && echo curl $silent $insecure -f -u "$user:$pass" -X PUT \
    -d '{"name": "'"$dynamic_name."'", "type": "A", "ttl": '"$ttl"', "content": "'"$pubip"'"}' \
    -H 'Accept: application/json' https://api.luadns.com/v1/zones/$zone_num/records/$record_num
  output=$(curl $silent $insecure -f -u "$user:$pass" -X PUT \
    -d '{"name": "'"$dynamic_name."'", "type": "A", "ttl": '"$ttl"', "content": "'"$pubip"'"}' \
    -H 'Accept: application/json' https://api.luadns.com/v1/zones/$zone_num/records/$record_num)
  err=$?
  [ $err != 0 ] && echo "Error: Could not update IP address for $dynamic_name ($err)" && echo $output && exit 1
  [ -n "$debug" ] && echo "$output"
fi

# Get the time the IP was last updated
updated_at=$(curl $silent $insecure -f -u "$user:$pass" -H 'Accept: application/json' \
             https://api.luadns.com/v1/zones/52069/records | \
             jq -r '.[] | select(.name=="'"$dynamic_name"'." and .type=="A").updated_at')

print_json $pubip $dnsip $dynamic_name "Up to date" $updated_at

