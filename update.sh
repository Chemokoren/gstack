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

echo "==> Integrating $UPSTREAM_REMOTE/$BRANCH into local $BRANCH..."
local_commit=$(git rev-parse "$BRANCH")
upstream_commit=$(git rev-parse "$UPSTREAM_REMOTE/$BRANCH")
merge_base=$(git merge-base "$BRANCH" "$UPSTREAM_REMOTE/$BRANCH")

if [ "$local_commit" = "$upstream_commit" ]; then
    echo "    Local $BRANCH is already up to date."
elif [ "$local_commit" = "$merge_base" ]; then
    echo "    Fast-forwarding local $BRANCH..."
    git merge "$UPSTREAM_REMOTE/$BRANCH" --ff-only
elif [ "$upstream_commit" = "$merge_base" ]; then
    echo "    Local $BRANCH is ahead of $UPSTREAM_REMOTE/$BRANCH; keeping local commits."
else
    echo "    Local and upstream have diverged; creating an automatic merge commit."
    git merge "$UPSTREAM_REMOTE/$BRANCH" --no-edit
fi

echo "==> Pushing to $FORK_REMOTE/$BRANCH..."
git push "$FORK_REMOTE" "$BRANCH"

echo ""
echo "✅ Done! Your fork is now up to date with $UPSTREAM_REMOTE/$BRANCH."
