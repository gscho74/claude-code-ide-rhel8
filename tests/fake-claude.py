#!/usr/bin/env python3
import json, os, sys, tty
# A real PTY peer for testing Emacs startup/paste/cleanup without a model call.
tty.setraw(sys.stdin.fileno())
print('FAKE_READY '+json.dumps(sys.argv[1:]), flush=True)
while True:
    data=os.read(sys.stdin.fileno(), 65536)
    if not data:
        break
    print('RECEIVED '+json.dumps(data.decode('utf-8', errors='replace'), ensure_ascii=False), flush=True)
