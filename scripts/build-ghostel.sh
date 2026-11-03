#!/usr/bin/env bash
set -euo pipefail
bundle_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $(zig version) == 0.16.0 ]] || { echo 'Use exactly Zig 0.16.0' >&2; exit 1; }
case $(uname -m) in
  x86_64) ghost_target=x86_64-linux-gnu.2.28 ;;
  aarch64) ghost_target=aarch64-linux-gnu.2.28 ;;
  *) echo 'Supported targets: x86_64/aarch64' >&2; exit 1 ;;
esac
export ZIG_GLOBAL_CACHE_DIR=${ZIG_GLOBAL_CACHE_DIR:-"$bundle_dir/vendor/zig-cache"}
cd "$bundle_dir/vendor/ghostel"
# Explicit glibc target prevents accidentally creating an Ubuntu-only module.
zig build --prefix . -Doptimize=ReleaseFast -Dcpu=baseline -Dtarget="$ghost_target" -j"${BUILD_JOBS:-2}"
readelf --version-info ghostel-module.so
python3 - ghostel-module.so <<'PYCODE'
import re,subprocess,sys
out=subprocess.check_output(['readelf','--version-info',sys.argv[1]]).decode()
versions=[tuple(map(int,v.split('.'))) for v in re.findall(r'GLIBC_(\d+\.\d+(?:\.\d+)?)',out)]
if versions and max(versions) > (2,28):
    sys.exit('ERROR: module requires glibc newer than 2.28')
print('glibc symbol version check passed')
PYCODE
