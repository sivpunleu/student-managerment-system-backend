const bcrypt = require("bcryptjs");
const User = require("../models/User");
const Student = require("../models/Student");
const createHttpError = require("../utils/httpError");
const { escapeRegex, parsePagination } = require("../utils/validation");

const allowedRoles = ["admin", "staff", "student"];
const effectiveRole = (user) => (user.role === "user" ? "student" : user.role);

const validatePassword = (password) => {
  if (typeof password !== "string" || password.length < 8) {
    throw createHttpError(
      400,
      "Password must contain at least 8 characters",
    );
  }
};

const serializeUser = (user, studentByEmail = new Map()) => {
  const student = studentByEmail.get(user.email);
  return {
    id: user._id,
    fullName: user.fullName,
    email: user.email,
    role: effectiveRole(user),
    isActive: user.isActive !== false,
    linkedStudent: student
      ? {
          id: student._id,
          studentId: student.studentId,
          fullName: student.fullName,
        }
      : null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
};

const linkedStudentsFor = async (users) => {
  const emails = users.map((user) => user.email);
  const students = await Student.find({ email: { $in: emails } }).select(
    "studentId fullName email",
  );
  return new Map(students.map((student) => [student.email, student]));
};

exports.getUsers = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = {};

  if (req.query.role && allowedRoles.includes(req.query.role)) {
    filter.role =
      req.query.role === "student"
        ? { $in: ["student", "user"] }
        : req.query.role;
  }

  if (req.query.status === "active") {
    filter.isActive = { $ne: false };
  } else if (req.query.status === "inactive") {
    filter.isActive = false;
  }

  if (req.query.search) {
    const search = new RegExp(escapeRegex(req.query.search), "i");
    filter.$or = [{ fullName: search }, { email: search }];
  }

  const [users, total] = await Promise.all([
    User.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    User.countDocuments(filter),
  ]);
  const studentByEmail = await linkedStudentsFor(users);

  res.json({
    users: users.map((user) => serializeUser(user, studentByEmail)),
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.updateUserRole = async (req, res) => {
  const role = req.body.role === "user" ? "student" : req.body.role;
  if (!allowedRoles.includes(role)) {
    throw createHttpError(400, "A valid role is required");
  }

  if (req.params.id === req.user._id.toString() && role !== "admin") {
    throw createHttpError(400, "You cannot remove your own admin role");
  }

  const user = await User.findById(req.params.id).select("+tokenVersion");
  if (!user) {
    throw createHttpError(404, "User not found");
  }

  user.role = role;
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  await user.save();

  const studentByEmail = await linkedStudentsFor([user]);
  res.json({
    message: "User role updated",
    user: serializeUser(user, studentByEmail),
  });
};

exports.updateUserStatus = async (req, res) => {
  if (typeof req.body.isActive !== "boolean") {
    throw createHttpError(400, "Active status is required");
  }

  if (req.params.id === req.user._id.toString() && req.body.isActive === false) {
    throw createHttpError(400, "You cannot deactivate your own account");
  }

  const user = await User.findById(req.params.id).select(
    "+tokenVersion +refreshTokenHash +refreshTokenExpires",
  );
  if (!user) {
    throw createHttpError(404, "User not found");
  }

  user.isActive = req.body.isActive;
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  if (!user.isActive) {
    user.refreshTokenHash = null;
    user.refreshTokenExpires = null;
  }
  await user.save();

  const studentByEmail = await linkedStudentsFor([user]);
  res.json({
    message: user.isActive ? "User activated" : "User deactivated",
    user: serializeUser(user, studentByEmail),
  });
};

exports.resetUserPassword = async (req, res) => {
  validatePassword(req.body.newPassword);

  const user = await User.findById(req.params.id).select(
    "+password +tokenVersion +refreshTokenHash +refreshTokenExpires",
  );
  if (!user) {
    throw createHttpError(404, "User not found");
  }

  user.password = await bcrypt.hash(req.body.newPassword, 12);
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  user.refreshTokenHash = null;
  user.refreshTokenExpires = null;
  await user.save();

  res.json({ message: "Password reset successfully" });
};
