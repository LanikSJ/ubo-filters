#!/bin/bash
# FOP VS Code Setup Script
# Copies VS Code configuration to your filter list project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "FOP VS Code Setup"
echo "================="
echo ""

# Get target directory
TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
    echo -e "${RED}Error: Directory '$TARGET' does not exist${NC}"
    exit 1
fi

# Get script directory (where .vscode files are)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in the .vscode folder
if [[ "$SCRIPT_DIR" == *".vscode" ]]; then
    SOURCE_DIR="$SCRIPT_DIR"
else
    SOURCE_DIR="$SCRIPT_DIR/.vscode"
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Cannot find .vscode source folder${NC}"
    exit 1
fi

TARGET_VSCODE="$TARGET/.vscode"

# Create .vscode folder if needed
if [ -d "$TARGET_VSCODE" ]; then
    echo -e "${YELLOW}Warning: .vscode folder already exists in $TARGET${NC}"
    read -p "Overwrite existing files? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
else
    mkdir -p "$TARGET_VSCODE"
fi

# Copy files
echo "Copying VS Code configuration..."

for file in tasks.json settings.json extensions.json; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$TARGET_VSCODE/"
        echo -e "  ${GREEN}✓${NC} $file"
    fi
done

# Copy keybindings example (optional)
if [ -f "$SOURCE_DIR/keybindings.example.jsonc" ]; then
    cp "$SOURCE_DIR/keybindings.example.jsonc" "$TARGET_VSCODE/"
    echo -e "  ${GREEN}✓${NC} keybindings.example.jsonc"
fi

echo ""

# Create .fopconfig if it doesn't exist
if [ ! -f "$TARGET/.fopconfig" ]; then
    read -p "Create .fopconfig with recommended settings? (Y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cat > "$TARGET/.fopconfig" << 'EOF'
# FOP Configuration
# See https://github.com/ryanbr/fop-rs for all options

# Skip commit prompt (use VS Code git integration instead)
no-commit = true

# Typo detection
fix-typos = false

# Keep formatting preferences
keep-empty-lines = false
backup = false

# Quiet output
quiet = false
EOF
        echo -e "${GREEN}✓${NC} Created .fopconfig"
    fi
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open your project in VS Code"
echo "  2. Install recommended extensions when prompted"
echo "  3. Run FOP: Ctrl+Shift+P → 'Tasks: Run Task' → 'FOP: Sort All'"
echo ""
echo "Optional: Copy keyboard shortcuts from keybindings.example.jsonc"
echo "          to your VS Code user keybindings (Ctrl+K Ctrl+S → {})"
