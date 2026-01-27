#!/bin/bash
set -e

PKG_NAME="proxnodefailover"
VERSION="1.0.0"
ARCH="all"
DEB_NAME="${PKG_NAME}_${VERSION}_${ARCH}.deb"
PKG_DIR="packaging"

echo "Building $DEB_NAME..."

# 1. Environment Check
if ! command -v dpkg-deb &> /dev/null; then
    echo "Error: dpkg-deb not found. Please install dpkg (brew install dpkg on Mac)."
    exit 1
fi

# 2. Prepare Packaging Directory
echo "Syncing latest scripts to packaging directory..."

# Ensure directories exist
mkdir -p "${PKG_DIR}/usr/local/sbin"
mkdir -p "${PKG_DIR}/usr/local/bin"
mkdir -p "${PKG_DIR}/etc/systemd/system"

# Copy Runtime Script
cp net-failover.sh "${PKG_DIR}/usr/local/sbin/"
chmod 755 "${PKG_DIR}/usr/local/sbin/net-failover.sh"

# Copy Setup Utility
cp prox-setup "${PKG_DIR}/usr/local/bin/"
chmod 755 "${PKG_DIR}/usr/local/bin/prox-setup"

# Note: net-failover.service is likely just a template or installed via postinst? 
# Wait, usually the service file should be in the package.
# Let's check if it exists in source or if we need to create it.
# The previous `net-failover-setup` wrote it dynamically.
# I should probably have a static service file to copy in, or rely on postinst to create it (bad practice).
# BEST PRACTICE: Have the service file in the package. 
# I will check if I have a static service file in the repo. If not, I'll create one.

# 3. Build Package
dpkg-deb --build "${PKG_DIR}" "$DEB_NAME"

echo "Package built successfully: $DEB_NAME"
echo "Contents:"
dpkg-deb -c "$DEB_NAME"
