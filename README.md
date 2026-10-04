# OpenVPN SOCKS5 Proxy

A lightweight Docker-based SOCKS5 proxy that routes selected application traffic through an OpenVPN connection.

The project runs both **OpenVPN** and **Dante SOCKS5** inside a Docker container and exposes a local SOCKS5 proxy on `127.0.0.1:1080`.

This allows applications such as browsers, Telegram, development tools, or Proxifier to use the VPN connection without routing all host traffic through the VPN.

## Architecture

```text
┌──────────────────────┐
│       Host OS        │
│                      │
│ Browser ─────────┐   │
│ Telegram ────────┤   │
│ Proxifier ───────┤   │
│                  │   │
│      SOCKS5      │   │
│  127.0.0.1:1080  │   │
└─────────┬────────────┘
          │
          ▼
┌──────────────────────┐
│   Docker Container   │
│                      │
│    Dante SOCKS5      │
│          │           │
│          ▼           │
│       OpenVPN        │
│          │           │
│         tun0         │
└─────────┬────────────┘
          │
          ▼
      VPN Server
          │
          ▼
       Internet
```

Applications configured to use the SOCKS5 proxy:

```text
Application → 127.0.0.1:1080 → Dante → OpenVPN → Internet
```

All other applications continue using the host's normal Internet connection:

```text
Application → Host network → Internet
```

## Features

- OpenVPN client running inside Docker
- SOCKS5 proxy provided by Dante
- Selective VPN routing
- No system-wide VPN connection required
- Compatible with Proxifier
- Compatible with applications that support SOCKS5 directly
- Isolated VPN networking using Docker
- TUN/TAP support
- Automatic container restart
- VPN credentials and certificates kept outside the Docker image

## Requirements

You need:

- Docker
- Docker Compose
- a valid OpenVPN client configuration
- OpenVPN credentials/private-key password if required

Tested primarily with Docker Desktop on Windows.

## Project structure

```text
vpn-proxy/
├── Dockerfile
├── docker-compose.yml
├── start.sh
├── .gitignore
├── README.md
├── LICENSE
└── vpn/
    ├── vpn.ovpn.example
    └── vpn.pass.example
```
The Dante configuration is generated dynamically by `start.sh`
after the OpenVPN `tun0` interface becomes available.

The real VPN configuration and credentials should **not** be committed to Git.

## Configuration

### 1. OpenVPN configuration

Place your OpenVPN client configuration in:

```text
vpn/vpn.ovpn
```

For example:

```text
vpn/
└── vpn.ovpn
```

The configuration must be a valid OpenVPN client configuration supplied by your VPN provider or VPN server administrator.

### 2. Private key password

If the OpenVPN private key is encrypted and OpenVPN requests a password during connection, create:

```text
vpn/vpn.pass
```

and put the password into this file.

The container starts OpenVPN using:

```bash
openvpn \
  --config /vpn/vpn.ovpn \
  --askpass /vpn/vpn.pass
```

Do not commit the real password to Git.

## SOCKS5 configuration

The SOCKS5 proxy listens on:

```text
Host: 127.0.0.1
Port: 1080
Protocol: SOCKS5
```

No SOCKS username or password is required by the default configuration.

Example application configuration:

```text
Proxy type: SOCKS5
Host:       127.0.0.1
Port:       1080
Username:   <empty>
Password:   <empty>
```

Do not enter:

```text
socks5://127.0.0.1
```

into applications that expect a separate host field.

Use only:

```text
127.0.0.1
```
Or:

```text
localhost
```
## Running

Build and start the container:

```bash
docker compose up -d --build
```

Check its status:

```bash
docker compose ps
```

View logs:

```bash
docker logs -f vpn-proxy
```

A successful OpenVPN connection should contain:

```text
Initialization Sequence Completed
```

## Verify the proxy

First check your normal public IP:

```bash
curl.exe https://api.ipify.org
```

Then make the same request through SOCKS5:

```bash
curl.exe --socks5 127.0.0.1:1080 https://api.ipify.org
```

The second command should return the public IP address of the VPN connection.

For example:

```text
Normal connection:

curl.exe https://api.ipify.org
203.0.113.10


SOCKS5 + OpenVPN:

curl.exe --socks5 127.0.0.1:1080 https://api.ipify.org
198.51.100.20
```

If the addresses are different, traffic through SOCKS5 is being routed through the VPN.

## Using with Telegram

Open:

```text
Settings
→ Advanced
→ Connection type
→ Use custom proxy
```

Select:

```text
SOCKS5
```

Configure:

```text
Host:     127.0.0.1
Port:     1080
Username:
Password:
```

## Using with Proxifier

Create a proxy server:

```text
Address: 127.0.0.1
Port:    1080
Protocol: SOCKS5
```

Then create Proxification Rules for applications that should use the VPN.

For example:

```text
telegram.exe → SOCKS5 127.0.0.1:1080
browser.exe  → SOCKS5 127.0.0.1:1080

Default → Direct
```

This keeps all other system traffic outside the VPN.

## Using with Python

Install SOCKS support for `requests`:

```bash
pip install "requests[socks]"
```

Example:

```python
import requests

proxies = {
    "http": "socks5h://127.0.0.1:1080",
    "https": "socks5h://127.0.0.1:1080",
}

response = requests.get(
    "https://api.ipify.org",
    proxies=proxies,
    timeout=10,
)

print(response.text)
```

Using `socks5h` also routes hostname resolution through the SOCKS proxy.

## Security

Never commit real VPN credentials or private keys.

Recommended `.gitignore`:

```gitignore
vpn/*.ovpn
vpn/*.pass
vpn/*.key
vpn/*.crt

.env
```

Example/template files can be committed instead:

```text
vpn/vpn.ovpn.example
vpn/vpn.pass.example
```

Before publishing the repository, check the complete Git history for accidentally committed credentials.

Removing a secret only from the latest commit does not remove it from previous commits.

If a real credential or private key has ever been published, consider it compromised and rotate/revoke it.

## Troubleshooting

### SOCKS5 port is not listening

Check:

```bash
docker exec -it vpn-proxy ss -tlnp
```

Expected:

```text
0.0.0.0:1080
```

### Check the VPN interface

```bash
docker exec -it vpn-proxy ip addr show tun0
```

A successful VPN connection should create a `tun0` interface with an address similar to:

```text
inet 10.8.0.x
```

### Check OpenVPN

```bash
docker exec -it vpn-proxy ps aux
```

An OpenVPN process should be running.

### Proxy works only while the container is running

This is expected.

The proxy path is:

```text
SOCKS5 → OpenVPN → Internet
```

The container provides both the SOCKS5 server and VPN connection.

The OpenVPN Connect desktop application is not required when OpenVPN is running inside this container.

## How it works

The container establishes its own OpenVPN connection and receives a VPN interface (`tun0`).

Dante accepts SOCKS5 connections on port `1080` and sends proxied traffic through the VPN connection.

Docker publishes port `1080` to the host, allowing selected host applications to connect to the proxy.

As a result, the host itself does not need to use the VPN as its default gateway.

This provides application-level split tunneling without changing the host's global network configuration.

## Disclaimer

This project is intended for legitimate networking, development, testing, and privacy use cases.

Make sure your use complies with the policies of your network, VPN provider, and applicable laws.

## License

MIT
