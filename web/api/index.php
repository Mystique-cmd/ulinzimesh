<?php
require_once __DIR__ . '/config.php';

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
// Normalize path: remove trailing slash and optional /api prefix
$path = rtrim($path, '/');
if ($path === '') { $path = '/'; }
if (strpos($path, '/api/') === 0) {
  $path = substr($path, 4);
}

// --- /findings ---
if ($path === '/findings') {
  if ($pdo === null) { echo json_encode([]); exit; }
  $stmt = $pdo->query("
    SELECT finding_id, title, description, severity, created_at
    FROM findings
    ORDER BY created_at DESC
    LIMIT 100
  ");
  echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
  exit;
}

// --- /flows ---
if ($path === '/flows') {
  if ($pdo === null) { echo json_encode([]); exit; }
  $stmt = $pdo->query("
    SELECT f.ts, f.src_ip, f.dst_ip, f.dst_port, f.protocol, h.hostname
    FROM network_flows f
    JOIN hosts h ON f.host_id = h.host_id
    ORDER BY f.ts DESC
    LIMIT 100
  ");
  echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
  exit;
}

// --- /indicators ---
if ($path === '/indicators') {
  if ($pdo === null) { echo json_encode([]); exit; }
  $stmt = $pdo->query("
    SELECT type, value, confidence, last_seen
    FROM indicators
    ORDER BY last_seen DESC
    LIMIT 100
  ");
  echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
  exit;
}

// --- Default: 404 ---
http_response_code(404);
echo json_encode(['error' => 'Not found']);
