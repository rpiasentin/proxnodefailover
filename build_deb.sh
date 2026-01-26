#!/bin/bash
set -e

PKG_NAME="proxnodefailover"
VERSION="1.0.0"
ARCH="all"
DEB_NAME="${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo "Building $DEB_NAME..."

# Ensure ownership (root mostly) - utilizing fakeroot or simple dpkg-deb behavior
# Since running on Mac/User, ownership inside DEB will be user's if not careful.
# Ideally use 'fakeroot dpkg-deb --build packaging .'
# But we might not have fakeroot or dpkg-deb on Mac.
# Assuming user will run this on Linux or Mac with tools.

if ! command -v dpkg-deb &> /dev/null; then
    echo "Error: dpkg-deb not found. Please install dpkg (brew install dpkg on Mac)."
    exit 1
fi

dpkg-deb --build packaging "$DEB_NAME"

echo "Package built: $DEB_NAME"
