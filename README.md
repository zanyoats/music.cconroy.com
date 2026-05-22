# music.cconroy.com

Setup workflow and server notes for the Kukicha music server.

## Provisioning

Run the `Setup Music VPS` GitHub Actions workflow to create the Vultr instance. Set `kukicha_version` to choose the Kukicha package version installed during provisioning.

After provisioning, point DNS at the public IP reported by the workflow:

```text
music.cconroy.com  A  <server-public-ip>
```

Caddy is configured for `music.cconroy.com`, redirects HTTP to HTTPS, and proxies to Kukicha on `127.0.0.1:4533`.

The setup workflow enables Caddy for future boots, but does not start it during initial provisioning. After DNS points at the server, start Caddy:

```sh
rc-service caddy start
```

## Services

SSH into the server as root:

```sh
ssh root@<server-public-ip>
```

Check service status:

```sh
rc-service caddy status
rc-service kukicha status
```

Start services:

```sh
rc-service caddy start
rc-service kukicha start
```

Stop services:

```sh
rc-service caddy stop
rc-service kukicha stop
```

Restart services:

```sh
rc-service caddy restart
rc-service kukicha restart
```

Enable services on boot:

```sh
rc-update add caddy default
rc-update add kukicha default
```

Disable services on boot:

```sh
rc-update del caddy default
rc-update del kukicha default
```

## Logs

Cloud-init setup log:

```sh
tail -f /var/log/user-data.log
```

Kukicha logs:

```sh
tail -f /var/log/kukicha/kukicha.log
tail -f /var/log/kukicha/kukicha.err.log
```

Caddy logs/status:

```sh
rc-service caddy status
```

## Config

Kukicha config:

```text
/root/.config/kukicha/kukicha.toml
```

Deploy config changes or Kukicha version upgrades from this repo:

```text
GitHub Actions -> Deploy Kukicha
```

Run the deploy workflow manually with `workflow_dispatch`. Use `update_config` to copy `.github/workflows/assets/kukicha.toml`, and set `kukicha_version` to install a specific Kukicha version. You can deploy only the config, install only a version, or do both in one run. It restarts Kukicha only if the service is already running. It uses:

```text
vars.DEPLOY_HOST
secrets.DEPLOY_SSH_PRIVATE_KEY
```

Kukicha auth files:

```text
/root/.config/kukicha/password.hash
/root/.config/kukicha/opensubsonic.secret
```

Caddy config:

```text
/etc/caddy/Caddyfile
```

OpenRC service:

```text
/etc/init.d/kukicha
```

## Notes

The setup workflow installs Kukicha and Caddy, creates/enables their OpenRC services, but does not start either service during initial provisioning. Start Caddy after DNS is configured:

```sh
rc-service caddy start
```

Start Kukicha manually after moving any required local data, such as the database file:

```sh
rc-service kukicha start
```
