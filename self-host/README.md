# gstack Self-Hosting Guide

Host gstack from your own infrastructure and install it on all your PCs.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              Ubuntu 24.04 Server                     │
│                                                      │
│   /srv/git/gstack.git  (bare repo)                  │
│         ↑                                            │
│   cron: every 6h sync from garrytan/gstack           │
│         ↑                                            │
│   SSH access via 'git' user                          │
└──────────────┬──────────────────────────────────────┘
               │ SSH (git clone / git pull)
        ┌──────┴──────┐
        │             │
   ┌────▼────┐   ┌────▼────┐
   │  PC #1  │   │  PC #2  │   ... more PCs
   │         │   │         │
   │ ~/.claude/skills/gstack
   └─────────┘   └─────────┘
```

## Option A: Self-Hosted Git Server (fully independent)

### Server Setup

1. Copy `server-setup.sh` to your Ubuntu 24.04 server
2. Run it:

```bash
chmod +x server-setup.sh
sudo ./server-setup.sh
```

This creates:
- A `git` user with SSH-only access (no shell login)
- A bare repo at `/srv/git/gstack.git`
- A cron job that syncs upstream every 6 hours
- SSH configured for client access

3. Add your SSH public keys:

```bash
# From each client PC:
ssh-copy-id -i ~/.ssh/id_ed25519.pub git@YOUR_SERVER_IP

# Or manually on the server:
sudo nano /home/git/.ssh/authorized_keys
# Paste your public key (one per line)
```

### Client Install (from your server)

```bash
./client-install.sh git@YOUR_SERVER_IP:/srv/git/gstack.git
```

---

## Option B: GitHub Fork (simpler, no server needed)

If you don't want to run your own Git server, just install from your fork:

### Client Install (from GitHub)

```bash
./client-install.sh git@github.com:Chemokoren/gstack.git
```

Or with no arguments (defaults to your fork):

```bash
./client-install.sh
```

---

## Keeping Up to Date

### Automatic (server-side)
The server syncs from `garrytan/gstack` every 6 hours via cron. Your PCs
pull from your server, so updates flow automatically:

```
garrytan/gstack → your server → your PCs
```

### Manual (per PC)
```bash
gstack-update
```

This command is created by `client-install.sh` at `~/.local/bin/gstack-update`.

### Manual (GitHub fork)
Use `update.sh` in the repo root to sync your fork with upstream:

```bash
cd /path/to/gstack && ./update.sh
```

---

## Prerequisites

### Server
- Ubuntu 24.04 (tested; other Debian-based distros should work)
- Root access
- Internet access (for initial clone and upstream sync)

### Client PCs
- **Git** — `sudo apt-get install -y git`
- **Bun** v1.0+ — `curl -fsSL https://bun.sh/install | bash`
- **Claude Code** — [docs.anthropic.com](https://docs.anthropic.com/en/docs/claude-code)
- SSH key pair (for server auth)

---

## Security Notes

- The `git` user uses `git-shell` — no interactive login possible
- SSH key auth only — no password auth
- The bare repo is read-write for the `git` user only
- Cron sync uses HTTPS (read-only) to fetch from upstream
- Consider firewall rules to restrict SSH access to known IPs:
  ```bash
  sudo ufw allow from 192.168.1.0/24 to any port 22
  ```

---

## Troubleshooting

**Can't connect from client?**
```bash
# Test SSH connection
ssh -vT git@YOUR_SERVER_IP

# Check server SSH is running
sudo systemctl status ssh

# Check authorized_keys permissions
ls -la /home/git/.ssh/
```

**Sync not working?**
```bash
# Run sync manually
sudo /usr/local/bin/gstack-sync-upstream

# Check logs
cat /var/log/gstack-sync.log

# Verify cron
crontab -l | grep gstack
```

**Setup fails on client?**
```bash
# Verify bun is installed
bun --version

# Reinstall from scratch
rm -rf ~/.claude/skills/gstack
./client-install.sh git@YOUR_SERVER_IP:/srv/git/gstack.git
```
