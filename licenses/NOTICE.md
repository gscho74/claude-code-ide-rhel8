# Source notices

claude-ide files are derived from the local codex-ide 0.5.0 sources carrying SPDX-License-Identifier: MIT.
The original local sources provide no separate copyright holder/license text; their SPDX notices are retained.
New adapter/packaging files use MIT terms (see MIT.txt).
Ghostel is by Daniel Kraus, GPL-3.0-or-later; individual headers and bundled vendor notices are preserved.
Ghostel and its native module are not relicensed by the MIT adapter.
The Ghostty dependency is downloaded by Zig using the pinned build.zig.zon metadata.
No Claude Code binary, credentials, private project, Windows fonts or original Ubuntu native modules are included. A newly built x86_64 glibc-2.28-targeted Ghostel module is included, with Ghostel sources and dependency source archives in vendor/zig-cache/p. The compiler (Zig 0.16.0) is available from https://ziglang.org/download/.

compat 30.1.0.1, Copyright (C) 2021-2025 Free Software Foundation, Inc., GPL-3.0-or-later. Source and COPYING are included in vendor/compat.
