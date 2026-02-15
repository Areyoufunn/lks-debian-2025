#!/bin/bash
#
# Quick Deploy Script
# Deploy to GitHub and setup on server
#

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 LKS 2025 - Quick Deploy to GitHub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "[1/3] Initializing Git repository..."
    git init
    git branch -M main
else
    echo "[1/3] Git already initialized"
fi

# Add all files
echo "[2/3] Adding files..."
git add .

# Commit
echo "[3/3] Committing..."
read -p "Commit message: " commit_msg
if [ -z "$commit_msg" ]; then
    commit_msg="Update: $(date '+%Y-%m-%d %H:%M')"
fi
git commit -m "$commit_msg"

# Check if remote exists
if ! git remote | grep -q origin; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔗 Setup GitHub Remote"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Create repository di GitHub: https://github.com/new"
    echo "2. Copy repository URL"
    echo ""
    read -p "GitHub repository URL: " repo_url
    git remote add origin "$repo_url"
fi

# Push
echo ""
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Pushed to GitHub!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next: Setup on server (int-srv)"
echo ""
echo "ssh root@int-srv"
echo "git clone $repo_url"
echo "cd lks-debian-2025"
echo "./setup-control-node.sh"
echo ""
