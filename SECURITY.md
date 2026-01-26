# Security

## Credentials at rest
This project intentionally stores Wi‑Fi credentials on the node for headless operation:
- `/etc/net-failover.conf` contains `WIFI_SSID` and `WIFI_PSK`
- `wpa_supplicant` config written by runtime contains SSID/PSK for the Wi‑Fi interface

Permissions:
- `net-failover-setup` sets `/etc/net-failover.conf` to `0600`
- runtime sets wpa_supplicant config to `0600`

## Logs
- Logs include connectivity mode and active interface, but do **not** print the PSK.

## Tailscale
- If you supply `TS_AUTHKEY`, treat it like a secret.
- Prefer short-lived keys and least-privileged policies when possible.

## Operational guidance
- Use `--write-only` when deploying remotely over SSH.
- Activate the service once you confirm alternate access (e.g., Tailscale SSH) works.
