require("dotenv").config();

const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");
const connectDB = require("../config/db");
const User = require("../models/User");
const { isValidEmail, normalizeEmail } = require("../utils/validation");

const createAdmin = async () => {
  const fullName = (process.env.ADMIN_NAME || "").trim();
  const email = normalizeEmail(process.env.ADMIN_EMAIL);
  const password = process.env.ADMIN_PASSWORD || "";

  if (fullName.length < 2 || !isValidEmail(email) || password.length < 8) {
    throw new Error(
      "Set ADMIN_NAME, a valid ADMIN_EMAIL, and ADMIN_PASSWORD with at least 8 characters",
    );
  }

  await connectDB();

  const hashedPassword = await bcrypt.hash(password, 12);
  const existingUser = await User.findOne({ email }).select("+password");

  if (existingUser) {
    existingUser.fullName = fullName;
    existingUser.password = hashedPassword;
    existingUser.role = "admin";
    await existingUser.save();
    console.log(`Admin updated: ${email}`);
    return;
  }

  await User.create({
    fullName,
    email,
    password: hashedPassword,
    role: "admin",
  });

  console.log(`Admin created: ${email}`);
};

createAdmin()
  .catch((error) => {
    console.error("Could not create admin:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.connection.close();
  });
