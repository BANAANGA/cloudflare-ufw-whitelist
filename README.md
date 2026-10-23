# cloudflare-ufw-whitelist
Whitelist Cloudflare reverse proxy IP ranges (IPv4 + IPv6) on ports 80 and 443 using `ufw`. The script also prompts for extra addresses (e.g. your own IP) to whitelist.

## Quick start (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/BANAANGA/cloudflare-ufw-whitelist/main/cloudflare-ufw-whitelist.sh -o /tmp/cf-ufw.sh && sudo bash /tmp/cf-ufw.sh
```

The script is downloaded to a file first (not piped into `bash`) so the interactive prompts work. Review it before running.

## Manual install

```bash
git clone https://github.com/BANAANGA/cloudflare-ufw-whitelist.git
cd cloudflare-ufw-whitelist
sudo ./cloudflare-ufw-whitelist.sh
```

## Usage

```
sudo ./cloudflare-ufw-whitelist.sh [-y] [-n]
  -y  skip the confirmation prompt
  -n  dry run: print the ufw commands without applying them (no root needed)
```

What it does:

1. Downloads the current lists from <https://www.cloudflare.com/ips-v4> and <https://www.cloudflare.com/ips-v6>.
2. Prompts for additional IPs/CIDRs (one per line or space/comma separated; empty line to finish).
3. Adds `ufw allow proto tcp from <ip> to any port 80|443` for every range, tagged with the comment `cloudflare-whitelist`.

## Requirements

`bash`, `curl`, `ufw`, root privileges.

## Important

The script only adds allow rules. For only whitelisted sources to reach ports 80/443:

- set `sudo ufw default deny incoming`
- remove any existing general rules such as `allow 80`, `allow 443` or `allow 'Nginx Full'` (`sudo ufw status numbered`)
- make sure SSH is allowed before enabling ufw

Cloudflare ranges change occasionally; re-run the script periodically and remove stale rules, which can be found by their `cloudflare-whitelist` comment.
