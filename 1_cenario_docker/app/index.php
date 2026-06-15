<?php

require_once __DIR__ . '/repositories/Database.php';
require_once __DIR__ . '/repositories/ClientRepository.php';

$method = $_SERVER['REQUEST_METHOD'];
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Normalize paths when nginx internally redirects to /index.php
if (strpos($uri, '/index.php') === 0) {
    $uri = substr($uri, strlen('/index.php'));
    if ($uri === '') {
        $uri = '/';
    }
}

if ($uri === '/health') {
    echo json_encode([
        'status' => 'ok',
        'service' => 'tcc-kubernetes-app',
        'hostname' => gethostname(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);

    exit;
}

if ($method === 'GET' && $uri === '/clients') {
    $repository = new ClientRepository();
    $clients = $repository->list();

    echo json_encode([
        'status' => 'success',
        'data' => $clients
    ]);

    exit;
}

if ($method === 'GET' && $uri === '/client') {
    $id = $_GET['id'] ?? null;

    if (!$id) {
        http_response_code(400);

        echo json_encode([
            'status' => 'error',
            'message' => 'ID do cliente não informado'
        ]);

        exit;
    }

    $repository = new ClientRepository();
    $client = $repository->findById((int) $id);

    echo json_encode([
        'status' => 'success',
        'data' => $client
    ]);

    exit;
}

http_response_code(404);

echo json_encode([
    'error' => 'Rota não encontrada',
    'uri' => $uri
]);