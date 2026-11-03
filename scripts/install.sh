#!/usr/bin/env bash
set -euo pipefail
bundle_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target_dir=${1:-"$HOME/.local/share/claude-ide"}
if [[ -e "$target_dir" ]]; then
  echo "Destination exists; choose a new directory: $target_dir" >&2; exit 1
fi
mkdir -p -- "$(dirname -- "$target_dir")"
cp -a -- "$bundle_dir" "$target_dir"
printf 'Installed at %s\n' "$target_dir"
echo 'Add the following line to your Emacs init file:'
python3 - "$target_dir" <<'PYCODE'
import json,sys
print('(load '+json.dumps(sys.argv[1]+'/claude-ide-init.el')+' nil t)')
PYCODE
