// One swipe up through the H.264 socket's touch input, as a viewer's finger:
//   node edge.mjs <ws url> <startY> <ms to the top> <ms held before lifting>
// startY 0.99 starts in the home indicator's strip, 0.9 in the app.
const [url, startY, travel, hold] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ws = new WebSocket(url);
await new Promise((ok, fail) => { ws.onopen = ok; ws.onerror = () => fail(new Error("cannot open " + url)); });
const send = (m) => ws.send(JSON.stringify(m));
const y0 = Number(startY), y1 = 0.55, steps = 12;
send({ type: "touch", phase: "down", x: 0.5, y: y0 });
for (let s = 1; s <= steps; s++) {
  await sleep(Number(travel) / steps);
  send({ type: "touch", phase: "move", x: 0.5, y: y0 + (y1 - y0) * s / steps });
}
for (let t = 0; t < Number(hold); t += 50) {
  await sleep(50);
  send({ type: "touch", phase: "move", x: 0.5, y: y1 });
}
send({ type: "touch", phase: "up", x: 0.5, y: y1 });
await sleep(300);
ws.close();
