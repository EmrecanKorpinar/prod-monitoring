const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const winston = require("winston");
const DailyRotateFile = require("winston-daily-rotate-file");
const fs = require("fs");
const path = require("path");

const app = express();

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
    // Konsol çıktısı
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
    // Günlük rotate eden dosya
    new DailyRotateFile({
      filename: path.join(logDir, "app-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      maxFiles: "7d",
      maxSize: "10m",
      format: winston.format.json(),
    }),
    // Error log
    new DailyRotateFile({
      filename: path.join(logDir, "error-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      level: "error",
      maxFiles: "14d",
      maxSize: "10m",
    }),
  ],
});

// Morgan ile HTTP request logging
app.use(
  morgan("combined", {
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

app.use(cors());
app.use(express.json());

// Request tracking middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on("finish", () => {
    const duration = Date.now() - startTime;
    logger.info("HTTP Request", {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
    });
  });
  
  next();
});

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

// Metrics endpoint - Son metrikleri getir
app.get("/metrics", (req, res) => {
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

// Alerts endpoint
app.get("/alerts", (req, res) => {
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

// Security logs endpoint
app.get("/security", (req, res) => {
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
