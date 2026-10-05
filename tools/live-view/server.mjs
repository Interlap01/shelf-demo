#!/usr/bin/env node
/**
 * Live View — poll MobAI preview / device screenshots and serve them in a browser.
 *
 *   node tools/live-view/server.mjs
 *   open http://127.0.0.1:4747
 */
import http from "node:http";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import os from "node:os";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(__dirname, "public");
const PORT = Number(process.env.LIVE_VIEW_PORT || 4747);
const HOST = process.env.LIVE_VIEW_HOST || "127.0.0.1";
const PROJECT = process.env.LIVE_VIEW_PROJECT || path.resolve(__dirname, "../..");
const CACHE = path.join(os.tmpdir(), "mobai-live-view");
const MOBAI_BIN = process.env.MOBAI_BIN || path.join(os.homedir(), ".mobai/bin");

fs.mkdirSync(CACHE, { recursive: true });

const state = {
  sourceId: "preview",
  intervalMs: Number(process.env.LIVE_VIEW_INTERVAL_MS || 1500),
  capturing: false,
  lastOkAt: null,
  lastError: null,
  lastMs: null,
  framePath: null,
  frameBytes: 0,
  frameSeq: 0,
  sources: [],
};

function envPath() {
  const extra = MOBAI_BIN;
  const current = process.env.PATH || "";
  return current.includes(extra) ? current : `${extra}${path.delimiter}${current}`;
}

function run(cmd, args, { cwd = PROJECT, timeoutMs = 45000 } = {}) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, {
      cwd,
      env: { ...process.env, PATH: envPath() },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      resolve({ code: 124, stdout, stderr: stderr + "\ntimeout" });
    }, timeoutMs);
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? 1, stdout, stderr });
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({ code: 127, stdout, stderr: String(err.message || err) });
    });
  });
}

function parseJsonLoose(text) {
  const t = (text || "").trim();
  if (!t) return null;
  try {
    return JSON.parse(t);
  } catch {
    const start = t.indexOf("{");
    const startArr = t.indexOf("[");
    let i = -1;
    if (start >= 0 && (startArr < 0 || start < startArr)) i = start;
    else if (startArr >= 0) i = startArr;
    if (i < 0) return null;
    try {
      return JSON.parse(t.slice(i));
    } catch {
      return null;
    }
  }
}

async function listDevices() {
  const r = await run("mobai", ["devices", "list", "--json"], { timeoutMs: 15000 });
  const data = parseJsonLoose(r.stdout) ?? parseJsonLoose(r.stderr);
  if (!Array.isArray(data)) return [];
  return data.map((d) => ({
    id: `device:${d.id}`,
    kind: "device",
    deviceId: d.id,
    label: d.name || d.model || d.id,
    detail: [d.platform, d.osVersion, d.virtual ? "simulator" : "physical"]
      .filter(Boolean)
      .join(" · "),
    bridgeRunning: !!d.bridgeRunning,
    available: true,
  }));
}

async function previewStatus() {
  const r = await run("mobai-dev", ["preview", "info", "--json"], {
    cwd: PROJECT,
    timeoutMs: 10000,
  });
  const data = parseJsonLoose(r.stdout) ?? parseJsonLoose(r.stderr) ?? {};
  const running = data.ok === true || data.running === true || !!data.port;
  return {
    id: "preview",
    kind: "preview",
    label: "MobAI Preview",
    detail: running
      ? `engine on :${data.port ?? "?"}`
      : data.message || "not running — mobai-dev preview run --detach",
    available: running,
    raw: data,
  };
}

async function refreshSources() {
  const [preview, devices] = await Promise.all([previewStatus(), listDevices()]);
  state.sources = [preview, ...devices];
  if (!state.sources.some((s) => s.id === state.sourceId)) {
    const firstLive = state.sources.find((s) => s.available) || state.sources[0];
    if (firstLive) state.sourceId = firstLive.id;
  }
  return state.sources;
}

function currentSource() {
  return state.sources.find((s) => s.id === state.sourceId) || null;
}

async function capturePreview(outFile) {
  const r = await run(
    "mobai-dev",
    ["preview", "screenshot", "--out", outFile, "--json"],
    { cwd: PROJECT, timeoutMs: 30000 }
  );
  const data = parseJsonLoose(r.stdout) ?? parseJsonLoose(r.stderr);
  if (r.code !== 0 || (data && data.ok === false)) {
    const msg =
      data?.message || data?.suggestion || r.stderr.trim() || r.stdout.trim() || `exit ${r.code}`;
    throw new Error(msg);
  }
  if (!fs.existsSync(outFile)) {
    const alt = data?.path || data?.out || data?.screenshot_path;
    if (alt && fs.existsSync(alt)) fs.copyFileSync(alt, outFile);
  }
  if (!fs.existsSync(outFile)) throw new Error("preview screenshot produced no file");
}

async function captureDevice(deviceId, outFile) {
  const dir = path.dirname(outFile);
  const name = path.basename(outFile, path.extname(outFile));
  const r = await run(
    "mobai",
    ["screenshot", "--path", dir, "--name", name, "--full", "-d", deviceId, "--json"],
    { timeoutMs: 45000 }
  );
  const data = parseJsonLoose(r.stdout) ?? parseJsonLoose(r.stderr);
  if (r.code !== 0 || (data && data.success === false)) {
    const msg =
      data?.error ||
      data?.message ||
      r.stderr.trim() ||
      r.stdout.trim() ||
      `exit ${r.code}`;
    throw new Error(typeof msg === "string" ? msg : JSON.stringify(msg));
  }
  // CLI may write .png even when we asked for name without extension
  const candidates = [
    outFile,
    path.join(dir, `${name}.png`),
    path.join(dir, `${name}.jpg`),
    path.join(dir, `${name}.jpeg`),
    data?.screenshot_path,
    data?.path,
    data?.result?.screenshot_path,
  ].filter(Boolean);
  const found = candidates.find((p) => fs.existsSync(p));
  if (!found) throw new Error("device screenshot produced no file");
  if (found !== outFile) fs.copyFileSync(found, outFile);
}

async function captureOnce() {
  if (state.capturing) return;
  state.capturing = true;
  const started = Date.now();
  try {
    await refreshSources();
    const src = currentSource();
    if (!src) throw new Error("no sources");
    const outFile = path.join(CACHE, `frame-${src.id.replace(/[^a-zA-Z0-9_-]/g, "_")}.png`);
    if (src.kind === "preview") {
      await capturePreview(outFile);
    } else if (src.kind === "device") {
      await captureDevice(src.deviceId, outFile);
    } else {
      throw new Error(`unknown source kind ${src.kind}`);
    }
    const stat = fs.statSync(outFile);
    state.framePath = outFile;
    state.frameBytes = stat.size;
    state.frameSeq += 1;
    state.lastOkAt = new Date().toISOString();
    state.lastError = null;
    state.lastMs = Date.now() - started;
  } catch (err) {
    state.lastError = String(err.message || err);
    state.lastMs = Date.now() - started;
  } finally {
    state.capturing = false;
  }
}

let timer = null;
function schedule() {
  if (timer) clearInterval(timer);
  timer = setInterval(() => {
    captureOnce().catch(() => {});
  }, Math.max(400, state.intervalMs));
}

function sendJson(res, code, body) {
  const payload = JSON.stringify(body);
  res.writeHead(code, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(payload);
}

function contentType(file) {
  if (file.endsWith(".html")) return "text/html; charset=utf-8";
  if (file.endsWith(".css")) return "text/css; charset=utf-8";
  if (file.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (file.endsWith(".png")) return "image/png";
  if (file.endsWith(".svg")) return "image/svg+xml";
  return "application/octet-stream";
}

function serveStatic(req, res) {
  let urlPath = decodeURIComponent(new URL(req.url, `http://${HOST}`).pathname);
  if (urlPath === "/") urlPath = "/index.html";
  const file = path.normalize(path.join(PUBLIC, urlPath));
  if (!file.startsWith(PUBLIC)) {
    res.writeHead(403).end("forbidden");
    return;
  }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404).end("not found");
    return;
  }
  res.writeHead(200, {
    "Content-Type": contentType(file),
    "Cache-Control": urlPath === "/index.html" ? "no-store" : "public, max-age=60",
  });
  fs.createReadStream(file).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);

  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  if (url.pathname === "/api/status" && req.method === "GET") {
    sendJson(res, 200, {
      sourceId: state.sourceId,
      intervalMs: state.intervalMs,
      capturing: state.capturing,
      lastOkAt: state.lastOkAt,
      lastError: state.lastError,
      lastMs: state.lastMs,
      frameSeq: state.frameSeq,
      frameBytes: state.frameBytes,
      hasFrame: !!state.framePath && fs.existsSync(state.framePath),
      sources: state.sources,
      project: PROJECT,
    });
    return;
  }

  if (url.pathname === "/api/sources" && req.method === "GET") {
    try {
      await refreshSources();
      sendJson(res, 200, { sources: state.sources, sourceId: state.sourceId });
    } catch (err) {
      sendJson(res, 500, { error: String(err.message || err) });
    }
    return;
  }

  if (url.pathname === "/api/select" && req.method === "POST") {
    let body = "";
    for await (const chunk of req) body += chunk;
    try {
      const data = JSON.parse(body || "{}");
      if (data.sourceId) state.sourceId = String(data.sourceId);
      if (data.intervalMs != null) {
        state.intervalMs = Math.max(400, Number(data.intervalMs) || 1500);
        schedule();
      }
      state.lastError = null;
      captureOnce().catch(() => {});
      sendJson(res, 200, {
        ok: true,
        sourceId: state.sourceId,
        intervalMs: state.intervalMs,
      });
    } catch (err) {
      sendJson(res, 400, { error: String(err.message || err) });
    }
    return;
  }

  if (url.pathname === "/api/capture" && req.method === "POST") {
    await captureOnce();
    sendJson(res, state.lastError ? 502 : 200, {
      ok: !state.lastError,
      error: state.lastError,
      frameSeq: state.frameSeq,
      lastMs: state.lastMs,
    });
    return;
  }

  if (url.pathname === "/api/frame" && req.method === "GET") {
    if (!state.framePath || !fs.existsSync(state.framePath)) {
      res.writeHead(404, { "Cache-Control": "no-store" }).end("no frame yet");
      return;
    }
    res.writeHead(200, {
      "Content-Type": "image/png",
      "Cache-Control": "no-store, no-cache, must-revalidate",
      "X-Frame-Seq": String(state.frameSeq),
    });
    fs.createReadStream(state.framePath).pipe(res);
    return;
  }

  serveStatic(req, res);
});

await refreshSources().catch(() => {});
schedule();
captureOnce().catch(() => {});

server.listen(PORT, HOST, () => {
  console.log(`Live View  http://${HOST}:${PORT}`);
  console.log(`Project    ${PROJECT}`);
  console.log(`Polling    every ${state.intervalMs}ms`);
  console.log(`Sources    preview + mobai devices via CLI`);
});
