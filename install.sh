#!/bin/sh
# claude-profiles installer (macOS / Linux): puts `ccp` in ~/.local/bin.
#
#   curl -fsSL https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/install.sh | sh
#   # or from a clone:  ./install.sh
set -e
BIN="${CCP_BIN_DIR:-$HOME/.local/bin}"
RAW="https://raw.githubusercontent.com/yuna-studio/claude-profiles/main/ccp"
mkdir -p "$BIN"
SRC="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
if [ -n "$SRC" ] && [ -f "$SRC/ccp" ] && [ -f "$SRC/install.sh" ]; then cp "$SRC/ccp" "$BIN/ccp.new"
else curl -fsSL "$RAW" -o "$BIN/ccp.new"; fi
chmod +x "$BIN/ccp.new" && mv "$BIN/ccp.new" "$BIN/ccp"
echo "installed $BIN/ccp ($("$BIN/ccp" --version))"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "add $BIN to PATH:  echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.zshrc" ;; esac
echo
if [ -z "${CCP_NO_SETUP:-}" ]; then   # shell, status line, Claude Code plugin, service: nothing to set by hand
  "$BIN/ccp" setup || echo "setup did not finish; run: ccp setup"
else
  echo "next: ccp setup   (shell, status line, Claude Code plugin, service)"
fi
