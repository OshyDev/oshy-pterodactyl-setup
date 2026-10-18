# Pterodactyl Bootstrap

A simple Bash installer for setting up Pterodactyl Panel and Wings on Ubuntu 24.04 LTS.

## Features

- Installs required packages for Pterodactyl Panel
- Downloads the latest Pterodactyl Panel release
- Installs PHP dependencies using Composer
- Runs the initial Panel setup commands
- Installs Docker and Pterodactyl Wings
- Creates a systemd service for Wings
- Includes a simple interactive installation menu
- Checks for existing Panel files before extracting the release

## Requirements

- Ubuntu 24.04 LTS
- Root or sudo access
- Internet connection
- A domain name for the Panel is recommended
- A database configured for the Panel
- Open ports and firewall rules configured for your setup

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR-USERNAME/ptero-bootstrap.git
cd ptero-bootstrap
```

Make the installer executable:

```bash
chmod +x install.sh
```

Run the installer:

```bash
sudo ./install.sh
```

Choose an option from the installation menu.

## Installation Options

| Option | Description |
|---|---|
| 1 | Install Panel dependencies |
| 2 | Install Pterodactyl Panel |
| 3 | Install Docker and Wings |
| 4 | Install dependencies and Panel |
| 0 | Exit |

## Wings Configuration

After installing Wings, create a node in the Pterodactyl Panel and generate its configuration.

Save the configuration to:

```text
/etc/pterodactyl/config.yml
```

Start Wings:

```bash
sudo systemctl start wings
```

Check the service status:

```bash
sudo systemctl status wings --no-pager
```

Enable Wings at boot:

```bash
sudo systemctl enable wings
```

## Important

This project is a basic installer and does not automatically configure every production requirement.

You must configure the following separately:

- Database and database user
- NGINX virtual host
- HTTPS certificate
- Panel cron job
- Queue worker
- Firewall rules and allocation ports
- Wings node configuration

Always review the official documentation before using the installation on a production server.

## Official Documentation

- [Pterodactyl Documentation](https://docs.pterodactyl.io/)
- [Pterodactyl Panel](https://github.com/pterodactyl/panel)
- [Pterodactyl Wings](https://github.com/pterodactyl/wings)

## Disclaimer

This project is provided as-is, without any warranty.

Always test on a fresh server and back up important data before making system changes.

Pterodactyl is an independent project. This repository is not affiliated with or endorsed by the official Pterodactyl team.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
