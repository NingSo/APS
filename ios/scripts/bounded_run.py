#!/usr/bin/env python3
"""Bound one CI command without hiding its exit code or leaving child processes alive."""
import os
import signal
import subprocess
import sys

seconds = int(sys.argv[1])
command = sys.argv[2:]
if not command:
    raise SystemExit('A command is required')
process = subprocess.Popen(command, start_new_session=True)
try:
    result = process.wait(timeout=seconds)
except subprocess.TimeoutExpired:
    print(f'CI command exceeded {seconds} seconds; interrupting to retain diagnostics.', flush=True)
    os.killpg(process.pid, signal.SIGINT)
    try:
        process.wait(timeout=20)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    result = 124
raise SystemExit(result if result >= 0 else 128 - result)
