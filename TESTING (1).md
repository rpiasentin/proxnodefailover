# Testing

Run logs in one terminal:
```bash
journalctl -u net-failover.service -f
```

## Test 1 — Normal wired static
- Plug into the intended LAN where static IP + gateway are valid.
- Confirm:
  - `ip -4 -br addr show <MGMT_IF>`
  - log line shows `mode=wired-static`

## Test 2 — Wired static invalid → wired DHCP
- Plug into a LAN where the configured static gateway is wrong OR isolate upstream routing.
- Expected:
  - runtime logs static failure and switches to DHCP
  - log line shows `mode=wired-dhcp`

## Test 3 — Wired DHCP invalid → Wi‑Fi DHCP
- Keep ethernet plugged (carrier up) but ensure DHCP does not provide connectivity (or block upstream).
- Expected:
  - runtime switches to Wi‑Fi and stays there without hunting
  - log line shows `mode=wifi-dhcp`

## Test 4 — Wi‑Fi fails → direct connect fallback
- Disable Wi‑Fi AP or move out of range.
- Expected:
  - runtime assigns fallback CIDR to mgmt interface
  - log line shows `mode=wired-direct`

To connect from laptop:
- Set laptop ethernet to same /24 (e.g., 192.168.99.2/24)
- SSH to the node fallback IP (e.g., 192.168.99.1)

## Test 5 — No static retry until carrier change
- Force a switch off static (Test 2).
- Keep cable plugged (carrier unchanged).
- Verify logs do NOT show repeated attempts to apply static.
- Unplug/plug cable: verify static attempts resume.
