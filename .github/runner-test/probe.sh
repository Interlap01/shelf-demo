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

# --duration is long so no simulator closes for being unused mid-test.
./bin/mobai-ci runner --xcfast "$PWD/bin/xcfast" --device "$MOBAI_SIM_UDID" --wait-device 4m \
  --duration 45m --max-duration 50m --max-simulators 3 \
  --label "${GITHUB_REPOSITORY} runner test" > runner.log 2>&1 &
PID=$!
trap 'echo "::group::runner log"; cat runner.log; echo "::endgroup::"' EXIT

# The first simulator: xcfast build, then shared.
if wait_ready s1 1200; then
  echo "STAGE s1 ready $(since "$T0") after start ($(grep -m1 'xcfast built in' runner.log))"
  mem "1 simulator"
else
  FAILED=1
fi

if [ $FAILED = 0 ]; then
  T=$(date +%s)
  curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{"slim":"auto"}' | jq -c .
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
  curl -s -X POST "$API/simulators" -H 'Content-Type: application/json' -d '{"slim":"stock"}' | jq -c .
  if wait_ready s3 900; then
    echo "STAGE s3 (stock) ready in $(since "$T")"
    mem "3 simulators"
  else FAILED=1; fi

  curl -s "$API/simulators" | jq -c '.simulators[] | {id, state}'
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/simulators" -d '{}')
  echo "LIMIT a 4th simulator answers $code (409 expected while 3 run)"

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
