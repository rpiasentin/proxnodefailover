# proxnodefailover

A Proxmox host network failover solution that keeps a node reachable across relocations:

1) **Wired static** (preferred)  
2) **Wired DHCP**  
3) **Wi‑Fi DHCP**  
4) **Direct-connect fallback** (static IP on wired for laptop-to-node cable)

It is designed to keep access available for **Tailscale management**, with conservative behavior:
- If static fails and the node falls back to DHCP/Wi‑Fi, it **will not retry static** until the **Ethernet carrier changes** (unplug/plug).  
- When Wi‑Fi is healthy, the runtime **does not hunt** back to wired until carrier changes.

The runtime service reports:
- active mode (wired-static / wired-dhcp / wifi-dhcp / wired-direct)
- interface, IP, gateway
- tailscale node name + tailscale IP

## Quick install (safe)

Download **net-failover-setup**, then run it in **write-only** mode first:

```bash
curl -fsSL https://raw.githubusercontent.com/rpiasentin/proxnodefailover/main/scripts/net-failover-setup -o /root/net-failover-setup
chmod +x /root/net-failover-setup
/root/net-failover-setup --write-only
```

When you're ready to activate:

```bash
systemctl enable --now net-failover.service
journalctl -u net-failover.service -f
```

## Recommended: pin to a tag

Once you create a release tag (example `v1.0.1`):

```bash
TAG="v1.0.1"
curl -fsSL "https://raw.githubusercontent.com/rpiasentin/proxnodefailover/${TAG}/scripts/net-failover-setup" -o /root/net-failover-setup
chmod +x /root/net-failover-setup
/root/net-failover-setup --write-only
```

## If the repo is private

Use a GitHub token with repo read access:

```bash
export GITHUB_TOKEN="ghp_...redacted..."
curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  https://raw.githubusercontent.com/rpiasentin/proxnodefailover/main/scripts/net-failover-setup \
  -o /root/net-failover-setup
chmod +x /root/net-failover-setup
/root/net-failover-setup --write-only
```

## What net-failover-setup does

- Detects likely Proxmox management bridge (vmbr0) and its physical port
- Asks for any node-specific items (interfaces, static IP, gateway)
- Writes:
  - `/etc/net-failover.conf` (600)
  - `/usr/local/sbin/net-failover.sh` (755)
  - `/etc/systemd/system/net-failover.service`
- Optionally installs/enables **Tailscale + Tailscale SSH** (authkey optional)
- Makes timestamped backups of existing files

## Testing

See `docs/TESTING.md`.

## Security notes

See `docs/SECURITY.md`.

## Rollback

1) Disable service:
```bash
systemctl disable --now net-failover.service
```

2) Restore the latest backups:
- `/etc/net-failover.conf.bak.*`
- `/usr/local/sbin/net-failover.sh.bak.*`
- `/etc/systemd/system/net-failover.service.bak.*`

3) Reload systemd:
```bash
systemctl daemon-reload
```

## Files

- `scripts/net-failover-setup` – interactive deployer (supports `--write-only`)
- `scripts/net-failover.sh` – reference runtime script (same as installed by the deployer)
- `scripts/net-failover.service` – reference systemd unit
- `examples/net-failover.conf.example`
