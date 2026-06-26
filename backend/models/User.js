const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 100,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      match: [/^[^\s@]+@[^\s@]+\.[^\s@]+$/, "Please enter a valid email"],
    },
    password: {
      type: String,
      required: true,
      select: false,
    },
    role: {
      type: String,
      enum: ["admin", "staff", "student", "user"],
      default: "student",
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    avatarData: {
      type: Buffer,
      select: false,
      default: null,
    },
    avatarContentType: {
      type: String,
      enum: ["image/jpeg", "image/png", "image/webp"],
      select: false,
      default: null,
    },
    avatarUpdatedAt: {
      type: Date,
      default: null,
    },
    tokenVersion: {
      type: Number,
      default: 0,
      select: false,
    },
    refreshTokenHash: {
      type: String,
      select: false,
      default: null,
    },
    refreshTokenExpires: {
      type: Date,
      select: false,
      default: null,
    },
    resetPasswordTokenHash: {
      type: String,
      select: false,
      default: null,
    },
    resetPasswordExpires: {
      type: Date,
      select: false,
      default: null,
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model("User", userSchema);
