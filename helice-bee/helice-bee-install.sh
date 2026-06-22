#!/bin/bash
set -e

INSTALL_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
BINARY_NAME="helicebee"
PAGES_URL="https://kop-ter.github.io/helice-bee"

echo "=== HeliceBee Installer ==="

# ── Architecture check ────────────────────────────────────────────────────────
if [ "$(uname -m)" != "x86_64" ]; then
    echo "Unsupported architecture: $(uname -m). Only x86_64 is supported."
    exit 1
fi

# ── Detect update vs fresh install ───────────────────────────────────────────
IS_UPDATE=false
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo "Existing install found — updating..."
    IS_UPDATE=true
fi

# ── System dependencies (fresh install only) ─────────────────────────────────
if [ "$IS_UPDATE" = false ]; then
    echo "Installing system dependencies..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm webkit2gtk-4.1 alsa-lib
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y libwebkit2gtk-4.1-0 libasound2
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y webkit2gtk4.1 alsa-lib
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y libwebkit2gtk-4_1-0 libasound2
    else
        echo "Warning: unknown package manager. Ensure webkit2gtk-4.1 and alsa-lib are installed."
    fi
fi

# ── Fetch latest version ──────────────────────────────────────────────────────
echo "Fetching latest release..."
LATEST_JSON=$(curl -fsSL "$PAGES_URL/latest.json")
VERSION=$(echo "$LATEST_JSON" | python3 -c "import sys,json; latest=json.load(sys.stdin); print(latest.get('linux', {}).get('version') or latest.get('version', ''))")
DOWNLOAD_URL=$(echo "$LATEST_JSON" | python3 -c "import sys,json; latest=json.load(sys.stdin); print(latest.get('linux', {}).get('url', ''))")

if [ -z "$DOWNLOAD_URL" ] || [ -z "$VERSION" ]; then
    echo "Error: could not parse Linux release info from latest.json"
    exit 1
fi

echo "Downloading version $VERSION..."
TMP=$(mktemp)
curl -fsSL -o "$TMP" "$DOWNLOAD_URL"
chmod +x "$TMP"

# ── Install binary ────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
mv "$TMP" "$INSTALL_DIR/$BINARY_NAME"
echo "Installed to $INSTALL_DIR/$BINARY_NAME"

# ── Icon ──────────────────────────────────────────────────────────────────────
mkdir -p "$ICON_DIR"
curl -fsSL -o "$ICON_DIR/$BINARY_NAME.png" "$PAGES_URL/icon.png"

# ── Desktop entry (taskbar / app launcher) ────────────────────────────────────
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/com.helice.helicebee.desktop" <<EOF
[Desktop Entry]
Name=HeliceBee
Exec=env WEBKIT_DISABLE_COMPOSITING_MODE=1 GDK_BACKEND=x11 $INSTALL_DIR/$BINARY_NAME
Icon=$ICON_DIR/$BINARY_NAME.png
Type=Application
Categories=AudioVideo;Audio;Player;
StartupWMClass=com.helice.helicebee
EOF

# Refresh desktop/icon caches if the tools are available
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

# ── PATH (fresh install only) ─────────────────────────────────────────────────
if [ "$IS_UPDATE" = false ]; then
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
            if [ -f "$rc" ] && ! grep -qF "$INSTALL_DIR" "$rc"; then
                echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$rc"
            fi
        done
        fish_config="$HOME/.config/fish/config.fish"
        if [ -f "$fish_config" ] && ! grep -qF 'fish_add_path $HOME/.local/bin' "$fish_config"; then
            echo 'fish_add_path $HOME/.local/bin' >> "$fish_config"
        fi
        echo "Added $INSTALL_DIR to PATH. Restart your shell or run:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

echo ""
if [ "$IS_UPDATE" = true ]; then
    echo "Updated to $VERSION. Restart HeliceBee to use the new version."
else
    echo "Done! Run: $BINARY_NAME"
fi
