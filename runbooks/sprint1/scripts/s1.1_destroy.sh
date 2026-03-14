#!/bin/bash
# S1.1 - Destroy 3 Production Repos (Local only)
# Usage: ./destroy.sh

set -e

BASE_DIR="${1:-$HOME/techitfactory}"

echo "=== Destroying repos in: $BASE_DIR ==="
echo ""

if [ ! -d "$BASE_DIR" ]; then
    echo "Directory $BASE_DIR does not exist. Nothing to destroy."
    exit 0
fi

echo "This will DELETE the following directories:"
echo "  - $BASE_DIR/techitfactory-infra"
echo "  - $BASE_DIR/techitfactory-app"
echo "  - $BASE_DIR/techitfactory-gitops"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

cd "$BASE_DIR"

# Remove repos
if [ -d "techitfactory-infra" ]; then
    rm -rf techitfactory-infra
    echo "✅ Removed techitfactory-infra"
fi

if [ -d "techitfactory-app" ]; then
    rm -rf techitfactory-app
    echo "✅ Removed techitfactory-app"
fi

if [ -d "techitfactory-gitops" ]; then
    rm -rf techitfactory-gitops
    echo "✅ Removed techitfactory-gitops"
fi

echo ""
echo "=== DONE ==="
echo ""
echo "Note: This only removes LOCAL directories."
echo "To delete GitHub repos, go to each repo Settings → Delete repository"
