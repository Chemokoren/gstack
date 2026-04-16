#!/usr/bin/env bash
set -euo pipefail

# Sync local main with the original repo (garrytan/gstack)
# and push to your fork (Chemokoren/gstack)

UPSTREAM_REMOTE="origin"
UPSTREAM_URL="git@github.com:garrytan/gstack.git"
FORK_REMOTE="fork"
FORK_URL="git@github.com:Chemokoren/gstack.git"
BRANCH="main"

echo "==> Ensuring remotes are configured..."

# origin should point to garrytan/gstack (the upstream source)
current_origin=$(git remote get-url "$UPSTREAM_REMOTE" 2>/dev/null || true)
if [ -z "$current_origin" ]; then
    git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
    echo "    Added remote '$UPSTREAM_REMOTE' -> $UPSTREAM_URL"
elif [ "$current_origin" != "$UPSTREAM_URL" ]; then
    echo "    WARNING: '$UPSTREAM_REMOTE' points to $current_origin (expected $UPSTREAM_URL)"
fi

# fork remote should point to Chemokoren/gstack
current_fork=$(git remote get-url "$FORK_REMOTE" 2>/dev/null || true)
if [ -z "$current_fork" ]; then
    git remote add "$FORK_REMOTE" "$FORK_URL"
    echo "    Added remote '$FORK_REMOTE' -> $FORK_URL"
elif [ "$current_fork" != "$FORK_URL" ]; then
    git remote set-url "$FORK_REMOTE" "$FORK_URL"
    echo "    Updated remote '$FORK_REMOTE' -> $FORK_URL"
fi

echo "==> Fetching latest from $UPSTREAM_REMOTE/$BRANCH..."
git fetch "$UPSTREAM_REMOTE" "$BRANCH"

echo "==> Checking out $BRANCH..."
git checkout "$BRANCH"

echo "==> Merging $UPSTREAM_REMOTE/$BRANCH into local $BRANCH..."
git merge "$UPSTREAM_REMOTE/$BRANCH" --ff-only

echo "==> Pushing to $FORK_REMOTE/$BRANCH..."
git push "$FORK_REMOTE" "$BRANCH"

echo ""
echo "✅ Done! Your fork is now up to date with $UPSTREAM_REMOTE/$BRANCH."
