const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const createHttpError = require("../utils/httpError");
const {
  isNonEmptyString,
  isValidEmail,
  normalizeEmail,
  pickFields,
} = require("../utils/validation");

const ACCESS_TOKEN_EXPIRES_IN =
  process.env.JWT_ACCESS_EXPIRES_IN || process.env.JWT_EXPIRES_IN || "1h";
const REFRESH_TOKEN_DAYS = Number(process.env.REFRESH_TOKEN_DAYS || 30);
const RESET_TOKEN_MINUTES = 15;
const MAX_AVATAR_BYTES = 2 * 1024 * 1024;

const hashToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");

const effectiveRole = (user) => (user.role === "user" ? "student" : user.role);

const serializeUser = (user) => ({
  id: user._id,
  fullName: user.fullName,
  email: user.email,
  role: effectiveRole(user),
  isActive: user.isActive !== false,
  avatarUrl: user.avatarUpdatedAt
    ? `/api/auth/avatar/${user._id}?v=${user.avatarUpdatedAt.getTime()}`
    : null,
});

const detectImageContentType = (buffer) => {
  if (
    buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  ) {
    return "image/jpeg";
  }

  const pngSignature = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);
  if (
    buffer.length >= pngSignature.length &&
    buffer.subarray(0, pngSignature.length).equals(pngSignature)
  ) {
    return "image/png";
  }

  if (
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString("ascii") === "RIFF" &&
    buffer.subarray(8, 12).toString("ascii") === "WEBP"
  ) {
    return "image/webp";
  }

  return null;
};

const decodeAvatar = (imageData) => {
  if (typeof imageData !== "string" || imageData.length === 0) {
    throw createHttpError(400, "Profile image data is required");
  }

  const base64 = imageData.includes(",")
    ? imageData.slice(imageData.indexOf(",") + 1)
    : imageData;
  const normalized = base64.replace(/\s/g, "");

  if (
    normalized.length === 0 ||
    normalized.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(normalized)
  ) {
    throw createHttpError(400, "Profile image data is invalid");
  }

  const buffer = Buffer.from(normalized, "base64");
  if (buffer.length === 0) {
    throw createHttpError(400, "Profile image data is invalid");
  }
  if (buffer.length > MAX_AVATAR_BYTES) {
    throw createHttpError(413, "Profile image must be 2 MB or smaller");
  }

  const contentType = detectImageContentType(buffer);
  if (!contentType) {
    throw createHttpError(400, "Only JPEG, PNG, and WebP images are allowed");
  }

  return { buffer, contentType };
};

const createAccessToken = (user) =>
  jwt.sign(
    {
      id: user._id,
      role: effectiveRole(user),
      version: user.tokenVersion || 0,
    },
    process.env.JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRES_IN },
  );

const issueSession = async (user) => {
  const refreshToken = crypto.randomBytes(48).toString("base64url");
  user.refreshTokenHash = hashToken(refreshToken);
  user.refreshTokenExpires = new Date(
    Date.now() + REFRESH_TOKEN_DAYS * 24 * 60 * 60 * 1000,
  );
  await user.save();

  const accessToken = createAccessToken(user);

  return {
    token: accessToken,
    accessToken,
    refreshToken,
    user: serializeUser(user),
  };
};

const validatePassword = (password) => {
  if (typeof password !== "string" || password.length < 8) {
    throw createHttpError(
      400,
      "Password must contain at least 8 characters",
    );
  }
};

exports.register = async (req, res) => {
  const { fullName, password } = req.body;
  const email = normalizeEmail(req.body.email);

  if (!isNonEmptyString(fullName) || fullName.trim().length < 2) {
    throw createHttpError(
      400,
      "Full name must contain at least 2 characters",
    );
  }

  if (!isValidEmail(email)) {
    throw createHttpError(400, "A valid email is required");
  }

  validatePassword(password);

  const userExists = await User.findOne({ email });
  if (userExists) {
    throw createHttpError(409, "Email already exists");
  }

  const user = await User.create({
    fullName: fullName.trim(),
    email,
    password: await bcrypt.hash(password, 12),
  });

  const session = await issueSession(user);
  res.status(201).json({
    message: "Registration successful",
    ...session,
  });
};

exports.createStaff = async (req, res) => {
  const { fullName, password } = req.body;
  const email = normalizeEmail(req.body.email);

  if (!isNonEmptyString(fullName) || fullName.trim().length < 2) {
    throw createHttpError(
      400,
      "Full name must contain at least 2 characters",
    );
  }

  if (!isValidEmail(email)) {
    throw createHttpError(400, "A valid email is required");
  }

  validatePassword(password);

  const userExists = await User.findOne({ email });
  if (userExists) {
    throw createHttpError(409, "Email already exists");
  }

  const user = await User.create({
    fullName: fullName.trim(),
    email,
    password: await bcrypt.hash(password, 12),
    role: "staff",
  });

  res.status(201).json({
    message: "Staff account created",
    user: serializeUser(user),
  });
};

exports.login = async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const { password } = req.body;

  if (!isValidEmail(email) || typeof password !== "string") {
    throw createHttpError(400, "Email and password are required");
  }

  const user = await User.findOne({ email }).select(
    "+password +tokenVersion +refreshTokenHash +refreshTokenExpires",
  );
  if (!user || !(await bcrypt.compare(password, user.password))) {
    throw createHttpError(401, "Invalid email or password");
  }
  if (user.isActive === false) {
    throw createHttpError(403, "Account is deactivated");
  }

  const session = await issueSession(user);
  res.json({ message: "Login successful", ...session });
};

exports.refresh = async (req, res) => {
  const refreshToken = req.body.refreshToken;

  if (typeof refreshToken !== "string" || refreshToken.length < 20) {
    throw createHttpError(401, "A valid refresh token is required");
  }

  const user = await User.findOne({
    refreshTokenHash: hashToken(refreshToken),
    refreshTokenExpires: { $gt: new Date() },
  }).select(
    "+tokenVersion +refreshTokenHash +refreshTokenExpires",
  );

  if (!user) {
    throw createHttpError(401, "Invalid or expired refresh token");
  }
  if (user.isActive === false) {
    throw createHttpError(403, "Account is deactivated");
  }

  const session = await issueSession(user);
  res.json({ message: "Session refreshed", ...session });
};

exports.logout = async (req, res) => {
  await User.updateOne(
    { _id: req.user._id },
    {
      $inc: { tokenVersion: 1 },
      $set: {
        refreshTokenHash: null,
        refreshTokenExpires: null,
      },
    },
  );

  res.json({ message: "Logged out successfully" });
};

exports.getMe = async (req, res) => {
  res.json({ user: serializeUser(req.user) });
};

exports.updateProfile = async (req, res) => {
  const updates = pickFields(req.body, ["fullName", "email"]);

  if (updates.fullName !== undefined) {
    if (!isNonEmptyString(updates.fullName) || updates.fullName.trim().length < 2) {
      throw createHttpError(
        400,
        "Full name must contain at least 2 characters",
      );
    }
    updates.fullName = updates.fullName.trim();
  }

  if (updates.email !== undefined) {
    updates.email = normalizeEmail(updates.email);
    if (!isValidEmail(updates.email)) {
      throw createHttpError(400, "A valid email is required");
    }

    const existing = await User.exists({
      _id: { $ne: req.user._id },
      email: updates.email,
    });
    if (existing) {
      throw createHttpError(409, "Email already exists");
    }
  }

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid profile fields were provided");
  }

  const user = await User.findByIdAndUpdate(req.user._id, updates, {
    returnDocument: "after",
    runValidators: true,
  });

  res.json({
    message: "Profile updated",
    user: serializeUser(user),
  });
};

exports.updateAvatar = async (req, res) => {
  const { buffer, contentType } = decodeAvatar(req.body.imageData);
  const avatarUpdatedAt = new Date();

  const user = await User.findByIdAndUpdate(
    req.user._id,
    {
      avatarData: buffer,
      avatarContentType: contentType,
      avatarUpdatedAt,
    },
    {
      returnDocument: "after",
      runValidators: true,
    },
  );

  res.json({
    message: "Profile image updated",
    user: serializeUser(user),
  });
};

exports.deleteAvatar = async (req, res) => {
  const user = await User.findByIdAndUpdate(
    req.user._id,
    {
      avatarData: null,
      avatarContentType: null,
      avatarUpdatedAt: null,
    },
    { returnDocument: "after" },
  );

  res.json({
    message: "Profile image removed",
    user: serializeUser(user),
  });
};

exports.getAvatar = async (req, res) => {
  const user = await User.findById(req.params.userId).select(
    "+avatarData +avatarContentType",
  );

  if (!user || !user.avatarData || !user.avatarContentType) {
    throw createHttpError(404, "Profile image not found");
  }

  res.set({
    "Content-Type": user.avatarContentType,
    "Content-Length": user.avatarData.length,
    "Cache-Control": "public, max-age=86400, immutable",
  });
  res.send(user.avatarData);
};

exports.changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  validatePassword(newPassword);

  const user = await User.findById(req.user._id).select(
    "+password +tokenVersion +refreshTokenHash +refreshTokenExpires",
  );

  if (
    typeof currentPassword !== "string" ||
    !(await bcrypt.compare(currentPassword, user.password))
  ) {
    throw createHttpError(401, "Current password is incorrect");
  }

  user.password = await bcrypt.hash(newPassword, 12);
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  const session = await issueSession(user);

  res.json({
    message: "Password changed successfully",
    ...session,
  });
};

exports.forgotPassword = async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const genericMessage =
    "If the email exists, a password reset token has been created";

  if (!isValidEmail(email)) {
    throw createHttpError(400, "A valid email is required");
  }

  const user = await User.findOne({ email }).select(
    "+resetPasswordTokenHash +resetPasswordExpires",
  );

  if (!user) {
    return res.json({ message: genericMessage });
  }

  const resetToken = crypto.randomBytes(32).toString("hex");
  user.resetPasswordTokenHash = hashToken(resetToken);
  user.resetPasswordExpires = new Date(
    Date.now() + RESET_TOKEN_MINUTES * 60 * 1000,
  );
  await user.save();

  const response = { message: genericMessage };

  // Replace this development delivery with an email provider in production.
  if (process.env.NODE_ENV !== "production") {
    response.resetToken = resetToken;
    response.expiresInMinutes = RESET_TOKEN_MINUTES;
  }

  res.json(response);
};

exports.resetPassword = async (req, res) => {
  const { resetToken, newPassword } = req.body;
  validatePassword(newPassword);

  if (typeof resetToken !== "string" || resetToken.length < 20) {
    throw createHttpError(400, "A valid reset token is required");
  }

  const user = await User.findOne({
    resetPasswordTokenHash: hashToken(resetToken),
    resetPasswordExpires: { $gt: new Date() },
  }).select(
    "+password +tokenVersion +refreshTokenHash +refreshTokenExpires +resetPasswordTokenHash +resetPasswordExpires",
  );

  if (!user) {
    throw createHttpError(400, "Invalid or expired reset token");
  }

  user.password = await bcrypt.hash(newPassword, 12);
  user.tokenVersion = (user.tokenVersion || 0) + 1;
  user.resetPasswordTokenHash = null;
  user.resetPasswordExpires = null;
  const session = await issueSession(user);

  res.json({
    message: "Password reset successfully",
    ...session,
  });
};
