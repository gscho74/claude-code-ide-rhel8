#!/usr/bin/env bash
set -euo pipefail
# Run on RHEL 8, after installing the development packages in README.ko.md.
emacs_build_dir=${EMACS_BUILD_DIR:-"$HOME/.cache/claude-ide-build"}
emacs_prefix=${EMACS_PREFIX:-"$HOME/.local/opt/emacs-30.2"}
mkdir -p "$emacs_build_dir"
cd "$emacs_build_dir"
if [[ ! -f emacs-30.2.tar.xz ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 -o emacs-30.2.tar.xz https://ftp.gnu.org/gnu/emacs/emacs-30.2.tar.xz
fi
if [[ ! -d emacs-30.2 ]]; then tar -xf emacs-30.2.tar.xz; fi
cd emacs-30.2
# GTK3/X11 works with a conventional RHEL desktop or X forwarding.
./configure --prefix="$emacs_prefix" --with-x-toolkit=gtk3 --with-modules --without-native-compilation
make -j"${BUILD_JOBS:-2}"
make install
printf 'Emacs installed: %s/bin/emacs\n' "$emacs_prefix"
