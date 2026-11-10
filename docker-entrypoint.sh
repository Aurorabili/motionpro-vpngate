#!/bin/bash
set -Eeuo pipefail

for var_name in MOTIONPRO_HOST MOTIONPRO_USER MOTIONPRO_PASSWORD; do
    if [[ -z "${!var_name:-}" ]]; then
        echo "Required environment variable is missing: ${var_name}" >&2
        exit 2
    fi
done

vpnd >/var/log/vpnd.log 2>&1 &
VPND_PID=$!
DANTED_PID=""

cleanup() {
    if [[ -n "${DANTED_PID}" ]]; then
        kill "${DANTED_PID}" 2>/dev/null || true
    fi
    kill "${VPND_PID}" 2>/dev/null || true
    MotionPro -s >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting MotionPro for ${MOTIONPRO_HOST}..."
MotionPro \
    -h "${MOTIONPRO_HOST}" \
    -u "${MOTIONPRO_USER}" \
    -p "${MOTIONPRO_PASSWORD}" \
    -l "${MOTIONPRO_LOG_LEVEL:-debug}" \
    -c inf

echo "Waiting for VPN connection..."
connected=0
for _ in $(seq 1 180); do
    if MotionPro -a 2>/dev/null | grep -q 'VPN Status: connected'; then
        connected=1
        break
    fi
    sleep 1
done

if [[ "${connected}" -ne 1 ]]; then
    echo "MotionPro did not reach VPN Status: connected" >&2
    exit 1
fi

# 可用 MOTIONPRO_DNS 显式指定 DNS，逗号分隔；
# 未指定时，从 MotionPro 日志读取 VPN 下发的 DNS。
dns_servers=()
if [[ -n "${MOTIONPRO_DNS:-}" ]]; then
    IFS=',' read -r -a dns_servers <<< "${MOTIONPRO_DNS}"
else
    while read -r dns_server; do
        [[ -n "${dns_server}" ]] && dns_servers+=("${dns_server}")
    done < <(
        grep -aohE 'dns server: [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
            /var/log/MotionPro/MotionPro_*.log 2>/dev/null \
          | awk '{print $3}' \
          | awk '!seen[$0]++'
    )
fi

if [[ "${#dns_servers[@]}" -eq 0 ]]; then
    echo "No VPN DNS found. Set MOTIONPRO_DNS to a comma-separated DNS list." >&2
    exit 1
fi

{
    for dns_server in "${dns_servers[@]}"; do
        printf 'nameserver %s\n' "${dns_server}"
    done
} > /etc/resolv.conf

echo "Using VPN DNS: ${dns_servers[*]}"

# Dante stays in the foreground; the script monitors it and VPN status.
danted -f /etc/danted.conf &
DANTED_PID=$!

echo "SOCKS5 proxy listening on port 1080 via tun0."
while kill -0 "${DANTED_PID}" 2>/dev/null; do
    if ! MotionPro -a 2>/dev/null | grep -q 'VPN Status: connected'; then
        echo "VPN disconnected; stopping proxy container." >&2
        exit 1
    fi
    sleep 5
done

wait "${DANTED_PID}"

