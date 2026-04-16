#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# gstack Self-Hosted Server Setup — Ubuntu 24.04
# ─────────────────────────────────────────────────────────────────────
# Run this on your Ubuntu 24.04 server to set up a private Git server
# hosting your gstack fork. After running this, any PC on your network
# (or over the internet via SSH) can install gstack from your server.
#
# Usage:
#   chmod +x server-setup.sh
#   sudo ./server-setup.sh
#
# What this does:
#   1. Creates a 'git' system user for hosting repos
#   2. Initializes a bare Git repo at /srv/git/gstack.git
#   3. Pushes your fork into it (from GitHub)
#   4. Sets up a sync cron job to pull updates from upstream (garrytan/gstack)
#   5. Configures SSH access for your client PCs
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────
UPSTREAM_REPO="https://github.com/garrytan/gstack.git"
FORK_REPO="https://github.com/Chemokoren/gstack.git"
GIT_USER="git"
REPO_DIR="/srv/git/gstack.git"
SYNC_SCRIPT="/usr/local/bin/gstack-sync-upstream"
SYNC_INTERVAL="0 */6 * * *"  # Every 6 hours

echo "=========================================="
echo "  gstack Self-Hosted Server Setup"
echo "  Ubuntu 24.04"
echo "=========================================="
echo ""

# ─── Must run as root ─────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (sudo)."
    exit 1
fi

# ─── Step 1: Install dependencies ─────────────────────────────────────
echo "==> Step 1: Installing dependencies..."
apt-get update -qq
apt-get install -y -qq git openssh-server cron

# ─── Step 2: Create git user ──────────────────────────────────────────
echo "==> Step 2: Setting up 'git' user..."
if ! id "$GIT_USER" &>/dev/null; then
    adduser --system --shell /usr/bin/git-shell --group \
            --home /home/$GIT_USER --disabled-password "$GIT_USER"
    echo "    Created user: $GIT_USER"
else
    echo "    User '$GIT_USER' already exists, skipping."
fi

# Ensure .ssh directory exists for the git user
mkdir -p /home/$GIT_USER/.ssh
chmod 700 /home/$GIT_USER/.ssh
touch /home/$GIT_USER/.ssh/authorized_keys
chmod 600 /home/$GIT_USER/.ssh/authorized_keys
chown -R $GIT_USER:$GIT_USER /home/$GIT_USER/.ssh

# Allow git-shell interactive commands (optional)
mkdir -p /home/$GIT_USER/git-shell-commands
cat > /home/$GIT_USER/git-shell-commands/no-interactive-login <<'NOLOGIN'
#!/bin/sh
echo "This account is for git access only. No interactive login."
exit 128
NOLOGIN
chmod +x /home/$GIT_USER/git-shell-commands/no-interactive-login
chown -R $GIT_USER:$GIT_USER /home/$GIT_USER/git-shell-commands

# ─── Step 3: Initialize bare Git repository ──────────────────────────
echo "==> Step 3: Initializing bare Git repository..."
mkdir -p "$(dirname "$REPO_DIR")"

if [ -d "$REPO_DIR" ]; then
    echo "    Repository already exists at $REPO_DIR, skipping init."
else
    git clone --bare "$FORK_REPO" "$REPO_DIR"
    echo "    Cloned from $FORK_REPO"
fi

chown -R $GIT_USER:$GIT_USER "$REPO_DIR"

# ─── Step 4: Create upstream sync script ────────────────────────────
echo "==> Step 4: Setting up upstream sync..."
cat > "$SYNC_SCRIPT" <<SYNC
#!/usr/bin/env bash
# Sync gstack from upstream (garrytan/gstack) into local bare repo
set -euo pipefail

REPO="$REPO_DIR"
UPSTREAM="$UPSTREAM_REPO"
FORK="$FORK_REPO"
LOGFILE="/var/log/gstack-sync.log"

log() { echo "\$(date '+%Y-%m-%d %H:%M:%S') \$*" >> "\$LOGFILE"; }

TMPDIR=\$(mktemp -d)
trap 'rm -rf "\$TMPDIR"' EXIT

git clone --quiet "\$REPO" "\$TMPDIR/work" 2>/dev/null
cd "\$TMPDIR/work"

# Add upstream if not present
git remote add upstream "\$UPSTREAM" 2>/dev/null || true
git fetch --quiet upstream main 2>/dev/null

# Fast-forward merge
if git merge --ff-only upstream/main 2>/dev/null; then
    git push origin main 2>/dev/null
    log "Synced upstream changes to local repo"
else
    log "No new upstream changes (or merge conflict — skipped)"
fi
SYNC

chmod +x "$SYNC_SCRIPT"
echo "    Sync script: $SYNC_SCRIPT"

# ─── Step 5: Add cron job ────────────────────────────────────────────
echo "==> Step 5: Setting up cron job for auto-sync..."
CRON_LINE="$SYNC_INTERVAL $SYNC_SCRIPT"
(crontab -l 2>/dev/null | grep -v "gstack-sync-upstream" || true; echo "$CRON_LINE") | crontab -
echo "    Cron: $SYNC_INTERVAL (every 6 hours)"

# ─── Step 6: Configure SSH ──────────────────────────────────────────
echo "==> Step 6: Ensuring SSH is configured..."
systemctl enable ssh
systemctl start ssh

# ─── Step 7: Get server IP ──────────────────────────────────────────
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo "  ✅ Server setup complete!"
echo "=========================================="
echo ""
echo "  Repository: $REPO_DIR"
echo "  Server IP:  $SERVER_IP"
echo ""
echo "  ── NEXT STEPS ──"
echo ""
echo "  1. Add your SSH public keys (from each client PC):"
echo ""
echo "     ssh-copy-id -i ~/.ssh/id_ed25519.pub $GIT_USER@$SERVER_IP"
echo ""
echo "     Or manually append to:"
echo "     /home/$GIT_USER/.ssh/authorized_keys"
echo ""
echo "  2. On each client PC, run the install script:"
echo ""
echo "     curl -fsSL http://$SERVER_IP/install-gstack.sh | bash"
echo ""
echo "     Or clone and install manually:"
echo ""
echo "     git clone $GIT_USER@$SERVER_IP:$REPO_DIR ~/.claude/skills/gstack"
echo "     cd ~/.claude/skills/gstack && ./setup"
echo ""
echo "  3. Test the connection from a client:"
echo ""
echo "     ssh $GIT_USER@$SERVER_IP"
echo ""
echo "=========================================="
