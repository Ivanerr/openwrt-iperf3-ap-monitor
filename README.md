# OpenWRT Mesh Speed Monitor 🚀

A simple Lua script for OpenWRT to test iperf3 speeds between your main router and mesh APs (wired/wireless). Sends Telegram alerts 📱 if speeds drop below a threshold or if APs are unreachable.

## Features ✨
- Tests multiple APs with configurable IPs and names.
- JSON parsing of iperf3 results for accurate Mbps calculation.
- Threshold-based alerts (default: 200 Mbps).
- Runs as a scheduled task (e.g., via cron).
- Verbose logging for debugging.

## Installation 📥
1. Install dependencies on your main OpenWRT router:

```sh
opkg update
opkg install lua luci-lib-jsonc curl
```

2. Download the script using wget::

```sh
wget https://raw.githubusercontent.com/Ivanerr/openwrt-iperf3-ap-monitor/main/iperf3_mesh_speed_test.lua -O /usr/bin/iperf3_mesh_speed_test.lua
```

3. Make it executable:
```sh
chmod +x /usr/bin/iperf3_mesh_speed_test.lua
```

## Configuration ⚙️
Edit the script (`vi /usr/bin/iperf3_mesh_speed_test.lua`) to set:
- `TELEGRAM_TOKEN`: Your Telegram bot token.
- `CHAT_ID`: Your Telegram chat ID.
- `THRESHOLD_MBPS`: Alert threshold in Mbps (default: 200).
- `AP_LIST`: Array of APs with names and IPs.

## Usage ▶️
Run manually:
```sh
lua /usr/bin/iperf3_mesh_speed_test.lua
```

Schedule via cron (e.g., every 30 minutes):
1. Edit crontab: `crontab -e`
2. Add: `*/30 * * * * /usr/bin/lua /usr/bin/iperf3_mesh_speed_test.lua`

## AP Server Setup 🛡️
On each AP (running OpenWRT):
1. Install iperf3:
```sh
opkg update
opkg install iperf3
```

2. Start iperf3 server on boot by adding to `/etc/rc.local` (before `exit 0`):

/usr/bin/iperf3 -s -D
