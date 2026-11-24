# tbb-tor-service

Headless background `systemd --user` service and CLI control wrapper (`torctl`) that reuses Tor Browser's `tor` and `lyrebird` binaries (WebTunnel / obfs4 bridges) to provide a local SOCKS5 proxy at `127.0.0.1:9050` without keeping the browser window open.

## Features
- **Zero-conflict background daemon:** Runs on `127.0.0.1:9050` with an isolated `DataDirectory` (`~/.local/share/tbb-tor-bg`), allowing Tor Browser to run simultaneously on `127.0.0.1:9150`.
- **Automatic bridge sync:** Symlinks `torrc` directly from Tor Browser while keeping custom exit node rules in `torrc.custom`.
- **Modular shell integration:** Installs `torctl`, `withtor` alias, and bash completion into `~/.bashrc.d/tbb-tor.sh` without modifying `~/.bashrc`.
- **Exit node & API tools:** Rotate exit IPs (`newip`), lock exit countries (`country`), check bulk exit lists, and query relay details via Onionoo API.

## Requirements
- Linux with `systemd` user session
- Installed [Tor Browser](https://torproject.org) in `~/.local/share/torbrowser/tbb/x86_64/tor-browser` (launched at least once to generate `torrc` and configure bridges)
- `curl`, `bash`, `python3` (optional, for formatted Onionoo output)

## Quick Install
```bash
git clone https://github.com
cd tbb-tor-service
./setup-tbb-tor.sh
source ~/.bashrc.d/tbb-tor.sh
```

> **Note:** Make sure your `~/.bashrc` sources `~/.bashrc.d/*` so `torctl` and `withtor` load automatically in new terminal sessions.

## Usage

### Service Management
```bash
torctl start                      # Start the background Tor service
torctl stop                       # Stop the background Tor service
torctl restart                    # Restart the service (use after updating bridges in Tor Browser)
torctl status                     # Show systemd service status
torctl newip | reload             # Request a new exit node IP without dropping bridge connections
torctl country [code|auto]        # Show or set exit node country (e.g. de, nl,fi, or auto)
torctl check                      # Verify SOCKS5 proxy connectivity and print current exit IP
torctl logs [N]                   # Show last N log lines (default: 25)
torctl follow                     # Stream live logs (Ctrl+C to exit)
torctl uninstall | remove         # Completely remove service, data directory, and shell helpers
torctl help                       # Show CLI help message
```

### Exit Lists & Network API
```bash
torctl exitlist [IP]                    # Download torbulkexitlist or check if a specific IP is an exit node
torctl exitaddrs [filter]               # Download exit-addresses (with fingerprints) or filter by IP/ID
torctl relay | onionoo [IP|fingerprint] # Query Onionoo API for relay details (defaults to current exit IP)
```

### Examples & Proxy Endpoint
The service exposes a local **SOCKS5 / SOCKS5h** proxy at `127.0.0.1:9050`. You can route any CLI command through Tor using the `withtor` helper alias (sets `ALL_PROXY`, `HTTP_PROXY`, and `HTTPS_PROXY`):

```bash
# Verify proxy connectivity and inspect current exit node details
torctl check
torctl relay

# Query Onionoo API for a specific relay by IP or fingerprint
torctl relay 185.220.101.1
torctl onionoo 9695DFC35FFEB861329B9F1AB04C46397020CE31

# Rotate exit IP without dropping active bridge connections
torctl newip

# Lock exit nodes to Netherlands or Finland, then reset back to automatic
torctl country nl,fi
torctl country auto

# Check if a specific IP is an active Tor exit node
torctl exitlist 185.220.101.1

# Run any CLI tool through Tor
withtor curl -s https://ifconfig.me
withtor git clone https://github.com
```

## Uninstall
You can remove the service, isolated data directory, and shell helpers either via `torctl` or the setup script:
```bash
torctl uninstall
# or
./setup-tbb-tor.sh --uninstall
```
