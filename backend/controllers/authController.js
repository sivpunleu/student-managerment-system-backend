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

const hashToken = (token) =>
  crypto.createHash("sha256").update(token).digest("hex");

const serializeUser = (user) => ({
  id: user._id,
  fullName: user.fullName,
  email: user.email,
  role: user.role,
});

const createAccessToken = (user) =>
  jwt.sign(
    {
      id: user._id,
      role: user.role,
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
