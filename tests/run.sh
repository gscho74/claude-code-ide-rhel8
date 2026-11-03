#!/usr/bin/env bash
set -euo pipefail
bundle_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
for script in "$bundle_dir"/scripts/*.sh "$bundle_dir"/tests/*.sh; do bash -n "$script"; done
python3 "$bundle_dir/tests/test_mcp.py"
"${EMACS:-emacs}" -Q --batch -l "$bundle_dir/claude-ide-init.el" --eval '(princ "Standalone init loaded successfully\n")'
"${EMACS:-emacs}" -Q --batch -L "$bundle_dir/vendor/compat" -L "$bundle_dir/vendor/ghostel" -L "$bundle_dir/lisp" -l "$bundle_dir/tests/claude-ide-tests.el" -f ert-run-tests-batch-and-exit
