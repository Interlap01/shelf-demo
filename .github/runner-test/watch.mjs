// Watches one simulator's screen the way the MobAI app would and prints the
// frames that arrived every 5s:
//   node watch.mjs mjpeg <label> http://127.0.0.1:<port>/?fps=30&scale=50&quality=50
//   node watch.mjs h264  <label> ws://127.0.0.1:7101/simulators/<id>/screen/ws
const [mode, label, url] = process.argv.slice(2);
let frames = 0;
let bytes = 0;
setInterval(() => {
  console.log(`FPS ${label} ${new Date().toISOString().slice(11, 19)} ${(frames / 5).toFixed(1)} fps ${(bytes * 8 / 5000).toFixed(0)} kbit/s`);
  frames = 0;
  bytes = 0;
}, 5000);

if (mode === 'mjpeg') {
  const res = await fetch(url);
  let tail = new Uint8Array(0);
  for await (const chunk of res.body) {
    bytes += chunk.length;
    // A JPEG starts FF D8 FF; keep two bytes so a marker split across chunks counts.
    const buf = new Uint8Array(tail.length + chunk.length);
    buf.set(tail);
    buf.set(chunk, tail.length);
    for (let i = 0; i + 2 < buf.length; i++) {
      if (buf[i] === 0xff && buf[i + 1] === 0xd8 && buf[i + 2] === 0xff) frames++;
    }
    tail = buf.slice(-2);
  }
  console.log(`FPS ${label} stream ended`);
} else {
  const ws = new WebSocket(url);
  ws.binaryType = 'arraybuffer';
  ws.onmessage = (e) => {
    if (typeof e.data !== 'string') {
      frames++;
      bytes += e.data.byteLength;
    }
  };
  ws.onclose = () => console.log(`FPS ${label} stream ended`);
}
