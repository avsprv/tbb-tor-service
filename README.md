## Usage

### Service Management

| Command | Description |
| :--- | :--- |
| `torctl start` | Start the background Tor service |
| `torctl stop` | Stop the background Tor service |
| `torctl restart` | Restart the service (use after updating bridges in Tor Browser) |
| `torctl status` | Show systemd service status |
| `torctl newip` (`reload`) | Request a new exit node IP without dropping bridge connections |
| `torctl country [code\|auto]` | Show or set exit node country (e.g. de, nl,fi, or auto) |
| `torctl check` | Verify SOCKS5 proxy connectivity and print current exit IP |
| `torctl logs [N]` | Show last N log lines (default: 25) |
| `torctl follow` | Stream live logs (Ctrl+C to exit) |
| `torctl uninstall` (`remove`) | Completely remove the service, data directory, and shell helpers |
| `torctl help` | Show the CLI help message |

### Exit Lists & Network API

| Command | Description |
| :--- | :--- |
| `torctl exitlist [IP]` | Download torbulkexitlist or check if a specific IP is an exit node |
| `torctl exitaddrs [filter]` | Download exit-addresses (with fingerprints) or filter by IP/ID |
| `torctl relay [IP\|fingerprint]` | Query Onionoo API for relay details (alias: onionoo, defaults to current exit IP) |

### Examples & Proxy Endpoint

The service exposes a local **SOCKS5 / SOCKS5h** proxy at 127.0.0.1:9050. You can route any CLI tool through Tor using the `withtor` helper alias:

```bash
# Check your current Tor exit IP
torctl check

# Lock exit nodes to Netherlands or Finland (comma-separated, no spaces)
torctl country nl,fi

# Run any command through Tor (sets ALL_PROXY and HTTP_PROXY)
withtor curl -s https://ifconfig.me
```
