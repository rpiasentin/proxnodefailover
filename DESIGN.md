# Design

## Goals
- Keep a Proxmox node reachable when moved between different LANs and when a preferred static configuration isn't valid.
- Prefer deterministic management reachability (especially via Tailscale) over "hunting" for the perfect wired path.

## Interface model (Proxmox)
- Proxmox usually places the management IP on a Linux bridge (e.g., `vmbr0`).
- Linux bridges can show "UP" even if the physical cable is unplugged.
- Therefore the runtime uses a separate **physical carrier interface** (`ETH_LINK_IF`, usually the port enslaved to the bridge like `nic0`) for link detection.

## Failover order
1. Wired static on `MGMT_IF`
2. Wired DHCP on `MGMT_IF`
3. Wi‑Fi DHCP on `WIFI_IF`
4. Wired direct-connect static on `MGMT_IF` (no gateway)

## Anti-hunt rules
- If wired static fails, the runtime switches to wired DHCP and sets **static-suppression**.
- Static is only retried after an **Ethernet carrier change** (unplug/plug).
- When Wi‑Fi is healthy, the runtime does not attempt to switch back to wired until carrier changes.

## Health checks
Connectivity is considered OK if:
- interface has an IPv4 address AND
- can ping the interface gateway; otherwise tries public pings (1.1.1.1 / 8.8.8.8).

## Logging
When active connectivity is confirmed, the runtime logs a single “CONNECTED:” line that includes:
- mode, interface, IP, gateway
- tailscale node name + tailscale IPv4 (if tailscale is installed)

The log line is de-duplicated (only prints when something changes).
