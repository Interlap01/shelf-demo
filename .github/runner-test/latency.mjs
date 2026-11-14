// How fast the screen answers a finger, as a viewer sees it: on the home
// screen, swipes left and right between its pages through the H.264 socket's
// own touch input, timing from the touch to the first changed frame, and to
// the last frame of the page's animation (no frame for 400ms).
//   node latency.mjs <label> <ws url> [swipes]
const [label, url, count = "20"] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const ws = new WebSocket(url);
ws.binaryType = "arraybuffer";
let lastFrame = 0;
let frames = [];
ws.onmessage = (e) => {
  if (typeof e.data === "string") return;
  lastFrame = performance.now();
  frames.push(lastFrame);
};
await new Promise((ok, fail) => { ws.onopen = ok; ws.onerror = () => fail(new Error("cannot open " + url)); });
const send = (m) => ws.send(JSON.stringify(m));

// To the home screen, and let it settle.
send({ type: "button", button: "home", down: true });
await sleep(80);
send({ type: "button", button: "home", down: false });
await sleep(3000);

const first = [], settle = [];
for (let i = 0; i < Number(count); i++) {
  const [from, to] = i % 2 === 0 ? [0.85, 0.15] : [0.15, 0.85];
  frames = [];
  const t0 = performance.now();
  send({ type: "touch", phase: "down", x: from, y: 0.45 });
  for (let s = 1; s <= 8; s++) {
    await sleep(16);
    send({ type: "touch", phase: "move", x: from + (to - from) * s / 8, y: 0.45 });
  }
  send({ type: "touch", phase: "up", x: to, y: 0.45 });
  // Wait for the animation to end: 400ms without a frame, at most 5s.
  while (performance.now() - t0 < 5000) {
    await sleep(50);
    if (frames.length && performance.now() - lastFrame > 400) break;
  }
  if (!frames.length) { console.log(`LAT ${label} swipe ${i}: no frame in 5s`); continue; }
  first.push(frames[0] - t0);
  settle.push(frames[frames.length - 1] - t0);
  console.log(`LAT ${label} swipe ${i}: first frame ${Math.round(frames[0] - t0)}ms, last ${Math.round(frames[frames.length - 1] - t0)}ms, ${frames.length} frames`);
  await sleep(600);
}
const med = (a) => { const s = [...a].sort((x, y) => x - y); return Math.round(s[Math.floor(s.length / 2)] ?? -1); };
const p90 = (a) => { const s = [...a].sort((x, y) => x - y); return Math.round(s[Math.floor(s.length * 0.9)] ?? -1); };
console.log(`LATSUM ${label}: first frame median ${med(first)}ms p90 ${p90(first)}ms; animation done median ${med(settle)}ms p90 ${p90(settle)}ms (${first.length}/${count} swipes)`);
ws.close();
process.exit(0);
