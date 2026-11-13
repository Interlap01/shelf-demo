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
    tar czf snaps.tgz snaps
    gh release upload runner-test snaps.tgz --clobber -R "$GITHUB_REPOSITORY" >/dev/null 2>&1
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
./bin/mobai-ci runner --xcfast "$PWD/bin/xcfast" --device "$MOBAI_SIM_UDID" --wait-device 4m \
  --duration 45m --max-duration 50m --max-simulators 3 \
  --label "${GITHUB_REPOSITORY} runner test" 2>&1 \
  | while IFS= read -r l; do echo "$(date -u +%H:%M:%S) $l"; done | tee runner.log | sed 's/^/RUNNER /' &
PID=$!
trap 'echo "::group::runner log"; cat runner.log; echo "::endgroup::"; echo "::group::tunnel log"; cat "${TMPDIR:-/tmp}"/mobai-ci-tunnel-*.log; echo "::endgroup::"' EXIT

# HOLD: only the first simulator, kept up for someone to watch.
if [ "${HOLD:-}" = 1 ]; then
  wait_ready s1 1200 && echo "STAGE s1 ready $(since "$T0") after start"
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
  for _ in $(seq 1 60); do kill -0 "$PID" 2>/dev/null || break; sleep 2; done
  # OCR_CHECK: text drawn on a canvas is not in the accessibility tree, so
  # tapping it goes through OCR. Once as this runner (github-hosted: text only,
  # no icon scan) and once claiming self-hosted (icons scanned on this Mac),
  # with the CPU each mobai-ci test used.
  if [ "${OCR_CHECK:-0}" = 1 ]; then
    echo "RUNNER_ENVIRONMENT=${RUNNER_ENVIRONMENT:-unset}"
    mkdir -p anim ocrcheck
    cat > anim/ocr.html <<'EOF'
<meta name="viewport" content="width=device-width">
<body style="margin:0"><canvas id="c" width="390" height="700"></canvas>
<script>const g=document.getElementById('c').getContext('2d');g.fillStyle='#fff';g.fillRect(0,0,390,700);
g.fillStyle='#000';g.font='bold 40px -apple-system';g.fillText('OCRCHECK',90,300);</script>
EOF
    pgrep -f "http.server 8765" >/dev/null || (cd anim && python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1 &)
    printf '# Canvas text, found only through OCR\ntap "OCRCHECK"\n' > ocrcheck/ocr-check.mob
    for envname in github-hosted self-hosted; do
      xcrun simctl openurl "$MOBAI_SIM_UDID" http://127.0.0.1:8765/ocr.html
      sleep 5
      echo "::group::OCR check as $envname"
      RUNNER_ENVIRONMENT=$envname /usr/bin/time -l ./bin/mobai-ci test ocrcheck --root . --device "$MOBAI_SIM_UDID" --timeout 4m 2>&1 \
        | grep -E "pass|fail|PASS|FAIL|OCR|ocr|real|user|sys|maximum resident|error" | head -20
      echo "::endgroup::"
    done
  fi
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
  kill -0 "$PID" 2>/dev/null || break
  sleep 2
done
if kill -0 "$PID" 2>/dev/null; then
  echo "!! the runner did not exit after every simulator closed"
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
