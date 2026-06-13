require("dotenv").config();

const test = require("node:test");
const assert = require("node:assert/strict");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");

const app = require("../app");
const User = require("../models/User");
const Department = require("../models/Department");
const Student = require("../models/Student");
const Attendance = require("../models/Attendance");
const Note = require("../models/Note");
const Task = require("../models/Task");

const shouldRun = process.env.RUN_INTEGRATION_TESTS === "1";
let server;
let baseUrl;
let adminToken;
let userToken;

const request = async (path, options = {}) => {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...options.headers,
    },
  });
  const body = await response.json();
  return { response, body };
};

if (shouldRun) {
  test.before(async () => {
    if (!process.env.MONGO_URI || !process.env.JWT_SECRET) {
      throw new Error("MONGO_URI and JWT_SECRET are required");
    }

    const databaseName = `student_management_test_${process.pid}_${Date.now()}`;
    await mongoose.connect(process.env.MONGO_URI, { dbName: databaseName });

    await Promise.all([
      User.syncIndexes(),
      Department.syncIndexes(),
      Student.syncIndexes(),
      Attendance.syncIndexes(),
      Note.syncIndexes(),
      Task.syncIndexes(),
    ]);

    const password = await bcrypt.hash("Password123", 4);
    const [admin, user] = await User.create([
      {
        fullName: "Integration Admin",
        email: "integration-admin@example.com",
        password,
        role: "admin",
      },
      {
        fullName: "Integration User",
        email: "integration-user@example.com",
        password,
        role: "user",
      },
    ]);

    adminToken = jwt.sign(
      { id: admin._id, role: admin.role },
      process.env.JWT_SECRET,
    );
    userToken = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
    );

    server = app.listen(0);
    await new Promise((resolve) => server.once("listening", resolve));
    baseUrl = `http://127.0.0.1:${server.address().port}`;
  });

  test.after(async () => {
    if (server) {
      await new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }

    if (mongoose.connection.readyState !== 0) {
      await mongoose.connection.dropDatabase();
      await mongoose.connection.close();
    }
  });
}

test(
  "admin, attendance reporting, authorization, and safe deletion workflow",
  { skip: !shouldRun },
  async () => {
    const adminHeaders = { Authorization: `Bearer ${adminToken}` };
    const userHeaders = { Authorization: `Bearer ${userToken}` };

    const departmentResult = await request("/api/departments", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({
        name: "Software Engineering",
        description: "Integration test department",
      }),
    });
    assert.equal(departmentResult.response.status, 201);
    const departmentId = departmentResult.body._id;

    const studentPayload = {
      studentId: "TEST-001",
      fullName: "Integration Student",
      gender: "Male",
      email: "integration-student@example.com",
      department: departmentId,
      year: 3,
    };

    const forbiddenResult = await request("/api/students", {
      method: "POST",
      headers: userHeaders,
      body: JSON.stringify(studentPayload),
    });
    assert.equal(forbiddenResult.response.status, 403);

    const studentResult = await request("/api/students", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify(studentPayload),
    });
    assert.equal(studentResult.response.status, 201);
    assert.equal(studentResult.body.department.name, "Software Engineering");
    const studentId = studentResult.body._id;

    const attendancePayload = {
      student: studentId,
      date: "2026-06-13",
      status: "present",
    };

    const attendanceResult = await request("/api/attendances", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify(attendancePayload),
    });
    assert.equal(attendanceResult.response.status, 201);
    const attendanceId = attendanceResult.body._id;

    const duplicateResult = await request("/api/attendances", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify(attendancePayload),
    });
    assert.equal(duplicateResult.response.status, 409);

    const summaryResult = await request(
      "/api/attendances/summary?date=2026-06-13",
      { headers: userHeaders },
    );
    assert.equal(summaryResult.response.status, 200);
    assert.equal(summaryResult.body.counts.present, 1);
    assert.equal(summaryResult.body.attendanceRate, 100);

    const secondStudentResult = await request("/api/students", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({
        ...studentPayload,
        studentId: "TEST-002",
        fullName: "Second Integration Student",
        email: "integration-student-2@example.com",
      }),
    });
    assert.equal(secondStudentResult.response.status, 201);
    const secondStudentId = secondStudentResult.body._id;

    const noteResult = await request("/api/notes", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({
        title: "Student progress",
        content: "Needs more practice with routing.",
        student: studentId,
      }),
    });
    assert.equal(noteResult.response.status, 201);

    const taskResult = await request("/api/tasks", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({
        title: "Complete Flutter exercise",
        dueDate: "2026-06-12T08:00:00.000Z",
        priority: "high",
        student: studentId,
      }),
    });
    assert.equal(taskResult.response.status, 201);

    const bulkResult = await request("/api/attendances/bulk", {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({
        date: "2026-06-13",
        records: [
          { student: studentId, status: "late", note: "Traffic" },
          { student: secondStudentId, status: "absent" },
        ],
      }),
    });
    assert.equal(bulkResult.response.status, 200);
    assert.equal(bulkResult.body.count, 2);

    const updatedSummaryResult = await request(
      "/api/attendances/summary?date=2026-06-13",
      { headers: userHeaders },
    );
    assert.equal(updatedSummaryResult.body.counts.present, 0);
    assert.equal(updatedSummaryResult.body.counts.late, 1);
    assert.equal(updatedSummaryResult.body.counts.absent, 1);
    assert.equal(updatedSummaryResult.body.attendanceRate, 50);

    const overviewResult = await request(
      `/api/students/${studentId}/overview`,
      { headers: adminHeaders },
    );
    assert.equal(overviewResult.response.status, 200);
    assert.equal(overviewResult.body.attendance.totalRecords, 1);
    assert.equal(overviewResult.body.attendance.counts.late, 1);
    assert.equal(overviewResult.body.notes.total, 1);
    assert.equal(overviewResult.body.tasks.pending, 1);
    assert.equal(overviewResult.body.tasks.overdue, 1);

    const userOverviewResult = await request(
      `/api/students/${studentId}/overview`,
      { headers: userHeaders },
    );
    assert.equal(userOverviewResult.response.status, 200);
    assert.equal(userOverviewResult.body.notes.total, 0);
    assert.equal(userOverviewResult.body.tasks.total, 0);

    const reportResult = await request(
      "/api/attendances/report?from=2026-06-13&to=2026-06-14",
      { headers: userHeaders },
    );
    assert.equal(reportResult.response.status, 200);
    assert.equal(reportResult.body.daily.length, 2);
    assert.equal(reportResult.body.totalRecords, 2);

    const blockedStudentDelete = await request(
      `/api/students/${studentId}`,
      { method: "DELETE", headers: adminHeaders },
    );
    assert.equal(blockedStudentDelete.response.status, 409);
    assert.equal(blockedStudentDelete.body.details.attendances, 1);

    const blockedDepartmentDelete = await request(
      `/api/departments/${departmentId}`,
      { method: "DELETE", headers: adminHeaders },
    );
    assert.equal(blockedDepartmentDelete.response.status, 409);
    assert.equal(blockedDepartmentDelete.body.details.students, 2);

    for (const attendance of bulkResult.body.attendances) {
      const attendanceDelete = await request(
        `/api/attendances/${attendance._id}`,
        { method: "DELETE", headers: adminHeaders },
      );
      assert.equal(attendanceDelete.response.status, 200);
    }

    const noteDelete = await request(`/api/notes/${noteResult.body._id}`, {
      method: "DELETE",
      headers: adminHeaders,
    });
    assert.equal(noteDelete.response.status, 200);

    const taskDelete = await request(`/api/tasks/${taskResult.body._id}`, {
      method: "DELETE",
      headers: adminHeaders,
    });
    assert.equal(taskDelete.response.status, 200);

    const studentDelete = await request(`/api/students/${studentId}`, {
      method: "DELETE",
      headers: adminHeaders,
    });
    assert.equal(studentDelete.response.status, 200);

    const secondStudentDelete = await request(
      `/api/students/${secondStudentId}`,
      { method: "DELETE", headers: adminHeaders },
    );
    assert.equal(secondStudentDelete.response.status, 200);

    const departmentDelete = await request(
      `/api/departments/${departmentId}`,
      { method: "DELETE", headers: adminHeaders },
    );
    assert.equal(departmentDelete.response.status, 200);
  },
);

test(
  "refresh rotation, profile, password reset, and logout revoke sessions",
  { skip: !shouldRun },
  async () => {
    const registerResult = await request("/api/auth/register", {
      method: "POST",
      body: JSON.stringify({
        fullName: "Session Test User",
        email: "session-test@example.com",
        password: "Password123",
      }),
    });
    assert.equal(registerResult.response.status, 201);
    assert.ok(registerResult.body.accessToken);
    assert.ok(registerResult.body.refreshToken);

    const firstAccessToken = registerResult.body.accessToken;
    const firstRefreshToken = registerResult.body.refreshToken;

    const refreshResult = await request("/api/auth/refresh", {
      method: "POST",
      body: JSON.stringify({ refreshToken: firstRefreshToken }),
    });
    assert.equal(refreshResult.response.status, 200);
    assert.notEqual(refreshResult.body.refreshToken, firstRefreshToken);

    const reusedRefreshResult = await request("/api/auth/refresh", {
      method: "POST",
      body: JSON.stringify({ refreshToken: firstRefreshToken }),
    });
    assert.equal(reusedRefreshResult.response.status, 401);

    const profileResult = await request("/api/auth/profile", {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${refreshResult.body.accessToken}`,
      },
      body: JSON.stringify({ fullName: "Updated Session User" }),
    });
    assert.equal(profileResult.response.status, 200);
    assert.equal(profileResult.body.user.fullName, "Updated Session User");

    const changePasswordResult = await request("/api/auth/change-password", {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${refreshResult.body.accessToken}`,
      },
      body: JSON.stringify({
        currentPassword: "Password123",
        newPassword: "NewPassword123",
      }),
    });
    assert.equal(changePasswordResult.response.status, 200);

    const revokedAccessResult = await request("/api/auth/me", {
      headers: { Authorization: `Bearer ${firstAccessToken}` },
    });
    assert.equal(revokedAccessResult.response.status, 401);

    const forgotResult = await request("/api/auth/forgot-password", {
      method: "POST",
      body: JSON.stringify({ email: "session-test@example.com" }),
    });
    assert.equal(forgotResult.response.status, 200);
    assert.ok(forgotResult.body.resetToken);

    const resetResult = await request("/api/auth/reset-password", {
      method: "POST",
      body: JSON.stringify({
        resetToken: forgotResult.body.resetToken,
        newPassword: "ResetPassword123",
      }),
    });
    assert.equal(resetResult.response.status, 200);

    const logoutResult = await request("/api/auth/logout", {
      method: "POST",
      headers: { Authorization: `Bearer ${resetResult.body.accessToken}` },
    });
    assert.equal(logoutResult.response.status, 200);

    const loggedOutResult = await request("/api/auth/me", {
      headers: { Authorization: `Bearer ${resetResult.body.accessToken}` },
    });
    assert.equal(loggedOutResult.response.status, 401);
  },
);
