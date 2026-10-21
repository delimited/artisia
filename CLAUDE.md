# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Ansible playbook plus Debian installer preseeds that rebuild one specific machine, a ThinkPad P16 Gen 2 (Intel + NVIDIA hybrid) named `artisia`, on Debian 13 "trixie". It runs locally against itself (`inventory.ini`: `ansible_connection=local`). The repo is public, so it must stay **free of secrets**. Everything must be idempotent: rerunning the playbook is how changes get applied.

## Commands

```bash
ansible-galaxy collection install -r requirements.yml   # community.general (flatpak, ini_file)
ansible-playbook site.yml -K                             # full run (sudo password prompt)
ansible-playbook site.yml -K --tags java                 # one role; tags match role names
ansible-playbook site.yml -K --check --diff              # dry run
ansible-playbook site.yml --syntax-check
ansible-lint                                             # config in .ansible-lint
./bootstrap.sh [extra ansible-playbook args]             # installs Ansible + collections, then runs the playbook
```

`site.yml` asserts the host is Debian trixie, so a real run only works on the target machine. There are no tests; `--syntax-check`, `ansible-lint` and `--check --diff` are the verification tools.

## Architecture

- **`group_vars/all.yml` is the main edit point**: package lists for each role, Flatpaks, `gnome_settings` (dconf keys in GVariant syntax, so strings need inner quotes, e.g. `"'prefer-dark'"`), and `default_apps`. `desktop_user` comes from `$USER` of whoever runs the playbook.
- **Role order in `site.yml` matters**: `base` rewrites the apt sources (deb822, with contrib/non-free/non-free-firmware) and flushes handlers before anything else installs. `nvidia` depends on non-free being present.
- **Third-party apt repos go through the `extrepo` role**, never hand-written `.sources` files or downloaded keys. A role adds repos with `import_role: name: extrepo` and `vars: extrepo_repos: [...]` (see `roles/docker`, `roles/devtools`, `roles/desktop`). The role also pins `.sources` files to `Architectures: amd64` to work around extrepo 0.14 in trixie. The licence policies it enables come from `extrepo_policies`.
- **GNOME defaults are system-wide** (`/etc/dconf/db/local.d/00-artisia` from `roles/desktop/templates/gnome-defaults.j2`, plus `/etc/xdg/mimeapps.list`), so per-user settings in `/home` still win.
- **Per-user installs** (JetBrains Toolbox) use `become_user: "{{ desktop_user }}"` inside a block. Everything else runs as root.
- **Things that can't be automated** (MOK enrolment for Secure Boot, reboots, fingerprint enrolment) are surfaced as `debug` messages or handlers, not done by the playbook. Also keep the "Manual steps" section in README.md in sync.
- **`preseed/`**: `install.cfg` (wipes the disk: LUKS + LVM with separate root/swap/home LVs) and `reinstall.cfg` (manual partitioning that keeps the `home` LV, and a `late_command` that writes crypttab) both include `common.cfg` (minimal `gnome-core` package selection, etc.). `/home` survives reinstalls, so roles sometimes clean up stale per-user state left there (e.g. removing a native-installer Claude Code from `~/.local/bin`).

## Conventions

- Fully qualified module names (`ansible.builtin.*`, `community.general.*`). Registered variables are prefixed with the role name (`nvidia_sb_state`, `devtools_toolbox_dir`) to satisfy ansible-lint.
- `command` tasks set `creates:` or `changed_when:` so reruns stay idempotent. Add `ignore_errors: "{{ ansible_check_mode }}"` where a file only exists after a real run.
- Comments explain *why* (Debian/vendor quirks), not what the task does. Keep that style.
- README.md is the user-facing doc. Update its tables ("What's where") when you add a role, repo or package source.
- The GitHub user is `delimited` (in `bootstrap.sh` and the README's URLs); keep them in sync if it changes.
