#!/usr/bin/env python3
import subprocess
import json
import sys

APP_ID = "foot-scratchpad"
STASH_WS = 99

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

try:
    windows = json.loads(run(['niri', 'msg', '--json', 'windows']).stdout)
    workspaces = json.loads(run(['niri', 'msg', '--json', 'workspaces']).stdout)
except Exception:
    subprocess.Popen(
        ['foot', f'--app-id={APP_ID}'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    sys.exit(0)

focused_ws = next((ws for ws in workspaces if ws.get('is_focused')), None)
scratch_win = next((w for w in windows if w.get('app_id') == APP_ID), None)

if not scratch_win:
    subprocess.Popen(
        ['foot', f'--app-id={APP_ID}'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
elif scratch_win.get('is_focused'):
    run(['niri', 'msg', 'action', 'move-window-to-workspace', str(STASH_WS), '--window-id', str(scratch_win['id']), '--focus', 'false'])
else:
    if focused_ws:
        target_ws = focused_ws.get('name') or str(focused_ws.get('idx'))
        run(['niri', 'msg', 'action', 'move-window-to-workspace', target_ws, '--window-id', str(scratch_win['id']), '--focus', 'true'])
    run(['niri', 'msg', 'action', 'focus-window', '--id', str(scratch_win['id'])])
