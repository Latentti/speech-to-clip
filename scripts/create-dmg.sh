#!/bin/bash

# Script: create-dmg.sh
# Purpose: Create a professional DMG for Speech to Clip distribution
# Usage: ./scripts/create-dmg.sh <version> [app-path]
#   version: Version number (e.g., "1.0")
#   app-path: Optional path to exported app (default: archives/Speech to Clip.app)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: $0 <version> [app-path]"
    echo "Example: $0 1.0"
    exit 1
fi

VERSION=$1
APP_PATH=${2:-"archives/Speech to Clip.app"}
DMG_NAME="SpeechToClip-v${VERSION}.dmg"
VOLUME_NAME="Speech to Clip ${VERSION}"
TEMP_DIR="/tmp/speechtoclip-dmg-$$"

echo -e "${GREEN}Creating DMG for Speech to Clip v${VERSION}${NC}"

# Verify app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at: $APP_PATH${NC}"
    echo "Please export the app from Xcode first."
    exit 1
fi

# Verify app is signed and notarized
echo -e "${YELLOW}Verifying code signature...${NC}"
codesign -vv "$APP_PATH" 2>&1 | grep -q "satisfies its Designated Requirement" || {
    echo -e "${RED}Error: App is not properly signed${NC}"
    exit 1
}

echo -e "${GREEN}✓ Code signature valid${NC}"

# Create temp directory
mkdir -p "$TEMP_DIR"
echo -e "${YELLOW}Created temp directory: $TEMP_DIR${NC}"

# Copy app to temp
echo -e "${YELLOW}Copying app bundle...${NC}"
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create Applications symlink
echo -e "${YELLOW}Creating Applications symlink...${NC}"
ln -s /Applications "$TEMP_DIR/Applications"

# Calculate required size (app size + 50MB buffer)
APP_SIZE=$(du -sm "$APP_PATH" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))
echo -e "${YELLOW}DMG size: ${DMG_SIZE}MB${NC}"

# Create dist directory if it doesn't exist
mkdir -p dist

# Remove old DMG if exists
[ -f "dist/$DMG_NAME" ] && rm "dist/$DMG_NAME"

# Create DMG
echo -e "${YELLOW}Creating DMG (this may take a minute)...${NC}"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "dist/$DMG_NAME"

# Clean up
echo -e "${YELLOW}Cleaning up temp files...${NC}"
rm -rf "$TEMP_DIR"

# Get DMG size
DMG_SIZE_ACTUAL=$(du -h "dist/$DMG_NAME" | cut -f1)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ DMG created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "File: dist/$DMG_NAME"
echo -e "Size: $DMG_SIZE_ACTUAL"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the DMG: open dist/$DMG_NAME"
echo "2. Upload to GitHub Releases"
echo "3. Add release notes from RELEASE_NOTES_TEMPLATE.md"
