#!/usr/bin/env bash
set -euo pipefail

TBB_DIR="$HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser"
TOR_BIN="$TBB_DIR/TorBrowser/Tor/tor"
TOR_LIBS="$TBB_DIR/TorBrowser/Tor"
LYREBIRD_BIN="$TBB_DIR/TorBrowser/Tor/PluggableTransports/lyrebird"
TBB_TORRC="$TBB_DIR/TorBrowser/Data/Tor/torrc"

DATA_DIR="$HOME/.local/share/tbb-tor-bg"
CUSTOM_TORRC="$DATA_DIR/torrc.custom"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_USER_DIR/tbb-tor.service"
BASHRC="$HOME/.bashrc"
BASHRC_D_DIR="$HOME/.bashrc.d"
HELPER_FILE="$BASHRC_D_DIR/tbb-tor.sh"

check_bashrc_d_inclusion() {
    if [[ ! -f "$BASHRC" ]] || ! grep -qE '\.bashrc\.d' "$BASHRC"; then
        echo "Warning: Your $BASHRC does not appear to source $BASHRC_D_DIR automatically."
        echo "To enable 'torctl' and 'withtor' in new shells, add the following lines to $BASHRC:"
        echo ""
        echo '  if [ -d ~/.bashrc.d ]; then'
        # shellcheck disable=SC2016
        echo '      for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done'
        echo '  fi'
        echo ""
    fi
}

is_service_installed() {
    [[ -f "$SERVICE_FILE" ]] || systemctl --user list-unit-files "tbb-tor.service" 2>/dev/null | grep -q "^tbb-tor.service"
}

uninstall_service() {
    local found=0

    if is_service_installed; then
        found=1
        echo "Stopping and disabling tbb-tor.service..."
        systemctl --user disable --now tbb-tor.service 2>/dev/null || true

        if [[ -f "$SERVICE_FILE" ]]; then
            rm -f "$SERVICE_FILE"
            echo "Removed $SERVICE_FILE"
        fi

        systemctl --user daemon-reload
        systemctl --user reset-failed 2>/dev/null || true
    else
        echo "Notice: tbb-tor.service is not currently installed."
    fi

    if [[ -d "$DATA_DIR" ]]; then
        found=1
        rm -rf "$DATA_DIR"
        echo "Removed $DATA_DIR"
    fi

    if [[ -f "$HELPER_FILE" ]]; then
        found=1
        rm -f "$HELPER_FILE"
        echo "Removed $HELPER_FILE"
    fi

    if [[ $found -eq 0 ]]; then
        echo "Nothing to uninstall. System is already clean."
    else
        echo "Uninstall complete."
    fi
}

install_service() {
    if [[ ! -x "$TOR_BIN" || ! -x "$LYREBIRD_BIN" ]]; then
        echo "Error: Tor Browser binaries not found in $TBB_DIR" >&2
        exit 1
    fi

    if [[ ! -f "$TBB_TORRC" ]]; then
        echo "Error: Tor Browser torrc not found at $TBB_TORRC. Launch Tor Browser once to generate it." >&2
        exit 1
    fi

    if is_service_installed; then
        local current_state
        current_state=$(systemctl --user is-active tbb-tor.service 2>/dev/null || echo "inactive")
        echo "Notice: tbb-tor.service is already installed (status: $current_state). Updating configuration..."
    else
        echo "Installing tbb-tor.service..."
    fi

    mkdir -p "$DATA_DIR" "$SYSTEMD_USER_DIR" "$BASHRC_D_DIR"
    ln -sf "$TBB_TORRC" "$DATA_DIR/torrc"

    if [[ ! -f "$CUSTOM_TORRC" ]]; then
        cat << TORRC > "$CUSTOM_TORRC"
%include $DATA_DIR/torrc
# ExitNodes {de}
# StrictNodes 1
TORRC
    fi

    cat << UNIT > "$SERVICE_FILE"
[Unit]
Description=Tor daemon from Tor Browser (headless)
After=network-online.target

[Service]
Type=simple
WorkingDirectory=$TBB_DIR
Environment="LD_LIBRARY_PATH=$TOR_LIBS"
ExecStart=$TOR_BIN -f $CUSTOM_TORRC --DataDirectory $DATA_DIR --SocksPort 127.0.0.1:9050 --ControlPort 0 --DisableNetwork 0 --ClientTransportPlugin "webtunnel,obfs4 exec $LYREBIRD_BIN"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
UNIT

    systemctl --user daemon-reload
    systemctl --user enable --now tbb-tor.service

    cat << 'ALIASES' > "$HELPER_FILE"
# shellcheck shell=bash
# tbb-tor helper functions, completions, and aliases

_torctl_parse_onionoo() {
    python3 - "$1" << 'PY'
import sys
import json

file_path = sys.argv[1]
try:
    with open(file_path, "r", encoding="utf-8") as f:
        raw = f.read().strip()
except Exception as e:
    print(f"Error reading response file: {e}")
    sys.exit(1)

if not raw:
    print("Error: Empty response from Onionoo API.")
    sys.exit(1)

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print("Error: Invalid JSON received from Onionoo API.")
    print(raw[:300])
    sys.exit(1)

relays = data.get("relays", [])
if not relays:
    print("No matching relays found in Onionoo.")
    sys.exit(0)

for r in relays:
    or_ips = r.get("or_addresses", [])
    exit_ips = r.get("exit_addresses", [])
    all_ips = ", ".join(or_ips + exit_ips)
    flags = ", ".join(r.get("flags", []))
    bw = r.get("observed_bandwidth", 0) / (1024 * 1024)
    country_code = r.get("country", "").upper()

    print(f"Nickname:    {r.get('nickname')}")
    print(f"Fingerprint: {r.get('fingerprint')}")
    print(f"OR/Exit IPs: {all_ips}")
    print(f"Country:     {r.get('country_name')} ({country_code})")
    print(f"AS / ISP:    {r.get('as')} - {r.get('as_name')}")
    print(f"Flags:       {flags}")
    print(f"Bandwidth:   {bw:.2f} MB/s")
    print(f"Platform:    {r.get('platform')}")
    print(f"Last Seen:   {r.get('last_seen')}")
    print("-" * 45)
PY
}

torctl() {
    local custom_torrc="$HOME/.local/share/tbb-tor-bg/torrc.custom"
    local base_torrc="$HOME/.local/share/tbb-tor-bg/torrc"
    local service_file="$HOME/.config/systemd/user/tbb-tor.service"
    local helper_file="$HOME/.bashrc.d/tbb-tor.sh"
    local proxy="socks5h://127.0.0.1:9050"

    local check_host="check.torproject.org"
    local onionoo_host="onionoo.torproject.org"
    local api_ip_url="https://${check_host}/api/ip"
    local exitlist_url="https://${check_host}/torbulkexitlist"
    local exitaddrs_url="https://${check_host}/exit-addresses"

    case "${1:-}" in
        start|stop|restart|status)
            systemctl --user "$1" tbb-tor.service
            ;;
        newip|reload)
            echo "Requesting new Tor circuit (new exit IP)..."
            systemctl --user reload tbb-tor.service
            sleep 2
            curl -fsSL --max-time 15 -x "$proxy" "$api_ip_url" || echo "Error: Proxy is unreachable"
            echo ""
            ;;
        country)
            if [[ -z "${2:-}" ]]; then
                echo "Current exit node config:"
                grep -E "^#?\s*(ExitNodes|StrictNodes)" "$custom_torrc" 2>/dev/null || echo "Default (any country)"
                echo ""
                echo "Usage: torctl country <code|auto>"
                echo "Examples: torctl country de | torctl country nl,fi | torctl country auto"
                return 0
            fi

            if [[ "$2" == "auto" || "$2" == "any" || "$2" == "reset" ]]; then
                cat << TORRC > "$custom_torrc"
%include $base_torrc
# ExitNodes {de}
# StrictNodes 1
TORRC
                echo "Exit node country reset to automatic (any country)."
            else
                local formatted
                formatted=$(echo "$2" | tr '[:upper:]' '[:lower:]' | sed 's/[{} ]//g; s/[^a-z,]//g; s/\([a-z]\{2\}\)/{\1}/g')
                cat << TORRC > "$custom_torrc"
%include $base_torrc
ExitNodes $formatted
StrictNodes 1
TORRC
                echo "Exit node country locked to: $formatted"
            fi

            systemctl --user reload tbb-tor.service
            sleep 2
            curl -fsSL --max-time 15 -x "$proxy" "$api_ip_url" || echo "Error: Proxy is unreachable"
            echo ""
            ;;
        check)
            echo "Checking Tor SOCKS5 proxy at 127.0.0.1:9050..."
            curl -fsSL --max-time 15 -x "$proxy" "$api_ip_url" || echo "Error: Proxy is unreachable or still bootstrapping"
            echo ""
            ;;
        exitlist)
            if [[ -z "${2:-}" ]]; then
                curl -fsSL --compressed --max-time 20 -x "$proxy" "$exitlist_url"
            else
                echo "Checking if $2 is a Tor exit node..."
                if curl -fsSL --compressed --max-time 20 -x "$proxy" "$exitlist_url" | grep -Fxq "$2"; then
                    echo "MATCH: $2 is an active Tor exit node."
                else
                    echo "NO MATCH: $2 is not in the current bulk exit list."
                fi
            fi
            ;;
        exitaddrs)
            if [[ -z "${2:-}" ]]; then
                curl -fsSL --compressed --max-time 20 -x "$proxy" "$exitaddrs_url"
            else
                curl -fsSL --compressed --max-time 20 -x "$proxy" "$exitaddrs_url" | grep -i -B 1 -A 2 "$2" || echo "No entries matching '$2' found."
            fi
            ;;
        relay|onionoo)
            local target="${2:-}"
            if [[ -z "$target" ]]; then
                target=$(curl -fsSL --max-time 15 -x "$proxy" "$api_ip_url" | grep -oE '"IP":"[^"]+"' | cut -d'"' -f4)
                if [[ -z "$target" ]]; then
                    echo "Error: Could not determine current exit IP. Provide an IP or fingerprint manually." >&2
                    return 1
                fi
                echo "Querying Onionoo API for current exit IP: $target"
            else
                echo "Querying Onionoo API for: $target"
            fi

            local api_url="https://${onionoo_host}/details?search=${target}&limit=5"
            if command -v python3 >/dev/null 2>&1; then
                local tmp_json
                tmp_json=$(mktemp)
                # shellcheck disable=SC2064
                trap "rm -f '$tmp_json'" RETURN

                if curl -fsSL --compressed --max-time 25 -x "$proxy" "$api_url" -o "$tmp_json"; then
                    _torctl_parse_onionoo "$tmp_json"
                else
                    echo "Error: Failed to fetch data from Onionoo API." >&2
                    return 1
                fi
            else
                curl -fsSL --compressed --max-time 25 -x "$proxy" "$api_url"
                echo ""
            fi
            ;;
        logs)
            journalctl --user -u tbb-tor -n "${2:-25}" --no-pager
            ;;
        follow)
            journalctl --user -u tbb-tor -f
            ;;
        uninstall|remove)
            local has_unit=0
            if [[ -f "$service_file" ]] || systemctl --user list-unit-files "tbb-tor.service" 2>/dev/null | grep -q "^tbb-tor.service"; then
                has_unit=1
            fi

            if [[ $has_unit -eq 0 && ! -d "$HOME/.local/share/tbb-tor-bg" ]]; then
                echo "Notice: tbb-tor.service is not installed."
                if [[ -f "$helper_file" ]]; then
                    read -r -p "Remove remaining shell helper $helper_file? [y/N] " confirm_helper
                    if [[ "$confirm_helper" =~ ^[Yy]$ ]]; then
                        rm -f "$helper_file"
                        echo "Removed $helper_file."
                        complete -r torctl withtor 2>/dev/null || true
                        unalias withtor 2>/dev/null || true
                        unset -f torctl _torctl_completions _torctl_parse_onionoo
                    fi
                fi
                return 0
            fi

            read -r -p "Are you sure you want to completely remove tbb-tor.service? [y/N] " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                systemctl --user disable --now tbb-tor.service 2>/dev/null || true
                rm -f "$service_file"
                systemctl --user daemon-reload
                systemctl --user reset-failed 2>/dev/null || true
                rm -rf "$HOME/.local/share/tbb-tor-bg"
                rm -f "$helper_file"
                echo "tbb-tor.service, data directory, and $helper_file removed."
                complete -r torctl withtor 2>/dev/null || true
                unalias withtor 2>/dev/null || true
                unset -f torctl _torctl_completions _torctl_parse_onionoo
            else
                echo "Uninstall aborted."
            fi
            ;;
        help|-h|--help)
            cat << 'HELP'
torctl - Control background Tor daemon (tbb-tor.service)

Usage:
  torctl <command> [arguments]

Service Management:
  start                            Start the background Tor service
  stop                             Stop the background Tor service
  restart                          Restart the service (use after updating bridges in Tor Browser)
  status                           Show systemd service status
  newip | reload                   Request a new exit node IP without dropping bridge connections
  country [code|auto]              Show or set exit node country (e.g., de, nl,fi, or auto)
  check                            Verify SOCKS5 proxy connectivity and print current exit IP
  logs [N]                         Show last N log lines (default: 25)
  follow                           Stream live logs (Ctrl+C to exit)
  uninstall | remove               Completely remove the service, data directory, and shell helpers
  help                             Show this help message

Tor Exit Lists & Network API:
  exitlist [IP]                    Download torbulkexitlist or check if a specific IP is an exit node
  exitaddrs [filter]               Download exit-addresses (with fingerprints) or filter by IP/ID
  relay | onionoo [IP|fingerprint] Query Onionoo API for relay details (defaults to current exit IP)

Proxy Endpoint:
  SOCKS5 / SOCKS5h:                127.0.0.1:9050

Alias:
  withtor <cmd>                    Run any CLI command with ALL_PROXY/HTTP_PROXY set to Tor
                                   Example: withtor curl -s https://ifconfig.me
HELP
            ;;
        *)
            echo "Unknown command: '${1:-}'. Run 'torctl help' for usage information."
            return 1
            ;;
    esac
}

# Bash completion for torctl
_torctl_completions() {
    local cur prev commands countries
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    commands="start stop restart status newip reload country check exitlist exitaddrs relay onionoo logs follow uninstall help"
    countries="auto de nl fi se ch fr us gb ca at pl"

    if [[ $COMP_CWORD -eq 1 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
    elif [[ $COMP_CWORD -eq 2 && "$prev" == "country" ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$countries" -- "$cur")
    elif [[ $COMP_CWORD -eq 2 && "$prev" == "logs" ]]; then
        mapfile -t COMPREPLY < <(compgen -W "25 50 100 200" -- "$cur")
    fi
}
complete -F _torctl_completions torctl

# Run any CLI command routed through the background Tor SOCKS5 proxy
alias withtor='ALL_PROXY=socks5h://127.0.0.1:9050 HTTP_PROXY=socks5h://127.0.0.1:9050 HTTPS_PROXY=socks5h://127.0.0.1:9050'
complete -c withtor
ALIASES

    echo "Helper functions, bash completion, and alias written to $HELPER_FILE."
    check_bashrc_d_inclusion
    echo "Setup complete. Run 'source $HELPER_FILE' to apply changes to your current shell."
}

case "${1:-install}" in
    install|--install|-i)
        install_service
        ;;
    uninstall|remove|--uninstall|--remove|-u)
        uninstall_service
        ;;
    *)
        echo "Usage: $0 [--install | --uninstall]"
        exit 1
        ;;
esac
