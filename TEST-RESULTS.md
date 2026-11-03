# Verification — 2026-11-03

Host: Ubuntu 26.04 / WSL2, Emacs 30.2, x86_64.

- 5 Python MCP tests: passed.
- 8 Emacs ERT tests: passed, including Ghostel native PTY roundtrip and built-in term PTY roundtrip, Korean UTF-8/IME prefix replacement, CLI option construction, project-context isolation and private-state cleanup.
- Standalone init load: passed.
- Relocated installation (path containing spaces), init load and refusal to overwrite existing destination: passed.
- Shell syntax and bridge Python 3.6 syntax: passed.
- Ghostel compilation: Zig 0.16.0, x86_64-linux-gnu.2.28, baseline CPU, successful.
- ELF maximum required glibc version: 2.28. Emacs module loading: passed on build host.

Not tested: actual RHEL 8 runtime, GUI rendering/key events/interactive Korean composition on RHEL, aarch64 build, Emacs 28 runtime, Claude Code authentication/real model response, full Emacs 30.2 source build on RHEL 8.
The terminal integration uses a fake Claude executable over a real PTY; no model call, credentials, permission approval or billing is involved in tests.

See tests/test-output.txt and BUILD-METADATA.json.
