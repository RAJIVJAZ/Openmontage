#!/bin/bash
# SessionStart hook for Claude Code cloud sessions: installs OpenMontage's
# Python deps, the free Piper voice, Remotion packages, and render browsers.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# Python dependencies (core + dev/test) and Piper offline TTS.
pip install --quiet --root-user-action=ignore -r requirements-dev.txt piper-tts

# Piper voice model. Hugging Face may be blocked by the network policy, so pull
# the same voice from Piper's GitHub release. *.onnx files are gitignored.
if [ ! -f en_US-lessac-medium.onnx ]; then
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/voice.tgz" \
    https://github.com/rhasspy/piper/releases/download/v0.0.2/voice-en-us-lessac-medium.tar.gz
  tar xzf "$tmp/voice.tgz" -C "$tmp"
  cp "$tmp/en-us-lessac-medium.onnx" en_US-lessac-medium.onnx
  cp "$tmp/en-us-lessac-medium.onnx.json" en_US-lessac-medium.onnx.json
  rm -rf "$tmp"
fi

# Remotion packages.
(cd remotion-composer && npm install --no-audit --no-fund --loglevel=error)

# Remotion downloads Chrome Headless Shell from a host that may be blocked;
# point its cache at the preinstalled Playwright headless shell instead.
shell_dir="$(ls -d /opt/pw-browsers/chromium_headless_shell-*/chrome-linux 2>/dev/null | head -1 || true)"
if [ -n "$shell_dir" ]; then
  cache=remotion-composer/node_modules/.remotion/chrome-headless-shell
  target="$cache/linux64/chrome-headless-shell-linux64"
  mkdir -p "$target"
  for f in "$shell_dir"/*; do ln -sfn "$f" "$target/"; done
  ln -sfn "$shell_dir/headless_shell" "$target/chrome-headless-shell"
  grep -oE "TESTED_VERSION = '[^']+'" \
    remotion-composer/node_modules/@remotion/renderer/dist/browser/get-chrome-download-url.js \
    | cut -d"'" -f2 | tr -d '\n' > "$cache/VERSION"
fi

# HyperFrames CLI and its render browser.
npx --yes hyperframes browser ensure >/dev/null
