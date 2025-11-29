// Resolve API base dynamically: prefer same-origin /api, fallback to localhost:8081
const API_CANDIDATES = [
  `${window.location.origin}/api`,
  'http://127.0.0.1:8081'
];

async function fetchJSON(endpoint) {
  for (const base of API_CANDIDATES) {
    try {
      const res = await fetch(`${base}/${endpoint}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (err) {
      console.warn(`[app.js] fetch failed for ${base}/${endpoint}:`, err);
      // try next candidate
    }
  }
  console.error(`[app.js] all API bases failed for ${endpoint}`);
  return [];
}

function renderFindings(data) {
  const tbody = document.querySelector("#findings tbody");
  tbody.innerHTML = "";
  if (!Array.isArray(data) || data.length === 0) {
    const tr = document.createElement("tr");
    tr.innerHTML = '<td colspan="3" style="text-align:center;color:#777;">No findings yet</td>';
    tbody.appendChild(tr);
    return;
  }
  data.forEach(f => {
    const tr = document.createElement("tr");
    const sevClass = `severity-${f.severity}`;
    tr.innerHTML = `
      <td>${f.title}</td>
      <td class="${sevClass}">${f.severity}</td>
      <td>${new Date(f.created_at).toLocaleString()}</td>
    `;
    tbody.appendChild(tr);
  });
}

function renderFlows(data) {
  const tbody = document.querySelector("#flows tbody");
  tbody.innerHTML = "";
  if (!Array.isArray(data) || data.length === 0) {
    const tr = document.createElement("tr");
    tr.innerHTML = '<td colspan="6" style="text-align:center;color:#777;">No flows yet</td>';
    tbody.appendChild(tr);
    return;
  }
  data.forEach(f => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${f.hostname}</td>
      <td>${f.src_ip}</td>
      <td>${f.dst_ip}</td>
      <td>${f.dst_port}</td>
      <td>${f.protocol}</td>
      <td>${new Date(f.ts).toLocaleString()}</td>
    `;
    tbody.appendChild(tr);
  });
}

function renderIndicators(data) {
  const tbody = document.querySelector("#indicators tbody");
  tbody.innerHTML = "";
  if (!Array.isArray(data) || data.length === 0) {
    const tr = document.createElement("tr");
    tr.innerHTML = '<td colspan="4" style="text-align:center;color:#777;">No indicators yet</td>';
    tbody.appendChild(tr);
    return;
  }
  data.forEach(i => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${i.type}</td>
      <td>${i.value}</td>
      <td>${i.confidence}</td>
      <td>${new Date(i.last_seen).toLocaleString()}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function refreshAll() {
  const [findings, flows, indicators] = await Promise.all([
    fetchJSON("findings"),
    fetchJSON("flows"),
    fetchJSON("indicators")
  ]);
  renderFindings(findings);
  renderFlows(flows);
  renderIndicators(indicators);
}

refreshAll();
setInterval(refreshAll, 5000);
