#!/usr/bin/env bash
# Prepares a Cursor Cloud Agent VM to validate this repo the way CI does.
# Idempotent: safe to re-run. Installs the pinned Flutter SDK and all deps so
# the agent can run `flutter analyze`, `flutter test`, and `npm test` before it
# opens a pull request. The GitHub Actions `check.yml` remains the gate.
set -euo pipefail

FLUTTER_VERSION="3.47.5"
FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
if ! grep -qs 'flutter/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >>"$HOME/.bashrc"
fi

flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true

# Dependencies for the three test suites: root scripts, Functions, Flutter app.
npm ci
(cd functions && npm ci)
(cd app && flutter pub get)
