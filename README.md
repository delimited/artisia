# artisia

Rebuild my ThinkPad P16 Gen 2 (Intel + NVIDIA hybrid) on Debian 13 "trixie" from scratch.
Idempotent: safe to rerun any time, and rerunning is how changes get applied.

## 1. Install Debian

1. Download the **amd64 netinst** ISO from debian.org and check it against `SHA512SUMS` + `SHA512SUMS.sign`.
2. Write it to USB (`dd` or GNOME Disks). Leave Secure Boot on.
3. In the installer:
   - *Guided – use entire disk with encrypted LVM*
   - **Leave the root password blank** so your user gets sudo
   - tasksel: **GNOME** + **standard system utilities** only

## 2. Bootstrap

```bash
sudo apt install -y curl
curl -fsSL https://raw.githubusercontent.com/CHANGEME/artisia/main/bootstrap.sh | bash
```

This installs Ansible, clones the repo to `~/src/artisia`, and runs the playbook.
The clone uses HTTPS, because your SSH keys aren't available yet (they're in KeePassXC).
Keep this repo **free of secrets** so it can stay public.

## 3. Manual steps (once)

- **Secure Boot + NVIDIA**: if the playbook says so, run `sudo mokutil --import /var/lib/dkms/mok.pub`,
  set a one-time password, reboot, choose *Enroll MOK*.
- **Reboot**, then log out/in for the `docker` group to apply.
- Enrol a fingerprint: *Settings → Users → Fingerprint Login*.
- Run JetBrains Toolbox once from `~/.local/opt/jetbrains-toolbox`, then install IntelliJ.
- Restore the KeePassXC database, then switch the remote to SSH:
  `git -C ~/src/artisia remote set-url origin git@github.com:CHANGEME/artisia.git`
- Sign in to Claude Desktop, Firefox Sync, Thunderbird, Spotify.
- Add the Brother DCP-L2627DW in *Settings → Printers* (driverless; scanning works in Document Scanner).
- PIA VPN (optional): Linux installer from privateinternetaccess.com.

## Day-to-day

```bash
cd ~/src/artisia
ansible-playbook site.yml -K                 # everything
ansible-playbook site.yml -K --tags java     # one role
ansible-playbook site.yml -K --check --diff  # dry run
```

Roles: `base`, `nvidia`, `java`, `docker`, `devtools`, `desktop`.
Package lists live in `group_vars/all.yml`. That's usually the only file to edit.

## What's where

| Thing | Source |
|---|---|
| OpenJDK 25, Maven | Debian main |
| NVIDIA driver | Debian non-free |
| Docker CE | download.docker.com |
| VS Code | packages.microsoft.com |
| Claude Desktop | downloads.claude.ai |
| Claude Code CLI | native installer (self-updating) |
| Firefox | packages.mozilla.org (pinned over ESR) |
| Spotify, Foliate, Papers | Flathub |
| IntelliJ | JetBrains Toolbox |
