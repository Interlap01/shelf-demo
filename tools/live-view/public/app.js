const sourcesEl = document.getElementById("sources");
const frameEl = document.getElementById("frame");
const emptyEl = document.getElementById("empty");
const metaText = document.getElementById("metaText");
const liveDot = document.getElementById("liveDot");
const hintEl = document.getElementById("hint");
const intervalEl = document.getElementById("interval");

let lastSeq = -1;
let selectedId = null;

function fmtAgo(iso) {
  if (!iso) return "never";
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 2000) return "just now";
  if (ms < 60000) return `${Math.round(ms / 1000)}s ago`;
  return `${Math.round(ms / 60000)}m ago`;
}

function renderSources(sources, sourceId) {
  selectedId = sourceId;
  sourcesEl.innerHTML = "";
  if (!sources.length) {
    sourcesEl.innerHTML = `<li class="detail" style="padding:0.5rem;color:var(--muted)">No sources yet.</li>`;
    return;
  }
  for (const src of sources) {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "source";
    btn.setAttribute("aria-pressed", src.id === sourceId ? "true" : "false");
    const badgeClass = src.available ? "live" : "down";
    const badgeText =
      src.kind === "preview"
        ? src.available
          ? "preview"
          : "offline"
        : src.available
          ? src.detail?.includes("simulator")
            ? "simulator"
            : "device"
          : "offline";
    btn.innerHTML = `
      <span class="name">${escapeHtml(src.label)}</span>
      <span class="detail">${escapeHtml(src.detail || src.id)}</span>
      <span class="badge ${badgeClass}">${badgeText}</span>
    `;
    btn.addEventListener("click", () => selectSource(src.id));
    li.appendChild(btn);
    sourcesEl.appendChild(li);
  }
}

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function selectSource(sourceId) {
  const intervalMs = Number(intervalEl.value);
  await fetch("/api/select", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sourceId, intervalMs }),
  });
  await tick();
}

async function refreshSources() {
  const res = await fetch("/api/sources");
  const data = await res.json();
  renderSources(data.sources || [], data.sourceId);
}

async function snapNow() {
  liveDot.dataset.state = "busy";
  metaText.textContent = "Capturing…";
  await fetch("/api/capture", { method: "POST" });
  await tick();
}

async function tick() {
  try {
    const res = await fetch("/api/status");
    const data = await res.json();
    renderSources(data.sources || [], data.sourceId);

    if (String(intervalEl.value) !== String(data.intervalMs)) {
      // keep user choice unless server drifted oddly
    }

    if (data.hasFrame && data.frameSeq !== lastSeq) {
      lastSeq = data.frameSeq;
      const url = `/api/frame?seq=${data.frameSeq}&t=${Date.now()}`;
      const img = new Image();
      img.onload = () => {
        frameEl.src = url;
        frameEl.hidden = false;
        emptyEl.hidden = true;
      };
      img.src = url;
    }

    if (data.capturing) {
      liveDot.dataset.state = "busy";
    } else if (data.lastError) {
      liveDot.dataset.state = "err";
    } else if (data.hasFrame) {
      liveDot.dataset.state = "ok";
    } else {
      liveDot.dataset.state = "idle";
    }

    const parts = [];
    if (data.capturing) parts.push("capturing");
    else if (data.lastOkAt) parts.push(`updated ${fmtAgo(data.lastOkAt)}`);
    if (data.lastMs != null) parts.push(`${data.lastMs}ms`);
    if (data.frameSeq) parts.push(`#${data.frameSeq}`);
    metaText.textContent = parts.join(" · ") || "Waiting…";

    if (data.lastError) {
      hintEl.textContent = data.lastError;
      hintEl.classList.add("error");
    } else {
      const src = (data.sources || []).find((s) => s.id === data.sourceId);
      hintEl.classList.remove("error");
      hintEl.textContent = src
        ? `Watching ${src.label}. Open this page from Forwarded Ports for a sidebar preview.`
        : "";
    }
  } catch (err) {
    liveDot.dataset.state = "err";
    metaText.textContent = "Server unreachable";
    hintEl.textContent = String(err.message || err);
    hintEl.classList.add("error");
  }
}

document.getElementById("refreshSources").addEventListener("click", () => {
  refreshSources().catch(console.error);
});
document.getElementById("snapNow").addEventListener("click", () => {
  snapNow().catch(console.error);
});
intervalEl.addEventListener("change", () => {
  selectSource(selectedId || "preview").catch(console.error);
});

tick();
setInterval(tick, 700);
