const API_BASE = "http://127.0.0.1:8081";

async function fetchJSON(endpoint) {
  try {
    const res = await fetch(`${API_BASE}/${endpoint}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    console.error(`[app.js] fetch failed for ${endpoint}:`, err);
    return [];
  }
}

function renderFindings(data) {
  const tbody = document.querySelector("#findings tbody");
  tbody.innerHTML = "";
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
  data.forEach(f => {
    tr = document.createElement("tr");
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
  data.forEach(i => {
    tr = document.createElement("tr");
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
