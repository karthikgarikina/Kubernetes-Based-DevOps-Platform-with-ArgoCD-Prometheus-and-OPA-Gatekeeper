// Import tracing before any other imports
require('./tracing');

const express = require('express');
const fs = require('fs');
const path = require('path');
const winston = require('winston');
const client = require('prom-client');
const { trace } = require('@opentelemetry/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Winston JSON Logger (formatted for Grafana Loki ingestion)
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'sample-microservice-api' },
  transports: [
    new winston.transports.Console()
  ]
});

// Prometheus Metrics Setup
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ prefix: 'sample_app_' });

const httpRequestsTotal = new client.Counter({
  name: 'sample_app_http_requests_total',
  help: 'Total number of HTTP requests processed by sample app',
  labelNames: ['method', 'route', 'status']
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'sample_app_http_request_duration_seconds',
  help: 'Histogram of HTTP request durations in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2.5]
});

// Middleware for request metrics, tracing context, and logging
app.use((req, res, next) => {
  const start = Date.now();
  const currentSpan = trace.getActiveSpan();
  const spanContext = currentSpan ? currentSpan.spanContext() : null;
  const traceId = spanContext ? spanContext.traceId : 'no-trace';
  const spanId = spanContext ? spanContext.spanId : 'no-span';

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    httpRequestsTotal.inc({ method: req.method, route, status: res.statusCode });
    httpRequestDurationSeconds.observe({ method: req.method, route, status: res.statusCode }, duration);

    logger.info('Handled HTTP request', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      durationSeconds: duration,
      traceId,
      spanId
    });
  });

  next();
});

// Path where HashiCorp Vault Agent Injector writes secrets
const VAULT_SECRET_PATH = process.env.VAULT_SECRET_PATH || '/vault/secrets/database-config';

// 1. Root Service Info Endpoint
app.get('/', (req, res) => {
  let vaultSecretDetected = false;
  let secretKeys = [];

  if (fs.existsSync(VAULT_SECRET_PATH)) {
    vaultSecretDetected = true;
    try {
      const content = fs.readFileSync(VAULT_SECRET_PATH, 'utf8');
      secretKeys = content.split('\n').filter(line => line.includes('=')).map(line => line.split('=')[0]);
    } catch (e) {
      logger.error('Failed reading Vault secret file', { error: e.message });
    }
  }

  res.json({
    service: 'sample-microservice-api',
    status: 'healthy',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    vault: {
      injected: vaultSecretDetected,
      secretPath: VAULT_SECRET_PATH,
      keysFound: secretKeys
    }
  });
});

// 2. Sample Business API Endpoint with custom tracing span
app.get('/api/data', (req, res) => {
  const tracer = trace.getTracer('sample-microservice-api');
  const span = tracer.startSpan('process-business-data');

  span.setAttribute('operation.type', 'read');
  span.setAttribute('customer.tier', 'enterprise');

  // Simulated workload
  const items = [
    { id: 101, name: 'Cloud Cluster Node', status: 'ready' },
    { id: 102, name: 'ArgoCD Controller', status: 'synchronized' },
    { id: 103, name: 'Prometheus Collector', status: 'scraping' },
    { id: 104, name: 'Vault Agent Injector', status: 'active' }
  ];

  span.end();

  res.json({
    success: true,
    count: items.length,
    data: items
  });
});

// 3. Vault Secret Verification Endpoint
app.get('/secret', (req, res) => {
  if (fs.existsSync(VAULT_SECRET_PATH)) {
    try {
      const content = fs.readFileSync(VAULT_SECRET_PATH, 'utf8');
      res.json({
        status: 'success',
        source: 'HashiCorp Vault Agent Injector (In-Memory Volume)',
        filePath: VAULT_SECRET_PATH,
        content: content.trim()
      });
    } catch (err) {
      res.status(500).json({ status: 'error', error: err.message });
    }
  } else {
    res.status(404).json({
      status: 'not_found',
      message: 'Vault secret file not found at ' + VAULT_SECRET_PATH,
      note: 'Ensure Vault Agent Injector is running and Pod has proper serviceAccount'
    });
  }
});

// 4. Prometheus Metrics Endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.send(await client.register.metrics());
});

// 5. Health and Readiness Probes
app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

app.get('/readyz', (req, res) => {
  res.status(200).send('READY');
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info('Sample microservice listening on port ' + PORT);
});
