const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const winston = require("winston");
const DailyRotateFile = require("winston-daily-rotate-file");
const responseTime = require("response-time");
const rateLimit = require("express-rate-limit");
const promClient = require("prom-client");
const jwt = require("jsonwebtoken");
const fs = require("fs");
const path = require("path");

const app = express();

// JWT Secret (production'da environment variable kullan)
const JWT_SECRET = process.env.JWT_SECRET || "prod-monitoring-secret-change-in-production";

// API Users (production'da database kullan)
const API_USERS = {
  "admin": { role: "admin", token: "admin-token-123" },
  "developer": { role: "developer", token: "dev-token-456" },
  "readonly": { role: "readonly", token: "readonly-token-789" }
};

// Log dizinini oluştur
const logDir = "/home/emrecan/home/prod-monitoring/data";
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

// Winston logger yapılandırması
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: process.env.INSTANCE_NAME || "backend" },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(
          ({ timestamp, level, message, service, ...meta }) =>
            `${timestamp} [${service}] ${level}: ${message} ${
              Object.keys(meta).length ? JSON.stringify(meta) : ""
            }`
        )
      ),
    }),
    new DailyRotateFile({
      filename: path.join(logDir, "app-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxFiles: "7d",
      maxSize: "10m",
      format: winston.format.json(),
    }),
    new DailyRotateFile({
      filename: path.join(logDir, "error-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      level: "error",
      maxFiles: "14d",
      maxSize: "10m",
    }),
  ],
});

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const httpErrorsTotal = new promClient.Counter({
  name: 'http_errors_total',
  help: 'Total number of HTTP errors',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active connections'
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(httpErrorsTotal);
register.registerMetric(activeConnections);

// Application metrics tracking
let appMetrics = {
  totalRequests: 0,
  errorCount: 0,
  totalResponseTime: 0,
  requestsPerMinute: 0,
  errorRate: 0,
  avgResponseTime: 0,
  lastMinuteRequests: []
};

// Rate limiting
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 500, // limit each IP to 500 requests per minute (for dashboard auto-refresh)
  message: "Too many requests from this IP, please try again later."
});

app.use(limiter);

// CORS configuration for dashboard
app.use(cors({
  origin: ['http://localhost:8000', 'http://localhost:8080', 'http://127.0.0.1:8000', 'http://127.0.0.1:8080'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'X-API-Token', 'Authorization'],
  credentials: true
}));

app.use(express.json());

// Response time tracking
app.use(responseTime((req, res, time) => {
  const route = req.route ? req.route.path : req.path;
  
  // Prometheus metrics
  httpRequestDuration.labels(req.method, route, res.statusCode).observe(time / 1000);
  httpRequestTotal.labels(req.method, route, res.statusCode).inc();
  
  if (res.statusCode >= 400) {
    httpErrorsTotal.labels(req.method, route, res.statusCode).inc();
  }
  
  // Application metrics
  appMetrics.totalRequests++;
  appMetrics.totalResponseTime += time;
  appMetrics.avgResponseTime = appMetrics.totalResponseTime / appMetrics.totalRequests;
  
  if (res.statusCode >= 400) {
    appMetrics.errorCount++;
  }
  
  appMetrics.errorRate = (appMetrics.errorCount / appMetrics.totalRequests) * 100;
  
  // Track requests per minute
  const now = Date.now();
  appMetrics.lastMinuteRequests.push(now);
  appMetrics.lastMinuteRequests = appMetrics.lastMinuteRequests.filter(t => now - t < 60000);
  appMetrics.requestsPerMinute = appMetrics.lastMinuteRequests.length;
}));

// Morgan HTTP logging
app.use(
  morgan("combined", {
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

// Audit logging middleware
const auditLog = (req, res, next) => {
  const auditEntry = {
    timestamp: new Date().toISOString(),
    user: req.user || "anonymous",
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('user-agent')
  };
  
  fs.appendFileSync(
    path.join(logDir, "audit.log"),
    JSON.stringify(auditEntry) + "\n"
  );
  
  next();
};

app.use(auditLog);

// Authentication middleware
const authenticate = (req, res, next) => {
  const token = req.headers['x-api-token'];
  
  if (!token) {
    return res.status(401).json({ error: "No API token provided" });
  }
  
  // Find user by token
  const user = Object.entries(API_USERS).find(([_, u]) => u.token === token);
  
  if (!user) {
    return res.status(401).json({ error: "Invalid API token" });
  }
  
  req.user = { username: user[0], role: user[1].role };
  next();
};

// Role-based access control
const requireRole = (roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }
    next();
  };
};

// Connection tracking
app.use((req, res, next) => {
  activeConnections.inc();
  res.on('finish', () => {
    activeConnections.dec();
  });
  next();
});

// Public endpoints (no auth required)

// Health endpoint
app.get("/health", (req, res) => {
  const healthData = {
    instance: process.env.INSTANCE_NAME,
    status: "OK",
    time: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  };
  
  logger.info("Health check", healthData);
  res.json(healthData);
});

// Prometheus metrics endpoint
app.get("/metrics/prometheus", async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Protected endpoints (require authentication)

// Application metrics
app.get("/metrics/application", authenticate, (req, res) => {
  res.json({
    ...appMetrics,
    timestamp: new Date().toISOString(),
    instance: process.env.INSTANCE_NAME
  });
});

// System metrics
app.get("/metrics", authenticate, (req, res) => {
  try {
    const metricsFile = path.join(logDir, "metrics.json");
    if (fs.existsSync(metricsFile)) {
      const metrics = fs.readFileSync(metricsFile, "utf8")
        .trim()
        .split("\n")
        .filter(line => line)
        .slice(-100)
        .map(line => JSON.parse(line));
      
      res.json({ metrics, count: metrics.length });
    } else {
      res.json({ metrics: [], count: 0 });
    }
  } catch (error) {
    logger.error("Error reading metrics", { error: error.message });
    res.status(500).json({ error: "Failed to read metrics" });
  }
});

// Process health
app.get("/health/processes", authenticate, (req, res) => {
  try {
    const healthFile = path.join(logDir, "process_health.json");
    if (fs.existsSync(healthFile)) {
      // Remove all newlines and extra whitespace, keep only single spaces
      let rawData = fs.readFileSync(healthFile, "utf8");
      // Remove newlines within JSON strings
      rawData = rawData.split('\n').map(line => line.trim()).join('');
      const health = JSON.parse(rawData);
      res.json(health);
    } else {
      res.json({ error: "Health data not available" });
    }
  } catch (error) {
    logger.error("Error reading process health", { error: error.message, stack: error.stack });
    res.status(500).json({ error: "Failed to read process health" });
  }
});

// Alerts
app.get("/alerts", authenticate, (req, res) => {
  try {
    const alertsFile = path.join(logDir, "alerts.log");
    if (fs.existsSync(alertsFile)) {
      const alerts = fs.readFileSync(alertsFile, "utf8")
        .trim()
        .split("\n")
        .filter(line => line)
        .slice(-50);
      
      res.json({ alerts, count: alerts.length });
    } else {
      res.json({ alerts: [], count: 0 });
    }
  } catch (error) {
    logger.error("Error reading alerts", { error: error.message });
    res.status(500).json({ error: "Failed to read alerts" });
  }
});

// Security logs
app.get("/security", authenticate, (req, res) => {
  try {
    const securityFile = path.join(logDir, "security.log");
    if (fs.existsSync(securityFile)) {
      const logs = fs.readFileSync(securityFile, "utf8")
        .trim()
        .split("\n")
        .filter(line => line)
        .slice(-50);
      
      res.json({ logs, count: logs.length });
    } else {
      res.json({ logs: [], count: 0 });
    }
  } catch (error) {
    logger.error("Error reading security logs", { error: error.message });
    res.status(500).json({ error: "Failed to read security logs" });
  }
});

// System logs (admin only)
app.get("/logs/system", authenticate, requireRole(['admin']), (req, res) => {
  try {
    const systemFile = path.join(logDir, "system_analysis.log");
    if (fs.existsSync(systemFile)) {
      const logs = fs.readFileSync(systemFile, "utf8");
      res.json({ logs });
    } else {
      res.json({ logs: "No system logs available" });
    }
  } catch (error) {
    logger.error("Error reading system logs", { error: error.message });
    res.status(500).json({ error: "Failed to read system logs" });
  }
});

// Audit logs (admin only)
app.get("/logs/audit", authenticate, requireRole(['admin']), (req, res) => {
  try {
    const auditFile = path.join(logDir, "audit.log");
    if (fs.existsSync(auditFile)) {
      const logs = fs.readFileSync(auditFile, "utf8")
        .trim()
        .split("\n")
        .filter(line => line)
        .slice(-100)
        .map(line => JSON.parse(line));
      
      res.json({ logs, count: logs.length });
    } else {
      res.json({ logs: [], count: 0 });
    }
  } catch (error) {
    logger.error("Error reading audit logs", { error: error.message });
    res.status(500).json({ error: "Failed to read audit logs" });
  }
});

// API info
app.get("/api/info", (req, res) => {
  res.json({
    name: "Production Monitoring API",
    version: "2.0.0",
    endpoints: {
      public: [
        "GET /health",
        "GET /metrics/prometheus"
      ],
      authenticated: [
        "GET /metrics",
        "GET /metrics/application",
        "GET /health/processes",
        "GET /alerts",
        "GET /security"
      ],
      admin_only: [
        "GET /logs/system",
        "GET /logs/audit"
      ]
    },
    authentication: "Use X-API-Token header",
    roles: ["admin", "developer", "readonly"]
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error("Unhandled error", {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
  });
  
  res.status(500).json({
    error: "Internal server error",
    message: err.message,
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Backend started on port ${PORT}`, {
    instance: process.env.INSTANCE_NAME,
    nodeVersion: process.version,
  });
});
