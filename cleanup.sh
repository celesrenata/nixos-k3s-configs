#!/usr/bin/env bash

set -e

echo "🧹 Cleaning up Kubernetes project directory..."
echo "This will remove temporary files, backups, and large binaries"
echo ""

# Count files before cleanup
BEFORE=$(du -sh . | cut -f1)
echo "Current size: $BEFORE"
echo ""

# Remove vim swap files
echo "Removing vim swap files..."
find . -name "*.swp" -o -name "*.swo" -o -name "*.swn" | xargs -r rm -v

# Remove Python virtual environments
echo "Removing Python virtual environments..."
find . -type d -name "venv" -o -name ".venv" -o -name "__pycache__" | xargs -r rm -rfv

# Remove backup directories
echo "Removing backup directories..."
find . -maxdepth 1 -type d \( \
    -name "*.bak" -o \
    -name "*.old" -o \
    -name "*.backup" -o \
    -name "*.fucked*" -o \
    -name "*.dead*" -o \
    -name "*.works" -o \
    -name "*.dupe" \
\) -exec rm -rfv {} +

# Remove large tar files
echo "Removing tar archives..."
find . -maxdepth 1 \( -name "*.tar" -o -name "*.tar.gz" \) -exec rm -v {} +

# Remove ISO files (keep them in a separate location if needed)
echo "Removing ISO files from kubevirt..."
find ./kubevirt -name "*.iso" -exec rm -v {} \;

# Remove AI model files from kubevirt
echo "Removing AI model files from kubevirt..."
find ./kubevirt -name "*.pth" -exec rm -v {} \;

# Remove stable-diffusion.bak with large models
echo "Removing stable-diffusion.bak directory..."
rm -rfv stable-diffusion.bak

# Remove deepweb-proxy backups
echo "Removing deepweb-proxy backups..."
rm -rfv deepweb-proxy.bak deepweb-proxy.bak2

# Remove mariadb/result (nix build artifact)
echo "Removing nix build artifacts..."
find . -type l -name "result" | xargs -r rm -v

# Remove empty directories
echo "Removing empty directories..."
find . -type d -empty -delete 2>/dev/null || true

# Count files after cleanup
AFTER=$(du -sh . | cut -f1)
echo ""
echo "✅ Cleanup complete!"
echo "Before: $BEFORE"
echo "After:  $AFTER"
echo ""
echo "Next steps:"
echo "1. Review the changes"
echo "2. Run: git init"
echo "3. Run: git add ."
echo "4. Run: git commit -m 'Initial commit of kubernetes projects'"
