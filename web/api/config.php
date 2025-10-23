<?php
// Load environment variables (if using dotenv loader, otherwise set via server)
$host     = getenv('PGHOST') ?: '127.0.0.1';
$port     = getenv('PGPORT') ?: '5432';
$dbname   = getenv('PGDATABASE') ?: 'ulinzi';
$user     = getenv('PGUSER') ?: 'ulinzi';
$password = getenv('PGPASSWORD') ?: 'ulinzi';

// Build DSN
$dsn = "pgsql:host=$host;port=$port;dbname=$dbname";

try {
  $pdo = new PDO($dsn, $user, $password, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
  ]);
} catch (PDOException $e) {
  http_response_code(500);
  echo json_encode(['error' => 'Database connection failed']);
  exit;
}

// Force JSON output
header('Content-Type: application/json');
