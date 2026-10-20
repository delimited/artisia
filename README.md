# artisia

Rebuild my ThinkPad P16 Gen 2 (Intel + NVIDIA hybrid) on Debian 13 "trixie" from scratch.
Idempotent: safe to rerun any time, and rerunning is how changes get applied.

## 1. Install Debian

1. Download the **amd64 netinst** ISO from debian.org and check it against `SHA512SUMS` + `SHA512SUMS.sign`.
2. Write it to USB (`dd` or GNOME Disks). Leave Secure Boot on.
3. Boot it, highlight *Graphical install*, press `e`, and add this to the end of the `linux` line
   (before the ` ---`), then press Ctrl+X:

   ```
   url=https://raw.githubusercontent.com/CHANGEME/artisia/main/preseed/install.cfg
   ```

4. Answer the remaining questions. [`preseed/install.cfg`](preseed/install.cfg) handles two things:
   - **Minimal GNOME**: `gnome-core` rather than tasksel's GNOME task, which brings LibreOffice,
     Evolution, Shotwell and more. There's no software-selection screen.
   - **Separate `/home`**: encrypted LVM with `root` (100 GB), `swap` (8 GB) and `home` (the rest)
     as separate logical volumes. Edit the sizes in the preseed before installing if you want.
     Docker and Flatpaks live on root.

   It still asks you to pick the disk, set the encryption passphrase and confirm the writes.
   **Leave the root password blank** so your user gets sudo. Use hostname `artisia`.

### Reinstalling without losing `/home`

The installer can't reuse an existing encrypted volume by itself, so a reinstall means unlocking
it by hand and partitioning manually. **Back up `/home` first anyway.**

1. Boot as above, but with `url=…/preseed/reinstall.cfg`.
2. When *Partition disks* appears, press Ctrl+Alt+F2, press Enter, and unlock the volume:

   ```
   blkid | grep crypto_LUKS          # normally /dev/nvme0n1p3
   cryptsetup luksOpen /dev/nvme0n1p3 nvme0n1p3_crypt
   vgchange -ay
   rm -f /var/lib/partman/filesystems_detected
   ```

3. Return to the installer with Ctrl+Alt+F5 (graphical) or Ctrl+Alt+F1 (text). Choose
   *Go Back*, then *Partition disks* again, then *Manual*:

   | Volume | Use as | Format? | Mount |
   |---|---|---|---|
   | EFI partition | EFI System Partition | yes | |
   | 1 GB partition | ext4 | yes | `/boot` |
   | `…-vg/root` | ext4 | **yes** | `/` |
   | `…-vg/home` | ext4 | **no, keep existing data** | `/home` |
   | `…-vg/swap` | swap area | | |

   Check the summary before writing: `home` should show `K` (keep), not `F` (format).
4. Create the **same username**. It gets uid 1000 again, so your files keep their owner.
   The preseed writes `/etc/crypttab` and rebuilds the initramfs at the end, because the
   installer doesn't do that for a volume it didn't create.
5. Run the bootstrap again. It finds the existing clone in `~/src/artisia` and pulls it.

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
  `echo $XDG_SESSION_TYPE` should print `wayland`. If it says `x11`, check that
  `/proc/driver/nvidia/params` shows `PreserveVideoMemoryAllocations: 1`.
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

Roles: `base`, `nvidia`, `java`, `docker`, `devtools`, `desktop`
(plus `extrepo`, which the others import to add their apt repos).
Package lists live in `group_vars/all.yml`. That's usually the only file to edit.
GNOME defaults (dark style, window buttons, enabled extensions) are in `gnome_settings` there.
They're system-wide defaults, so anything you change in Settings wins.
To find a setting's name, change it in Settings while running `dconf watch /`.

## What's where

Third-party apt repos come from Debian's [extrepo](https://salsa.debian.org/extrepo-team/extrepo-data)
list (extrepo name in brackets). If a vendor rotates its key, run `sudo extrepo update <name>`.

| Thing | Source |
|---|---|
| OpenJDK 25, Maven | Debian main |
| NVIDIA driver | Debian non-free |
| Docker CE | download.docker.com (`docker-ce`) |
| VS Code | packages.microsoft.com (`vscode`) |
| Claude Desktop | downloads.claude.ai (`anthropic-claude-desktop`) |
| Claude Code CLI | downloads.claude.ai, stable channel (`anthropic-claude-code`) |
| Firefox | packages.mozilla.org, pinned over ESR (`mozilla`) |
| Spotify, Foliate, Papers | Flathub |
| IntelliJ | JetBrains Toolbox |
