# Deployment Guide: ProxNodeFailover

Follow these steps to deploy your network failover tool to your Proxmox node.

## 💻 1. On Your Mac (Local Terminal)

First, build the Debian package locally and copy it to your Proxmox server.

**Step 1.1: Build the package**
Run this in your current terminal:
```bash
./build_deb.sh
```
*Expected Output:* `Package built: proxnodefailover_1.0.0_all.deb`

**Step 1.2: Transfer to Proxmox**
Copy the generated file to your node. You will likely be prompted for the root password of your Proxmox node.
```bash
scp proxnodefailover_1.0.0_all.deb root@192.168.1.127:/tmp/
```

---

## 🖥️ 2. On Proxmox (Remote Shell)

Now install and configure the package on the server itself.

**Step 2.1: Log in**
From your Mac terminal:
```bash
ssh root@192.168.1.127
```

**Step 2.2: Install the Package**
This command installs the tool and its dependencies (`dhclient`, `wpasupplicant`, etc.).
```bash
apt update
apt install --reinstall /tmp/proxnodefailover_1.0.0_all.deb
```
*Note: Using `--reinstall` ensures that even if you are reinstalling the same version (e.g., after a quick fix), it will overwrite the old files correctly.*


**Step 2.3: Run the Setup Wizard**
Now that the package is installed, run the interactive setup tool to configure your network and (optionally) install Tailscale.
```bash
prox-setup
```
This wizard will:
*   Inventory your system for WiFi hardware.
*   Ask for your preferences (Static IP, WiFi details, etc.).
*   Generate the configuration.
*   Install Tailscale (if requested).
*   Enable and start the service.

**Step 2.5: Monitoring & Logs**
You can monitor the service status in two ways:

1.  **Live Logs (Journal)**:
    Shows real-time failover decisions, IP status, and Tailscale info.
    ```bash
    journalctl -u net-failover -f
    ```
    *Look for lines starting with `STATUS:`.*

2.  **Physical Console**:
    The service automatically updates the login screen ("Issue Banner") on your physical monitor with the current **Management URL**, so you always know where to point your browser if the IP changes.


## 🧪 3. Testing & Validation

Once installed, you should verify the failover logic works as expected.

### Scenario A: Verify Normal Operation (Status 1)
1.  Ensure your ethernet cable is **connected**.
2.  Check the logs:
    ```bash
    journalctl -u net-failover -f
    # Expect: STATUS: Mode=wired-static ...
    ```
3.  Verify you can reach the internet: `ping 8.8.8.8`

### Scenario B: Verify Failover (Physical Test)
*Warning: This test will temporarily disconnect your SSH session.*

1.  **Unplug** the ethernet cable from the Proxmox node.
2.  Wait ~10-20 seconds.
3.  The node should switch to **WiFi Mode**.
4.  **Verification**:
    *   Look at the physical monitor/console. The banner should update to the WiFi IP.
    *   Or, check your router's client list for the Proxmox WiFi connection.
    *   Or, if you installed Tailscale, try SSHing to the **Tailscale IP**.
5.  **Recovery**: Plug the cable back in.
    *   Wait ~10 seconds.
    *   The node should switch back to `wired-static`.

---


## 🚨 Rollback (Uninstall)

If the installation causes issues, you can remove it cleanly from the Proxmox shell:

```bash
apt remove proxnodefailover
```
This stops the background service and removes the scripts.

### Restoring Legacy Version
When you installed this package, it automatically backed up your existing script and service file to:
*   `/usr/local/sbin/net-failover.sh.legacy_backup_<TIMESTAMP>`
*   `/etc/systemd/system/net-failover.service.legacy_backup_<TIMESTAMP>`

To restore your previous setup:
1.  Navigate to the directories:
    ```bash
    cd /usr/local/sbin/
    ```
2.  Find the backup:
    ```bash
    ls -l net-failover.sh.legacy*
    ```
3.  Restore it:
    ```bash
    cp net-failover.sh.legacy_backup_<DATE> net-failover.sh
    cp /etc/systemd/system/net-failover.service.legacy_backup_<DATE> /etc/systemd/system/net-failover.service
    ```
4.  Reload and restart:
    ```bash
    systemctl daemon-reload
    systemctl enable --now net-failover
    ```
