#!/bin/bash
# Starts mobai-ci runner with an xcfast build, then drives its API: two more
# simulators (slim auto, stock), the limit, a rebuild after a source change,
# and closing everything. Prints times and memory at each stage.
set -u
API=http://127.0.0.1:7101
T0=$(date +%s)
FAILED=0

since() { echo "$(( $(date +%s) - $1 ))s"; }
page=$(sysctl -n hw.pagesize)
mem() {
  vm_stat | awk -v p="$page" -v label="$1" '
    /Pages active/ {a=$3} /Pages wired down/ {w=$4} /occupied by compressor/ {c=$5}
    /Pages free/ {f=$3}
    END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); gsub(/\./,"",f);
         printf "MEM %-22s used %.1f GB (active %.1f, wired %.1f, compressed %.1f), free %.1f GB\n",
         label, (a+w+c)*p/2^30, a*p/2^30, w*p/2^30, c*p/2^30, f*p/2^30}'
  echo "    swap: $(sysctl -n vm.swapusage)"
}
state() { curl -s "$API/simulators/$1" | jq -r '.state // empty'; }
wait_ready() { # id timeout
  local end=$(( $(date +%s) + $2 )) s
  while [ "$(date +%s)" -lt "$end" ]; do
    s=$(state "$1")
    case "$s" in
      ready) return 0 ;;
      failed|closed) echo "!! $1 $s: $(curl -s "$API/simulators/$1" | jq -r .error)"; return 1 ;;
    esac
    kill -0 "$PID" 2>/dev/null || { echo "!! the runner exited"; return 1; }
    sleep 2
  done
  echo "!! $1 not ready in $2s"; return 1
}
rebuild() { # id
  local start end s
  [ "$(state "$1")" = ready ] || { echo "!! REBUILD $1 is $(state "$1"), not ready"; return 1; }
  start=$(date +%s)
  curl -s -X POST "$API/simulators/$1/host/rebuild" -H 'Content-Type: application/json' -d '{}' >/dev/null
  end=$(( start + 900 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    s=$(curl -s "$API/simulators/$1/host/rebuild" | jq -r .state)
    case "$s" in
      done) echo "REBUILD $1 done in $(since "$start")"; return 0 ;;
      failed) echo "!! REBUILD $1 failed: $(curl -s "$API/simulators/$1/host/rebuild" | jq -c '{error, log: .log[-20:]}')"; return 1 ;;
    esac
    sleep 2
  done
  echo "!! REBUILD $1 did not finish"; return 1
}

echo "machine: $(sysctl -n hw.ncpu) cores ($(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null) performance), $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
echo "xcfast cache before: $(du -sh ~/.xcfast 2>/dev/null | cut -f1 || echo none)"
mem "before"

# PHASES: CPU from the job's start. Every 5s the load, swap and the top
# processes, and every process at each stage (S: the runner starts, then each
# phase): the difference in CPU time between two lists is each process's CPU
# seconds in between. All of it goes to the draft release every 15s, since a
# machine that hangs never hands its job log back.
if [ "${PHASES:-0}" = 1 ]; then
  : > cpu.log
  : > runner.log
  mkdir -p snaps
  snap() { ps -axo pid=,ppid=,user=,time=,rss=,args= > "snaps/$1.txt"; }
  upload() {
    cp cpu.log runner.log snaps/
    tar czf "snaps-fps${MAX_FPS:-30}.tgz" snaps
    gh release upload runner-test "snaps-fps${MAX_FPS:-30}.tgz" --clobber -R "$GITHUB_REPOSITORY" >/dev/null 2>&1
  }
  ( while :; do
      { echo "CPU $(date -u +%H:%M:%S) load $(sysctl -n vm.loadavg) swap used $(sysctl -n vm.swapusage | awk '{print $6}')"
        top -l 2 -s 2 -n 12 -o cpu -stats pid,command,cpu,mem,threads \
          | awk '/^CPU usage/{u++; if(u==2) print "CPU   " $0} /^PID/{c++; next} c==2&&NF{print "CPU   " $0}'
        grep -hE "stream: [0-9.]+ fps" runner.log | tail -1
      } | tee -a cpu.log
      sleep 3
    done ) &
  SAMPLER=$!
  ( while :; do sleep 15; upload; done ) &
  UPLOADER=$!
  snap S
  echo "PHASE S: runner starts $(date -u +%H:%M:%S)" | tee -a cpu.log
fi

# --duration is long so no simulator closes for being unused mid-test.
# Every runner line gets the time, to line it up with the viewer's side.
./bin/mobai-ci runner --xcfast "$PWD/bin/xcfast" \
  --duration 45m --max-duration 50m --max-simulators "${MAX_SIMS:-3}" --max-fps "${MAX_FPS:-30}" \
  --label "${GITHUB_REPOSITORY} ${LABEL:-runner test}" 2>&1 \
  | while IFS= read -r l; do echo "$(date -u +%H:%M:%S) $l"; done | tee runner.log | sed 's/^/RUNNER /' &
PID=$!
trap 'echo "::group::runner log"; cat runner.log; echo "::endgroup::"; echo "::group::tunnel log"; cat "${TMPDIR:-/tmp}"/mobai-ci-tunnel-*.log; echo "::endgroup::"' EXIT
stop_runner() { curl -s -X POST "$API/stop" | jq -c .; for _ in $(seq 1 60); do pgrep -f "bin/mobai-ci runner" >/dev/null || break; sleep 2; done; }

# The runner builds, then waits: it starts no simulator by itself. Ask for the
# first one the way any client would.
for _ in $(seq 1 400); do curl -sf "$API/health" >/dev/null && break; sleep 2; done
echo "STAGE runner API up $(since "$T0") after start"

# LAT=1: how fast the screen answers a finger (latency.mjs on this machine,
# through s1's H.264 socket), step by step: as it is, with the Mac's Spotlight
# indexing off, with two more idle simulators. Then held HOLD_MINUTES so it
# can be measured through the tunnel too. Logs go to the release every 15s.
if [ "${LAT:-}" = 1 ]; then
  LOG=latency.log
  : > "$LOG"
  say() { echo "$*" | tee -a "$LOG"; }
  ( while :; do sleep 15; cp runner.log runner-latency.log 2>/dev/null
      tar czf latency.tgz "$LOG" runner-latency.log 2>/dev/null
      gh release upload runner-test latency.tgz --clobber -R "$GITHUB_REPOSITORY" >/dev/null 2>&1; done ) &
  UPLOADER=$!
  ( while :; do say "LOAD $(date -u +%H:%M:%S) $(sysctl -n vm.loadavg) swap $(sysctl -n vm.swapusage | awk '{print $6}')"; sleep 5; done ) &
  LOADS=$!
  top5() { top -l 2 -s 2 -n 8 -o cpu -stats command,cpu,mem | awk '/^PID|^COMMAND/{c++; next} c==2&&NF' | sed "s/^/TOP $1 /" | tee -a "$LOG"; }
  lat() { say "STEP $1 $(date -u +%H:%M:%S)"; top5 "$1"
    node .github/runner-test/latency.mjs "$1" "ws://127.0.0.1:7101/simulators/s1/screen/ws" 20 2>&1 | tee -a "$LOG"; }
  curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{"screen":"h264"}' >/dev/null
  wait_ready s1 900 && say "s1 ready $(since "$T0") after start"
  sleep 60
  lat "1 sim"
  sudo mdutil -a -i off 2>&1 | tee -a "$LOG"
  sleep 30
  lat "1 sim, Spotlight indexing off"
  for k in 2 3; do
    curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{"screen":"h264"}' >/dev/null
    wait_ready "s$k" 900 && say "s$k ready"
  done
  sleep 60
  lat "3 sims (2 idle)"
  say "HOLD $(date -u +%H:%M:%S)"
  sleep $(( ${HOLD_MINUTES:-15} * 60 ))
  kill "$LOADS"
  stop_runner
  kill "$UPLOADER"
  tar czf latency.tgz "$LOG" runner.log
  gh release upload runner-test latency.tgz --clobber -R "$GITHUB_REPOSITORY" >/dev/null 2>&1
  exit 0
fi

# VIEW="h264 mjpeg h264": one simulator per word, each started with that
# screen, kept up HOLD_MINUTES for the MobAI app to show, then the runner is
# stopped.
if [ -n "${VIEW:-}" ]; then
  k=0
  for mode in $VIEW; do
    k=$((k + 1))
    curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d "{\"screen\":\"$mode\"}" | jq -c .
    wait_ready "s$k" 900 && echo "STAGE s$k ($mode) ready $(since "$T0") after start"
  done
  curl -s "$API/simulators" | jq -c '.simulators[] | {id, screen, state}'
  sleep $(( ${HOLD_MINUTES:-25} * 60 ))
  stop_runner
  exit 0
fi

# STREAM=mjpeg|h264: how many simulators this machine can show at once. One
# simulator more at each level, each with a viewer on this machine through the
# runner's screen route (each started with "screen": "mjpeg", the on-device
# runner's frames, or "h264", the runner's encoder). Every level is measured with the screens still, then
# switching between light and dark every second on all of them.
# The log goes to the draft release every 15s, since a machine that hangs
# never hands its job log back.
if [ -n "${STREAM:-}" ]; then
  LOG="stream-$STREAM.log"
  : > "$LOG"
  say() { echo "$*" | tee -a "$LOG"; }
  ( while :; do sleep 15; cp runner.log "runner-$STREAM.log" 2>/dev/null
      tar czf "stream-$STREAM.tgz" "$LOG" "runner-$STREAM.log" 2>/dev/null
      gh release upload runner-test "stream-$STREAM.tgz" --clobber -R "$GITHUB_REPOSITORY" >/dev/null 2>&1; done ) &
  UPLOADER=$!
  ( while :; do say "LOAD $(date -u +%H:%M:%S) $(sysctl -n vm.loadavg) swap $(sysctl -n vm.swapusage | awk '{print $6}')"; sleep 5; done ) &
  LOADS=$!
  # Every Spotlight process with its path and memory, to tell the Mac's own
  # from each simulator's.
  spotlight() {
    ps -axo pid=,rss=,args= | grep -E "Spotlight|mds_stores|mdworker" | grep -v grep \
      | awk -v t="$1" '{printf "SPOT %s %6.0f MB %s\n", t, $2/1024, substr($0, index($0,$3))}' | cut -c1-220 | tee -a "$LOG"
  }
  udids=()
  for k in $(seq 1 "${MAX_SIMS:-5}"); do
    say "LEVEL $k: starting simulator s$k $(date -u +%H:%M:%S)"
    T=$(date +%s)
    curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d "{\"screen\":\"$STREAM\"}" | jq -c . | tee -a "$LOG"
    wait_ready "s$k" 900 || { say "LEVEL $k: s$k did not start, stopping here"; break; }
    u=$(curl -s "$API/simulators/s$k" | jq -r .udid)
    udids+=("$u")
    say "LEVEL $k: s$k ready in $(since "$T")"
    mem "with $k simulators" | tee -a "$LOG"
    if [ "$STREAM" = mjpeg ]; then
      node .github/runner-test/watch.mjs mjpeg "s$k" "$API/simulators/s$k/screen/mjpeg?fps=30&scale=50&quality=50" | tee -a "$LOG" &
    else
      node .github/runner-test/watch.mjs h264 "s$k" "ws://127.0.0.1:7101/simulators/s$k/screen/ws" | tee -a "$LOG" &
    fi
    sleep 10
    say "LEVEL $k still $(date -u +%H:%M:%S)"
    sleep 30
    top -l 2 -s 2 -n 10 -o cpu -stats command,cpu,mem | awk '/^PID|^COMMAND/{c++; next} c==2&&NF' | sed "s/^/TOP $k still /" | tee -a "$LOG"
    spotlight "$k still"
    say "LEVEL $k moving $(date -u +%H:%M:%S)"
    # Light and dark in turn every second: the whole screen redraws, without
    # the redrawing web page, which took 5 GB in SimRenderServer and froze
    # the machine in swap.
    ( n=0; while :; do n=$((n + 1)); a=light; [ $((n % 2)) = 1 ] && a=dark
        for u2 in "${udids[@]}"; do xcrun simctl ui "$u2" appearance "$a" & done; wait; sleep 1; done ) &
    TOGGLE=$!
    sleep 40
    top -l 2 -s 2 -n 10 -o cpu -stats command,cpu,mem | awk '/^PID|^COMMAND/{c++; next} c==2&&NF' | sed "s/^/TOP $k moving /" | tee -a "$LOG"
    mem "moving, $k simulators" | tee -a "$LOG"
    spotlight "$k moving"
    kill "$TOGGLE"; wait "$TOGGLE" 2>/dev/null
    for u2 in "${udids[@]}"; do xcrun simctl ui "$u2" appearance light; done
    say "LEVEL $k done $(date -u +%H:%M:%S)"
  done
  pkill -f watch.mjs
  kill "$LOADS"
  stop_runner
  sleep 2
  kill "$UPLOADER"
  tar czf "stream-$STREAM.tgz" "$LOG" runner.log
  gh release upload runner-test "stream-$STREAM.tgz" --clobber -R "$GITHUB_REPOSITORY" >/dev/null 2>&1
  exit 0
fi

# DRIVE: how fast the app's screens go when a test drives the simulator and
# nobody watches (no video at all). The runner only builds here; the simulator
# is booted slim the same way (everything off before its first boot) and a
# test walks every screen three times, each step timed.
if [ "${DRIVE:-}" = 1 ]; then
  APP=$(ls -d ~/.xcfast/*/dd/Build/Products/Debug-iphonesimulator/*.app | head -1)
  echo '{}' > slim.json
  T=$(date +%s)
  UDID=$(./bin/mobai-ci sim boot --slim slim.json --name drive-sim | tail -1)
  echo "STAGE slim simulator booted in $(since "$T")"
  ( while :; do echo "LOAD $(date -u +%H:%M:%S) $(sysctl -n vm.loadavg)"; sleep 5; done ) &
  LOADS=$!
  for i in 1 2 3; do
    echo "DRIVE run $i $(date -u +%H:%M:%S)"
    if [ "$i" = 1 ]; then set -- --app "$APP"; else set --; fi
    ./bin/mobai-ci test .github/runner-test/drive.mob --device "$UDID" "$@" \
      --progress --timeout 10m --output "drive-$i" 2>&1 | sed "s/^/DRIVE$i /"
    [ "${PIPESTATUS[0]}" = 0 ] || FAILED=1
  done
  kill "$LOADS"
  xcrun simctl delete "$UDID"
  stop_runner
  exit "$FAILED"
fi
curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{}' | jq -c .
sim1() { curl -s "$API/simulators/s1" | jq -r '.udid // empty'; }

# HOLD: only the first simulator, kept up for someone to watch.
if [ "${HOLD:-}" = 1 ]; then
  wait_ready s1 1200 && echo "STAGE s1 ready $(since "$T0") after start"
  MOBAI_SIM_UDID=$(sim1)
  HOLD_START=$(date +%s)
  # PHASES: what takes the CPU. Every 5s the load, swap and the top processes;
  # the phases change one thing at a time: a viewer (on the developer's
  # computer, joining at B and leaving at D) and a page that redraws every frame.
  if [ "${PHASES:-0}" = 1 ]; then
    mkdir -p anim
    cat > anim/index.html <<'EOF'
<meta name="viewport" content="width=device-width">
<style>body{margin:0;font:700 64px -apple-system;display:grid;place-items:center;height:100vh}
#b{width:160px;height:160px;background:#e33;animation:s 1s linear infinite}
@keyframes s{to{transform:rotate(360deg)}}</style>
<div><div id="b"></div><p id="n">0</p></div>
<script>let i=0;(function f(){document.getElementById('n').textContent=++i;requestAnimationFrame(f)})()</script>
EOF
    (cd anim && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
    phase() { snap "${1%%:*}"; echo "PHASE $1 $(date -u +%H:%M:%S)" | tee -a cpu.log; }
    phase "A: still, nobody watching"
    # What the runner itself does after it shared the simulator (the test
    # build keeps its symbols, so sample names Go functions).
    RPID=$(pgrep -f "bin/mobai-ci runner" | head -1)
    sleep 3
    sample "$RPID" 10 -file snaps/sample-mobai-ci-1.txt >/dev/null 2>&1
    sleep 15
    sample "$RPID" 10 -file snaps/sample-mobai-ci-2.txt >/dev/null 2>&1
    sleep 22
    phase "B: still, watched"; sleep 90
    phase "C: animation, watched"
    xcrun simctl openurl "$MOBAI_SIM_UDID" http://127.0.0.1:8765/ &
    sleep 30
    # What diagnosticd is busy with (the Mac's runs as root).
    for p in $(pgrep -x diagnosticd); do sudo sample "$p" 3 -file "snaps/sample-diagnosticd-$p.txt" >/dev/null 2>&1 & done
    sleep 30
    phase "D: animation, nobody watching"; sleep 60
    phase "E: app, nobody watching"
    ( xcrun simctl terminate "$MOBAI_SIM_UDID" com.apple.mobilesafari; xcrun simctl launch "$MOBAI_SIM_UDID" run.mobai.shelf ) &
    sleep 60
    phase "end"
    kill "$SAMPLER" "$UPLOADER"
    upload
  fi
  # ANIMATE: a page that redraws every frame, so the stream's frame rate can be
  # measured without anyone driving. Then the app comes back.
  if [ "${ANIMATE_SECONDS:-0}" -gt 0 ]; then
    mkdir -p anim
    cat > anim/index.html <<'EOF'
<meta name="viewport" content="width=device-width">
<style>body{margin:0;font:700 64px -apple-system;display:grid;place-items:center;height:100vh}
#b{width:160px;height:160px;background:#e33;animation:s 1s linear infinite}
@keyframes s{to{transform:rotate(360deg)}}</style>
<div><div id="b"></div><p id="n">0</p></div>
<script>let i=0;(function f(){document.getElementById('n').textContent=++i;requestAnimationFrame(f)})()</script>
EOF
    (cd anim && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
    sleep "${ANIMATE_DELAY:-60}"
    echo "ANIMATE start $(date -u +%H:%M:%S)"
    xcrun simctl openurl "$MOBAI_SIM_UDID" http://127.0.0.1:8765/
    sleep "$ANIMATE_SECONDS"
    xcrun simctl terminate "$MOBAI_SIM_UDID" com.apple.mobilesafari
    xcrun simctl launch "$MOBAI_SIM_UDID" run.mobai.shelf
    echo "ANIMATE end $(date -u +%H:%M:%S)"
  fi
  sleep $(( ${HOLD_MINUTES:-25} * 60 - ($(date +%s) - HOLD_START) ))
  curl -s -X DELETE "$API/simulators/s1" >/dev/null
  for _ in $(seq 1 60); do [ "$(state s1)" = closed ] && break; sleep 2; done
  stop_runner
  echo "simulators left: $(xcrun simctl list devices | grep -c mobai-runner-sim)"
  exit 0
fi

# The first simulator: xcfast build, then shared.
if wait_ready s1 1200; then
  echo "STAGE s1 ready $(since "$T0") after start ($(grep -m1 'xcfast built in' runner.log))"
  mem "1 simulator"
else
  FAILED=1
fi

if [ $FAILED = 0 ]; then
  T=$(date +%s)
  curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{}' | jq -c .
  if wait_ready s2 900; then
    echo "STAGE s2 (slim auto) ready in $(since "$T")"
    mem "2 simulators"
  else FAILED=1; fi

  # A source change, then rebuilds with two simulators up: s1 compiles it,
  # s2 finds nothing new.
  touch Sources/Views.swift
  rebuild s1 || FAILED=1
  mem "after rebuild"
  rebuild s2 || FAILED=1

  T=$(date +%s)
  curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{}' | jq -c .
  if wait_ready s3 900; then
    echo "STAGE s3 (slim auto) ready in $(since "$T")"
    mem "3 simulators"
  else FAILED=1; fi

  curl -s "$API/simulators" | jq -c '.simulators[] | {id, state}'
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/simulators" -d '{}')
  echo "LIMIT a 4th simulator answers $code (409 expected while 3 run)"
  # Time to watch the three in the MobAI app.
  sleep $(( ${END_HOLD_MINUTES:-0} * 60 ))
  mem "end"

  curl -s "$API/simulators" | jq -c '.simulators[] | {id, state, slim, primary}'
fi

for id in s3 s2 s1; do
  curl -s -X DELETE "$API/simulators/$id" >/dev/null
done
for _ in $(seq 1 90); do
  [ "$(curl -s "$API/simulators" | jq '[.simulators[] | select(.state != "closed" and .state != "failed")] | length')" = 0 ] && break
  sleep 2
done
# The runner is a daemon: it stays up without simulators until stopped.
stop_runner
if kill -0 "$PID" 2>/dev/null; then
  echo "!! the runner did not exit on SIGINT"
  FAILED=1
  kill "$PID"
fi
wait "$PID"; echo "runner exit code: $?"
echo "simulators left: $(xcrun simctl list devices | grep -c mobai-runner-sim)"
echo "xcfast cache after: $(du -sh ~/.xcfast | cut -f1)"
echo "total $(since "$T0")"
echo "::group::runner log"
cat runner.log
echo "::endgroup::"
exit $FAILED
