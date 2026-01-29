#!/usr/bin/env bash
set -euo pipefail


log(){ echo "[$(date -Is)] $*"; }

CONF=/etc/net-failover.conf
if [[ -f "$CONF" ]]; then
  log "DEBUG: Sourcing $CONF"
  cat "$CONF" # Print it for debug
  source "$CONF"
  log "DEBUG: Sourced. MOCK_CARRIER_FILE=${MOCK_CARRIER_FILE:-unset}"
else
  log "DEBUG: Config file $CONF not found"
fi

MGMT_IF="${MGMT_IF:-vmbr0}"
ETH_LINK_IF="${ETH_LINK_IF:-}"
WIFI_IF="${WIFI_IF:-}"

STATIC_CIDR="${STATIC_CIDR:-192.168.1.127/24}"
STATIC_GW="${STATIC_GW:-192.168.1.1}"
FALLBACK_CIDR="${FALLBACK_CIDR:-192.168.99.1/24}"

WIFI_SSID="${WIFI_SSID:-Piahas}"
WIFI_PSK="${WIFI_PSK:-richardpiasentin}"

CHECK_INTERVAL="${CHECK_INTERVAL:-10}"

if [[ -z "${WIFI_IF}" ]]; then
  WIFI_IF="$(ls /sys/class/net 2>/dev/null | grep -E '^wl' | head -n1 || true)"
fi

if [[ -z "${ETH_LINK_IF}" ]]; then
  ETH_LINK_IF="$MGMT_IF"
  if [[ -d "/sys/class/net/${MGMT_IF}/brif" ]]; then
    ETH_LINK_IF="$(ls "/sys/class/net/${MGMT_IF}/brif" 2>/dev/null | head -n1 || echo "$MGMT_IF")"
  fi
fi

carrier() {
  if [[ -n "${MOCK_CARRIER_FILE:-}" ]] && [[ -f "$MOCK_CARRIER_FILE" ]]; then
      # Check if content is 1, return 0 (true) if so, else 1 (false)
      [[ "$(cat "$MOCK_CARRIER_FILE")" == "1" ]]
      return
  fi
  [[ -e /sys/class/net/"$1"/carrier ]] && [[ "$(cat /sys/class/net/"$1"/carrier)" == "1" ]]
}
has_ipv4() { ip -4 addr show dev "$1" | grep -q 'inet '; }
gw_for() { ip route show default dev "$1" 2>/dev/null | awk 'NR==1{print $3}'; }
ip4_of() { ip -4 -o addr show dev "$1" 2>/dev/null | awk '{print $4}' | head -n1; }
ping_if() { ping -I "$1" -c 1 -W 1 "$2" >/dev/null 2>&1; }

connectivity_ok() {
  local ifc="$1"
  has_ipv4 "$ifc" || return 1
  local gw; gw="$(gw_for "$ifc" || true)"
  if [[ -n "${gw:-}" ]] && ping_if "$ifc" "$gw"; then return 0; fi
  for h in 1.1.1.1 8.8.8.8; do
    if ping_if "$ifc" "$h"; then return 0; fi
  done
  return 1
}

DHCLIENT_CMD="${DHCLIENT_CMD:-dhclient}"
log "DEBUG: DHCLIENT_CMD is '$DHCLIENT_CMD'"

dhclient_stop() {
  local ifc="$1"
  if [[ -f "/run/dhclient-${ifc}.pid" ]]; then
    "$DHCLIENT_CMD" -4 -r -pf "/run/dhclient-${ifc}.pid" "$ifc" >/dev/null 2>&1 || true
    rm -f "/run/dhclient-${ifc}.pid"
  fi
}
dhclient_start() {
  local ifc="$1"
  dhclient_stop "$ifc"
  "$DHCLIENT_CMD" -4 -v -pf "/run/dhclient-${ifc}.pid" -lf "/var/lib/dhcp/dhclient.${ifc}.leases" "$ifc" >/dev/null 2>&1 || true
}

eth_clear() {
  dhclient_stop "$MGMT_IF"
  ip addr flush dev "$MGMT_IF" >/dev/null 2>&1 || true
  ip route del default dev "$MGMT_IF" >/dev/null 2>&1 || true
}

wifi_conf_path() { echo "/etc/wpa_supplicant/wpa_supplicant-${WIFI_IF}.conf"; }
wifi_ensure_conf() {
  local wconf; wconf="$(wifi_conf_path)"
  if [[ ! -f "$wconf" ]]; then
    cat >"$wconf" <<EOC
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1
network={
  ssid="${WIFI_SSID}"
  psk="${WIFI_PSK}"
  key_mgmt=WPA-PSK
}
EOC
    chmod 600 "$wconf"
  fi
}
wifi_up() {
  [[ -n "${WIFI_IF:-}" ]] || return 1
  wifi_ensure_conf
  ip link set "$WIFI_IF" up >/dev/null 2>&1 || true
  systemctl start "wpa_supplicant@${WIFI_IF}.service" >/dev/null 2>&1 || true
  dhclient_start "$WIFI_IF"
}
wifi_down() {
  [[ -n "${WIFI_IF:-}" ]] || return 0
  dhclient_stop "$WIFI_IF"
  systemctl stop "wpa_supplicant@${WIFI_IF}.service" >/dev/null 2>&1 || true
  ip addr flush dev "$WIFI_IF" >/dev/null 2>&1 || true
}

eth_static_up() {
  ip link set "$MGMT_IF" up >/dev/null 2>&1 || true
  dhclient_stop "$MGMT_IF"
  ip addr flush dev "$MGMT_IF" >/dev/null 2>&1 || true
  ip addr add "$STATIC_CIDR" dev "$MGMT_IF"
  ip route replace default via "$STATIC_GW" dev "$MGMT_IF" metric 100
}
eth_dhcp_up() {
  log "DEBUG: Inside eth_dhcp_up"
  ip link set "$MGMT_IF" up >/dev/null 2>&1 || true
  ip addr flush dev "$MGMT_IF" >/dev/null 2>&1 || true
  ip route del default dev "$MGMT_IF" >/dev/null 2>&1 || true
  log "DEBUG: Calling dhclient_start"
  dhclient_start "$MGMT_IF"
  log "DEBUG: dhclient_start returned"
}
eth_direct_up() {
  ip link set "$MGMT_IF" up >/dev/null 2>&1 || true
  dhclient_stop "$MGMT_IF"
  ip addr flush dev "$MGMT_IF" >/dev/null 2>&1 || true
  ip addr add "$FALLBACK_CIDR" dev "$MGMT_IF"
  ip route del default dev "$MGMT_IF" >/dev/null 2>&1 || true
}

# Tailscale reporting

ts_self_line() { command -v tailscale >/dev/null 2>&1 && tailscale status --self 2>/dev/null | head -n1 || true; }
ts_ip() {
  local line; line="$(ts_self_line || true)"
  if [[ -n "${line:-}" ]]; then echo "$line" | awk '{print $1}'; return 0; fi
  command -v tailscale >/dev/null 2>&1 || { echo ""; return 0; }
  tailscale ip -4 2>/dev/null | head -n1 || true
}
ts_name() {
  local line; line="$(ts_self_line || true)"
  if [[ -n "${line:-}" ]]; then echo "$line" | awk '{print $2}'; return 0; fi
  hostname -s 2>/dev/null || hostname || true
}

LAST_REPORT_KEY=""
report_connected() {
  local mode="$1" ifc="$2"
  local ip gw tsip tsname key
  ip="$(ip4_of "$ifc" || true)"
  gw="$(gw_for "$ifc" || true)"
  tsip="$(ts_ip || true)"
  tsname="$(ts_name || true)"
  key="${mode}|${ifc}|${ip}|${gw}|${tsip}|${tsname}"
  if [[ "$key" != "$LAST_REPORT_KEY" ]]; then
    LAST_REPORT_KEY="$key"
    log "CONNECTED: mode=${mode} iface=${ifc} ip=${ip:-none} gw=${gw:-none} tailscale=${tsname:-unknown}(${tsip:-none})"
  fi
}

state="INIT"
suppress_static=0
last_carrier="-1"
wifi_lock_carrier="-1"

log "Starting net-failover. MGMT_IF=$MGMT_IF (carrier via $ETH_LINK_IF) WIFI_IF=${WIFI_IF:-none}"
log "Rule: after failover to DHCP/WIFI, STATIC is suppressed until Ethernet carrier changes."

while true; do
  curr_carrier=0
  if carrier "$ETH_LINK_IF"; then curr_carrier=1; fi
  log "DEBUG: curr_carrier=$curr_carrier"
  
  if [[ "$curr_carrier" != "$last_carrier" ]]; then
    last_carrier="$curr_carrier"
    suppress_static=0
    log "Ethernet carrier changed on $ETH_LINK_IF -> $curr_carrier ; STATIC retries re-enabled."
    [[ "$curr_carrier" == "0" ]] && eth_clear
  fi

  if [[ "$state" == "WIFI" ]]; then
    wifi_up || true
    if connectivity_ok "$WIFI_IF"; then
      report_connected "wifi-dhcp" "$WIFI_IF"
      if [[ "$wifi_lock_carrier" == "$curr_carrier" ]]; then
        sleep "$CHECK_INTERVAL"; continue
      else
        log "Carrier changed while on WIFI; allowing wired attempts again."
        state="INIT"
      fi
    else
      log "WIFI failed; moving to DIRECT fallback on $MGMT_IF ($FALLBACK_CIDR)."
      wifi_down
      state="DIRECT"
    fi
  fi

  if [[ "$state" == "DIRECT" ]]; then
    eth_direct_up || true
    report_connected "wired-direct" "$MGMT_IF"
    sleep "$CHECK_INTERVAL"
    continue
  fi

  if [[ "$curr_carrier" == "1" ]]; then
    if [[ "$state" != "STATIC_ETH" && "$state" != "DHCP_ETH" ]]; then
      wifi_down
      if [[ "$suppress_static" == "0" ]]; then
        log "Wired link present; trying WIRED STATIC on $MGMT_IF ($STATIC_CIDR gw $STATIC_GW)"
        eth_static_up || true
        state="STATIC_ETH"
        sleep 2
      else
        log "Wired link present; STATIC suppressed; trying WIRED DHCP on $MGMT_IF"
        eth_dhcp_up || true
        state="DHCP_ETH"
        sleep 5
      fi
    fi

    if [[ "$state" == "STATIC_ETH" ]]; then
      if connectivity_ok "$MGMT_IF"; then
        report_connected "wired-static" "$MGMT_IF"
        sleep "$CHECK_INTERVAL"; continue
      fi
      log "WIRED STATIC failed; switching to WIRED DHCP and suppressing STATIC until carrier change."
      suppress_static=1
      log "DEBUG: calling eth_dhcp_up"
      eth_dhcp_up || true
      log "DEBUG: eth_dhcp_up finished"
      state="DHCP_ETH"
      sleep 5
      log "DEBUG: End of loop iteration (STATIC_ETH fail path)"
    fi

    if [[ "$state" == "DHCP_ETH" ]]; then
      if connectivity_ok "$MGMT_IF"; then
        report_connected "wired-dhcp" "$MGMT_IF"
        sleep "$CHECK_INTERVAL"; continue
      fi
      log "WIRED DHCP failed; moving to WIFI (STATIC still suppressed until carrier change)."
      eth_clear
      state="WIFI"
      wifi_lock_carrier="$curr_carrier"
      sleep 1
      continue
    fi
  else
    if [[ "$state" != "WIFI" ]]; then
      log "No wired carrier; moving to WIFI DHCP."
      eth_clear
      state="WIFI"
      wifi_lock_carrier="$curr_carrier"
      sleep 1
      continue
    fi
  fi

  sleep "$CHECK_INTERVAL"
done
