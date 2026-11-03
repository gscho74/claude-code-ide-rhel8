# Claude IDE for Emacs — RHEL 8

An Emacs editor-context integration for Claude Code, adapted from a local
Codex IDE setup. Includes Ghostel terminal integration, Korean input handling,
selected-code/file/diagnostic sharing through a read-only stdio MCP bridge,
and Claude's native session resume flow.

**[한국어 설치 및 사용 안내](README.ko.md)**

## Source checkout versus deployment bundle

This Git repository contains the integration, tests, installation/build scripts,
and pinned Ghostel/compat sources. Generated native modules, downloaded Zig
sources/cache, and deployment checksums are excluded from Git.

A source checkout requires building Ghostel before use:

```bash
# Emacs 28.1+ with dynamic modules; Python 3.6+; Claude Code CLI.
# Install exactly Zig 0.16.0, then:
bash scripts/build-ghostel.sh
bash scripts/install.sh
```

Add the `(load ...)` form printed by the installer to your Emacs init.
Start a session with `C-c a n`; use `C-c a r` to send selected code.
See the Korean guide for RHEL development packages and an Emacs 30.2 build script.

The prepared x86_64 deployment tarball also contains a Ghostel module targeting
glibc 2.28 and the dependency source archives used to build it. It is distributed
separately from the source repository. No Claude binary or credentials are included.

## Validation

```bash
bash tests/run.sh
```

Without a built Ghostel module, its native integration test is skipped.
See [TEST-RESULTS.md](TEST-RESULTS.md) for the prepared bundle's verification.
Tests use a fake Claude process over real PTYs, without model calls.
Actual RHEL 8 GUI, Korean key events, and authenticated Claude sessions still
need validation on the target host.

## Licenses

Integration and packaging: [MIT](LICENSE).
Vendored Ghostel and compat: **GPL-3.0-or-later**, with their source notices retained.
The MIT license does not relicense these dependencies or the Ghostel module.
See [third-party notices](licenses/NOTICE.md).
