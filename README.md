# OxiScripts

A collection of bash scripts for system backup and maintenance, primarily targeting Debian-based systems (including Raspberry Pi). Still in active use after 13+ years.

All of this is done with bash. Yes, today it would simply be ansible-based ... but today is not the day I rewrite this code. 😊

## What it does

- **Backup**: incremental backups via `rdiff-backup`, tar archives, and rsync to a central backup server
- **System maintenance**: APT cache cleanup, update notifications
- **Self-updating**: installs and updates itself from a configured mirror URL

Backups are written to `/mnt/backup` (configurable) and then rsynced to a central server via `jobs/backup-rsync.sh`.

## Ansible

The preferred way to deploy oxiscripts is via the **[oxivanisher.linux_base.oxiscripts](https://github.com/oxivanisher/role-oxiscripts)** Ansible role, which is part of the [oxivanisher.linux_base](https://galaxy.ansible.com/ui/repo/published/oxivanisher/linux_base/) collection. The role handles installation, configuration, and setting up all backup jobs.

```yaml
- role: oxivanisher.linux_base.oxiscripts
  vars:
    oxiscripts_email: admin@example.com
    oxiscripts_rsync_server: nas.example.com
    oxiscripts_rsync_user: backup
    oxiscripts_rsync_password: secret
    oxiscripts_rsync_path: rsync-backup
```

## Manual Installation

```bash
# As root:
bash install.sh
```

The installer places files in `/etc/oxiscripts/`, hooks into `/etc/cron.*` for scheduled jobs, and adds a loader to all users' `.bashrc` files.

## Configuration

All runtime configuration lives in `/etc/oxiscripts/setup.sh` (generated from `setup_pure.sh` during install). Key variables:

| Variable | Description |
|---|---|
| `ADMINMAIL` | Email address for backup notifications |
| `BACKUPDIR` | Backup mount point (default: `/mnt/backup`) |
| `DEBUG` | Send notification emails after each backup run (0/1) |
| `OXIMIRROR` | URL to your hosted `install.sh` for self-updates |
| `OXICOLOR` | Colored terminal output (0/1) |

The `mountbackup` and `umountbackup` functions in `setup.sh` are intentionally left empty — fill them in if your backup volume needs mounting (NFS, USB drive, etc.).

## Shell functions

Sourcing `/etc/oxiscripts/init.sh` (done automatically via `.bashrc`) provides `ox-*` functions in your shell. Run `ox-help` to list them.

Notable functions:
- `ox-base-update` — pull and install the latest release from `OXIMIRROR`
- `ox-base-set debug|color|mirror|mail` — toggle settings without editing files
- `ox-base-show` — print current configuration

## Backup jobs

Job scripts live in `jobs/` and are symlinked into `/etc/cron.*` by the installer. Configure them for your system before relying on them — they contain placeholder values.

| Job | Schedule | Description |
|---|---|---|
| `backup-system.sh` | daily | dpkg selections, `/etc`, `/boot` |
| `backup-scripts.sh` | daily | `~/scripts` and `~/bin` for all users |
| `backup-cleanup.sh` | daily | remove duplicate and old backup files |
| `backup-rsync.sh` | — | rsync `/mnt/backup` to a remote server |
| `backup-mysql.sh` | — | `mysqldump` of all databases |
| `backup-ejabberd.sh` | — | ejabberd database export |
| `backup-pfsense.sh` | — | pfSense config download via HTTP |
| `backup-documents.sh` | — | rdiff-backup for document directories |
| `backup-info.sh` | monthly | email summary of backup sizes |

Jobs without a schedule are not activated by the installer — symlink them manually into the appropriate `cron.*` directory.

## Releasing / self-update mechanism

The `install.sh` in this repo is a self-contained installer: it has the payload (all scripts) uuencoded and appended to the shell script itself.

To build a new release:

```bash
# Requires: apt-get install sharutils
bash make_release.sh
```

This stamps the current Unix timestamp into `install.sh` as `INSTALLOXIRELEASE`. When `ox-base-update` runs on an installed system, it compares that value against the installed `OXIRELEASE` and only reinstalls if the mirror is newer.

To host your own mirror, upload `install.sh` and `install.sh.md5` to a web server and set `OXIMIRROR` accordingly.

## Things to know

- Edit `install_pure.sh` (not `install.sh`) when changing the installer — `install.sh` is generated
- Dash is **not** supported; these scripts require bash
- `/etc/oxiscripts/jobs/*.sh` — if a job file was locally modified, the installer saves the new version as `*.sh.new` instead of overwriting
