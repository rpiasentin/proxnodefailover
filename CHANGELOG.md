# Changelog

## v1.0.1
- Initial release:
  - net-failover runtime with:
    - wired static -> wired DHCP -> Wi‑Fi DHCP -> direct-connect fallback
    - static retry suppressed until Ethernet carrier changes
    - Wi‑Fi no-hunt behavior until carrier changes
    - CONNECTED log line includes tailscale name/ip
  - net-failover-setup deployer:
    - autodetect defaults, interactive prompts, idempotent installs
    - --write-only safety option
    - optional Tailscale install + Tailscale SSH
