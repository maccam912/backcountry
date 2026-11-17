#!/usr/bin/env python3
"""Run Backcountry inside the real Luanti engine in a throwaway world.
Nothing in your own worlds or settings is touched.

    python3 tools/run_engine_tests.py            # server only
    python3 tools/run_engine_tests.py --client   # also join with a real client window
"""
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("--engine", default="/Applications/luanti.app/Contents/MacOS/luanti")
p.add_argument("--client", action="store_true", help="join with a real client so player code paths run")
p.add_argument("--mapgen", default="valleys")
p.add_argument("--seed", default="4242")
p.add_argument("--port", default="30117")
p.add_argument("--keep", action="store_true")
p.add_argument("--old-spawn", default="", help='pretend an older version stored this start point, e.g. "(-25,16,-42)"')
p.add_argument("--show", type=int, default=0, metavar="SECONDS",
               help="stage a camp scene and keep a client open this long, for looking at the game (implies --client)")
p.add_argument("--headless", action="store_true", help="with --client: use the null video driver (no window)")
a = p.parse_args()

tmp = Path(tempfile.mkdtemp(prefix="backcountry-test-"))
games = tmp / "games"
games.mkdir()
os.symlink(ROOT, games / "backcountry")
world = tmp / "world"
world.mkdir()
(world / "world.mt").write_text(
    "gameid = backcountry\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\n"
    "mod_storage_backend = sqlite3\nenable_damage = true\ncreative_mode = false\n")
if a.show:
    a.client = True
    shutil.copytree(ROOT / "tests/showcase", world / "worldmods/bc_showcase")
else:
    shutil.copytree(ROOT / "tests/engine_probe", world / "worldmods/bc_probe")
conf = tmp / "server.conf"
conf.write_text(
    f"fixed_map_seed = {a.seed}\nmg_name = {a.mapgen}\nbind_address = 127.0.0.1\nport = {a.port}\n"
    f"server_announce = false\nenable_damage = true\ntime_speed = 48\nbc_probe_player = {'true' if a.client else 'false'}\n"
    "default_privs = interact,shout\n" + (f"bc_probe_old_spawn = {a.old_spawn}\n" if a.old_spawn else ""))
env = dict(os.environ, MINETEST_GAME_PATH=str(games), LUANTI_GAME_PATH=str(games),
           MINETEST_USER_PATH=str(tmp), LUANTI_USER_PATH=str(tmp))
log = tmp / "server.log"
server = subprocess.Popen([a.engine, "--server", "--world", str(world), "--config", str(conf), "--logfile", str(log)],
                          stdout=open(tmp / "server.out", "w"), stderr=subprocess.STDOUT, env=env)
client = None
if a.client:
    time.sleep(6)
    cconf = tmp / "client.conf"
    cconf.write_text(("screen_w = 2560\nscreen_h = 1600\n" if a.show else "screen_w = 1280\nscreen_h = 800\n") + "fullscreen = false\nwindow_maximized = false\nmute_sound = true\n"
                     "enable_sound = false\nviewing_range = 80\nmenu_last_game = backcountry\n"
                     + ("video_driver = null\nenable_post_processing = false\n" if a.headless else ""))
    client = subprocess.Popen([a.engine, "--go", "--address", "127.0.0.1", "--port", a.port, "--name", "probe",
                               "--password", "probe", "--config", str(cconf), "--logfile", str(tmp / "client.log")],
                              stdout=open(tmp / "client.out", "w"), stderr=subprocess.STDOUT, env=env)
if a.show:
    time.sleep(a.show)
    client.terminate()
    server.terminate()
    server.wait(timeout=20)
    text = log.read_text(errors="replace")
    bad = [l for l in text.splitlines() if "ERROR" in l]
    print("\n".join(bad) if bad else "showcase ran with no server errors")
    shutil.rmtree(tmp, ignore_errors=True)
    raise SystemExit(1 if bad else 0)
try:
    code = server.wait(timeout=240)
except subprocess.TimeoutExpired:
    server.kill()
    code = -1
if client:
    time.sleep(1)
    client.terminate()

text = log.read_text(errors="replace") if log.exists() else ""
errors = [l for l in text.splitlines() if "ERROR" in l or "error" in l.lower() and "lua" in l.lower()]
report = json.loads((world / "results.json").read_text()) if (world / "results.json").exists() else {
    "failures": ["engine exited before the probe finished"], "checks": 0, "notes": {}}
report["exit_code"] = code
report["log_errors"] = errors[:20]
print(json.dumps(report, indent=2))
ok = code == 0 and not report["failures"] and not errors
print("\nPASS" if ok else "\nFAIL", f"({report['checks']} checks)  work dir: {tmp}")
if not ok:
    print("\n".join(text.splitlines()[-40:]))
elif not a.keep:
    shutil.rmtree(tmp, ignore_errors=True)
raise SystemExit(0 if ok else 1)
