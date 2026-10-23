#!/usr/bin/env bash
# Whitelist Cloudflare IP ranges (plus optional extra addresses) on ports 80/443 via ufw.
# Usage: sudo ./cloudflare-ufw-whitelist.sh [-y] [-n]
#   -y  skip confirmation prompt
#   -n  dry run (print ufw commands, do not execute)
set -euo pipefail

PORTS=(80 443)
URL_V4="https://www.cloudflare.com/ips-v4"
URL_V6="https://www.cloudflare.com/ips-v6"
ASSUME_YES=0
DRY_RUN=0

while getopts "yn" opt; do
  case $opt in
    y) ASSUME_YES=1 ;;
    n) DRY_RUN=1 ;;
    *) echo "Usage: $0 [-y] [-n]" >&2; exit 1 ;;
  esac
done

if [[ $DRY_RUN -eq 0 && $EUID -ne 0 ]]; then
  echo "Run as root (sudo), or use -n for a dry run." >&2
  exit 1
fi

for cmd in curl ufw; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done

# Basic validation of IPv4/IPv6 address or CIDR.
valid_ip() {
  local ip=$1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[12][0-9]|3[0-2]))?$ ]]; then
    local IFS=. o
    for o in ${ip%%/*}; do ((o <= 255)) || return 1; done
    return 0
  fi
  if [[ $ip =~ ^[0-9a-fA-F:]+(/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8]))?$ && $ip == *:* ]]; then
    return 0
  fi
  return 1
}

fetch() {
  curl -fsS --max-time 30 "$1" || { echo "Failed to download $1" >&2; exit 1; }
}

mapfile -t CF < <(fetch "$URL_V4"; echo; fetch "$URL_V6")
RANGES=()
for r in "${CF[@]}"; do
  r=${r//[[:space:]]/}
  [[ -z $r ]] && continue
  valid_ip "$r" || { echo "Unexpected entry from Cloudflare: $r" >&2; exit 1; }
  RANGES+=("$r")
done
[[ ${#RANGES[@]} -gt 0 ]] || { echo "No Cloudflare ranges retrieved." >&2; exit 1; }
echo "Fetched ${#RANGES[@]} Cloudflare ranges."

echo
echo "Enter additional IPs/CIDRs to whitelist (one per line or space/comma separated)."
echo "Press Enter on an empty line to finish."
while true; do
  read -r -p "> " line || break
  [[ -z ${line//[[:space:]]/} ]] && break
  for ip in ${line//,/ }; do
    if valid_ip "$ip"; then
      RANGES+=("$ip")
    else
      echo "  Invalid address skipped: $ip"
    fi
  done
done

echo
echo "Will allow ${#RANGES[@]} source ranges on ports: ${PORTS[*]}"
if [[ $ASSUME_YES -eq 0 && $DRY_RUN -eq 0 ]]; then
  read -r -p "Proceed? [y/N] " ans
  [[ $ans =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

for ip in "${RANGES[@]}"; do
  for port in "${PORTS[@]}"; do
    cmd=(ufw allow proto tcp from "$ip" to any port "$port" comment "cloudflare-whitelist")
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "${cmd[*]}"
    else
      "${cmd[@]}" >/dev/null
    fi
  done
done

if [[ $DRY_RUN -eq 0 ]]; then
  ufw reload >/dev/null || true
  echo "Done. Verify with: ufw status numbered"
  echo "Note: remove any existing general 'allow 80/443' rules, and set 'ufw default deny incoming', so only these ranges can connect."
fi
