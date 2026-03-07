# Coder (Hosted vscode)

It's kind of difficult to set up real vscode-server since vscode requires electron, so I found [Coder](github.com/coder/code-server) which is a self-hosted vscode solution.

My instructions assume you use RHEL 8

## Dependencies

To actually use it in ppc64le without electron, we need a few hacks in place.

- Node.js 22 LTS
- Python 3.12 - Available in RHEL8:

  ```bash
  dnf install python3.12 python3.12-pip python3.12-setuptools python3.12-devel
  ```

## Install

```bash
mkdir coder & cd coder

npm init -y

npm pkg set dependencies.code-server="*"

npm pkg set overrides.electron="0.0.0"
npm pkg set overrides.playwright="0.0.0"
npm pkg set overrides.playwright-core="0.0.0"
npm pkg set overrides.@playwright/test="0.0.0"
npm pkg set overrides.@vscode/vsce-sign="0.0.0"

NODE_GYP_FORCE_PYTHON=/usr/bin/python3.12 npm install
```

## Launching Coder

```bash
./node_modules/.bin/code-server
```

Should launch by default in TCP port 8080, password should be available at `/root/.config/code-server/config.yaml`

## SystemD Service

A nice systemd service can be set up like this:

```ini
[Unit]
Description=VSCode Yaron
After=network.target nss-user-lookup.target auditd.service

[Service]
ExecStart=/opt/coder/node_modules/.bin/code-server --bind-addr 0.0.0.0:20080 --disable-telemetry
WorkingDir=/root
Type=simple
Restart=on-failure

[Install]
WantedBy=multi-user.target
```