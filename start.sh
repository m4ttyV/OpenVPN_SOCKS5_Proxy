#!/bin/sh
set -e

echo "[vpn-proxy] Starting OpenVPN..."

openvpn \
    --config /vpn/vpn.ovpn \
    --askpass /vpn/vpn.pass &

OPENVPN_PID=$!

echo "[vpn-proxy] Waiting for tun0..."

while ! ip link show tun0 >/dev/null 2>&1; do
    if ! kill -0 "$OPENVPN_PID" 2>/dev/null; then
        echo "[vpn-proxy] ERROR: OpenVPN exited before tun0 was created"
        exit 1
    fi

    sleep 1
done

echo "[vpn-proxy] tun0 is up"

VPN_IP=""

while [ -z "$VPN_IP" ]; do
    VPN_IP=$(ip -4 addr show tun0 \
        | awk '/inet / {print $2}' \
        | cut -d/ -f1)

    sleep 1
done

echo "[vpn-proxy] VPN IP: $VPN_IP"
echo "[vpn-proxy] Generating Dante config..."

cat > /etc/danted.conf <<EOF
logoutput: stderr

internal: 0.0.0.0 port = 1080
external: $VPN_IP

socksmethod: none

user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF

echo "[vpn-proxy] Starting SOCKS5 on 0.0.0.0:1080..."

exec sockd -N 1 -f /etc/danted.conf