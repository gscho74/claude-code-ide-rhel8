#!/usr/bin/env bash
set -uo pipefail
bundle_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
status=0
for tool in "${EMACS:-emacs}" "${PYTHON:-python3}" claude readelf; do
  if ! command -v "$tool"; then status=1; fi
done
ldd --version | head -1
"${PYTHON:-python3}" -c 'import sys; assert sys.version_info >= (3,6); print(sys.version) ' || status=1
"${EMACS:-emacs}" -Q --batch --eval '(progn (princ (format "Emacs %s modules=%S\n" emacs-version module-file-suffix)) (when (or (version< emacs-version "28.1") (not module-file-suffix)) (kill-emacs 1)))' || status=1
claude --version || status=1
if [[ -f "$bundle_dir/vendor/ghostel/ghostel-module.so" ]]; then
  CLAUDE_IDE_MODULE="$bundle_dir/vendor/ghostel/ghostel-module.so" "${EMACS:-emacs}" -Q --batch --eval '(module-load (getenv "CLAUDE_IDE_MODULE"))' || status=1
else
  echo 'Ghostel module missing: run scripts/build-ghostel.sh'; status=1
fi
printf 'DISPLAY=%s WAYLAND_DISPLAY=%s\n' "${DISPLAY:-}" "${WAYLAND_DISPLAY:-}"
exit "$status"
