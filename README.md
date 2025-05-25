# Mullvad Socks5 Proxy

**mullsocks** provides a convenient way to run a [Mullvad VPN](https://mullvad.net) SOCKS5 proxy inside a Docker container. With this tool, you can selectively route application traffic through Mullvad VPN using the SOCKS5 proxy, instead of forcing all system network traffic through the VPN. This approach is ideal for scenarios where you only want certain apps to use the VPN connection.

## Features

- **SOCKS5 Proxy on Mullvad**: Easily create a SOCKS5 proxy secured by Mullvad VPN.
- **Dockerized**: Runs as a lightweight, isolated Docker container.
- **Flexible App Routing**: Let chosen apps use the VPN by configuring their SOCKS5 proxy settings.
- **Easy Management**: Simple shell script to deploy, configure, and stop the proxy.

## Requirements

- [Docker](https://www.docker.com/)
- [Mullvad](https://mullvad.net) account

## Usage

1. **Clone this repository:**
```sh
git clone https://github.com/vietanhduong/mullsocks.git
cd mullsocks
# Or
curl -SLO https://raw.githubusercontent.com/vietanhduong/mullsocks/main/mullsocks.sh && chmod +x ./mullsocks.sh
```

2. **Start the proxy:**
```console
$ ./mullsocks.sh --help
Usage: mullsocks.sh [FLAGS]
Deploy and manage a Mullvad SOCKS5 proxy container.

Examples:
  # Quick start with default settings
  $ mullsocks.sh --account <your_account_number>

  # Change server location
  $ mullsocks.sh --account <your_account_number> --location sg

  # Change port
  $ mullsocks.sh --account <your_account_number> --port 1081

  # Stop the mullsocks container
  $ mullsocks.sh --stop

Flags:
  -h, --help              Show this help message
      --config-dir        Directory for mullsocks configuration (default: '/Users/x00/.mullsocks')
      --stop              Stop the mullsocks container
  -a, --account           Mullvad account number
  -p, --port              Port to use for the SOCKS5 proxy (default: 1080)
  -l, --location          Mullvad server location. Use quotes for multiple words (e.g., 'hk hkg') (default: 'hk')
```

## How It Works

- The script launches a Docker container configured with Mullvad VPN and exposes a local SOCKS5 proxy.
- Set your application to use `localhost:<port>` as a SOCKS5 proxy, and its traffic will route via Mullvad.
- You don’t need to change your system’s whole network routing.

## License

[MIT](LICENSE)

## Disclaimer
* This project is not affiliated with Mullvad. Use at your own risk.
