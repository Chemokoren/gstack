#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# gstack Client Install — Install from your self-hosted server or fork
# ─────────────────────────────────────────────────────────────────────
# Run this on each local PC to install gstack.
#
# Usage (from your self-hosted server):
#   ./client-install.sh git@YOUR_SERVER_IP:/srv/git/gstack.git
#
# Usage (from your GitHub fork):
#   ./client-install.sh git@github.com:Chemokoren/gstack.git
#
# Usage (auto-detect — uses GitHub fork by default):
#   ./client-install.sh
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────
DEFAULT_REPO="git@github.com:Chemokoren/gstack.git"
INSTALL_DIR="$HOME/.claude/skills/gstack"
REPO="${1:-$DEFAULT_REPO}"

echo "=========================================="
echo "  gstack Client Installer"
echo "=========================================="
echo ""
echo "  Source: $REPO"
echo "  Target: $INSTALL_DIR"
echo ""

# ─── Step 1: Check prerequisites ─────────────────────────────────────
echo "==> Step 1: Checking prerequisites..."

missing=()

if ! command -v git &>/dev/null; then
    missing+=("git")
fi

if ! command -v bun &>/dev/null; then
    missing+=("bun")
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    echo "ERROR: Missing required tools: ${missing[*]}"
    echo ""
    if [[ " ${missing[*]} " =~ " git " ]]; then
        echo "  Install git:"
        echo "    sudo apt-get install -y git"
        echo ""
    fi
    if [[ " ${missing[*]} " =~ " bun " ]]; then
        echo "  Install bun:"
        echo "    curl -fsSL https://bun.sh/install | bash"
        echo ""
    fi
    exit 1
fi

echo "    ✓ git $(git --version | awk '{print $3}')"
echo "    ✓ bun $(bun --version)"

# ─── Step 2: Clone or update ─────────────────────────────────────────
echo ""
echo "==> Step 2: Cloning gstack..."

if [ -d "$INSTALL_DIR/.git" ]; then
    echo "    gstack already installed at $INSTALL_DIR"
    echo "    Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull --ff-only
else
    # Remove stale directory if it exists but isn't a git repo
    if [ -d "$INSTALL_DIR" ]; then
        echo "    Removing stale install at $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi

    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --single-branch --depth 1 "$REPO" "$INSTALL_DIR"
    echo "    Cloned to $INSTALL_DIR"
fi

# ─── Step 3: Configure remotes ───────────────────────────────────────
echo ""
echo "==> Step 3: Configuring remotes..."
cd "$INSTALL_DIR"

# Ensure upstream (garrytan/gstack) is available for pulling latest changes
UPSTREAM_URL="https://github.com/garrytan/gstack.git"
if ! git remote get-url upstream &>/dev/null; then
    git remote add upstream "$UPSTREAM_URL"
    echo "    Added upstream: $UPSTREAM_URL"
else
    echo "    Upstream already configured"
fi

echo "    Remotes:"
git remote -v | sed 's/^/      /'

# ─── Step 4: Run setup ───────────────────────────────────────────────
echo ""
echo "==> Step 4: Running gstack setup..."
cd "$INSTALL_DIR"
./setup

# ─── Step 5: Create update helper ────────────────────────────────────
echo ""
echo "==> Step 5: Creating update command..."

UPDATE_SCRIPT="$HOME/.local/bin/gstack-update"
mkdir -p "$(dirname "$UPDATE_SCRIPT")"

cat > "$UPDATE_SCRIPT" <<'UPDATE'
#!/usr/bin/env bash
# Update gstack from origin + sync upstream changes
set -euo pipefail

GSTACK_DIR="$HOME/.claude/skills/gstack"

if [ ! -d "$GSTACK_DIR/.git" ]; then
    echo "ERROR: gstack not installed at $GSTACK_DIR"
    exit 1
fi

cd "$GSTACK_DIR"

echo "==> Fetching upstream (garrytan/gstack)..."
git fetch upstream main 2>/dev/null || echo "    (upstream not available, skipping)"

echo "==> Pulling from origin..."
git pull --ff-only origin main

echo "==> Rebuilding..."
./setup -q

echo ""
echo "✅ gstack updated to $(cat VERSION 2>/dev/null || echo 'latest')"
UPDATE

chmod +x "$UPDATE_SCRIPT"
echo "    Created: $UPDATE_SCRIPT"

# ─── Done ────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "  ✅ gstack installed successfully!"
echo "=========================================="
echo ""
echo "  Location:  $INSTALL_DIR"
echo "  Version:   $(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo 'unknown')"
echo ""
echo "  To update later:  gstack-update"
echo "  Or manually:      cd $INSTALL_DIR && git pull && ./setup"
echo ""
echo "  Get started:"
echo "    1. Open Claude Code in any project"
echo "    2. Type /office-hours to begin"
echo ""
echo "=========================================="
