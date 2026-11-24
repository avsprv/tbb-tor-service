# tbb-tor-service

Headless background `systemd --user` service and CLI control wrapper (`torctl`) that reuses Tor Browser's `tor` and `lyrebird` binaries (WebTunnel / obfs4 bridges) to provide a local SOCKS5 proxy at `127.0.0.1:9050` without keeping the browser window open.

## Features
- **Zero-conflict background daemon:** Runs on `127.0.0.1:9050` with isolated `DataDirectory`, allowing Tor Browser to run simultaneously on `127.0.0.1:9150`.
- **Automatic bridge sync:** Symlinks `torrc` directly from Tor Browser.
- **Modular shell integration:** Installs `torctl`, `withtor` alias, and bash completion into `~/.bashrc.d/tbb-tor.sh` without modifying `~/.bashrc`.
- **Exit node & API tools:** Rotate exit IPs (`newip`), lock exit countries (`country`), check bulk exit lists, and query relay details via Onionoo API.

## Requirements
- Linux with `systemd` user session
- Installed [Tor Browser](https://torproject.org) (launched at least once to generate `torrc` and configure bridges)
- `curl`, `bash`, `python3` (optional, for formatted Onionoo output)

## Quick Install
```bash
git clone https://github.com<YOUR_USERNAME>/tbb-tor-service.git
cd tbb-tor-service
./setup-tbb-tor.sh
source ~/.bashrc.d/tbb-tor.sh
```
## Usage

### Service Management

| Command | Description |
| :--- | :--- |
| `torctl start` | Start the background Tor service |
| `torctl stop` | Stop the background Tor service |
| `torctl restart` | Restart the service (use after updating bridges in Tor Browser) |
| `torctl status` | Show `systemd` service status |
| `torctl newip` (`reload`) | Request a new exit node IP without dropping bridge connections |
| `torctl country [code\|auto]` | Show or set exit node country (e.g. de, nl,fi, or auto) |
| `torctl check` | Verify SOCKS5 proxy connectivity and print current exit IP |
| `torctl logs [N]` | Show last `N` log lines (default: `25`) |
| `torctl follow` | Stream live logs (`Ctrl+C` to exit) |
| `torctl uninstall` (`remove`) | Completely remove the service, data directory, and shell helpers |
| `torctl help` | Show the CLI help message |

### Exit Lists & Network API

| Command | Description |
| :--- | :--- |
| `torctl exitlist [IP]` | Download `torbulkexitlist` or check if a specific IP is an exit node |
| `torctl exitaddrs [filter]` | Download `exit-addresses` (with fingerprints) or filter by IP/ID |
| `torctl relay [IP\|fingerprint]` | Query Onionoo API for relay details (alias: `onionoo`, defaults to current exit IP) |

### Examples & Proxy Endpoint

The service exposes a local **SOCKS5 / SOCKS5h** proxy at `127.0.0.1:9050`. You can route any CLI tool through Tor using the `withtor` helper alias:

```bash
# Check your current Tor exit IP
torctl check

# Lock exit nodes to Germany or Netherlands
torctl country de,nl

# Run any command through Tor (sets ALL_PROXY and HTTP_PROXY)
withtor curl -s https://ifconfig.me
```
