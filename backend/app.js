require("dotenv").config();

const express = require("express");
const cors = require("cors");
const path = require("path");

const studentRoutes = require("./routes/studentRoutes");
const departmentRoutes = require("./routes/departmentRoutes");
const authRoutes = require("./routes/authRoutes");
const attendanceRoutes = require("./routes/attendanceRoutes");
const noteRoutes = require("./routes/noteRoutes");
const taskRoutes = require("./routes/taskRoutes");
const { notFound, errorHandler } = require("./middleware/errorMiddleware");

const app = express();

const allowedOrigins = (process.env.CORS_ORIGIN || "*")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

app.disable("x-powered-by");
app.use(
  cors({
    origin(origin, callback) {
      if (
        !origin ||
        allowedOrigins.includes("*") ||
        allowedOrigins.includes(origin)
      ) {
        return callback(null, true);
      }

      const error = new Error("Origin is not allowed by CORS");
      error.statusCode = 403;
      return callback(error);
    },
  }),
);
app.use("/api/auth/profile/avatar", express.json({ limit: "3mb" }));
app.use(express.json({ limit: "20kb" }));

app.get("/", (req, res) => {
  res.json({
    name: "Student Management API",
    status: "running",
  });
});

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    timestamp: new Date().toISOString(),
  });
});

app.use("/api/docs", express.static(path.join(__dirname, "docs")));
app.use("/api/auth", authRoutes);
app.use("/api/students", studentRoutes);
app.use("/api/departments", departmentRoutes);
app.use("/api/attendances", attendanceRoutes);
app.use("/api/notes", noteRoutes);
app.use("/api/tasks", taskRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
