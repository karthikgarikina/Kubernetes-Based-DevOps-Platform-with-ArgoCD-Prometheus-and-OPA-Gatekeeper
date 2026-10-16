// tracing.js - OpenTelemetry SDK initialization for Jaeger distributed tracing
const process = require('process');
const opentelemetry = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const traceExporterEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://jaeger-collector.tracing.svc.cluster.local:4318/v1/traces';

const traceExporter = new OTLPTraceExporter({
  url: traceExporterEndpoint,
});

const sdk = new opentelemetry.NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'sample-microservice-api',
    [ATTR_SERVICE_VERSION]: '1.0.0',
    'deployment.environment': process.env.NODE_ENV || 'production',
  }),
  traceExporter,
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': { enabled: false },
  })],
});

sdk.start();
console.log('[OpenTelemetry] Distributed tracing initialized targeting: ' + traceExporterEndpoint);

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('[OpenTelemetry] Tracing terminated cleanly'))
    .catch((error) => console.error('[OpenTelemetry] Error terminating tracing', error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
