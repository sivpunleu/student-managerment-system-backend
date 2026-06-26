require("dotenv").config();

const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");
const connectDB = require("../config/db");
const User = require("../models/User");
const { isValidEmail, normalizeEmail } = require("../utils/validation");

const createStaff = async () => {
  const fullName = (process.env.STAFF_NAME || "").trim();
  const email = normalizeEmail(process.env.STAFF_EMAIL);
  const password = process.env.STAFF_PASSWORD || "";

  if (fullName.length < 2 || !isValidEmail(email) || password.length < 8) {
    throw new Error(
      "Set STAFF_NAME, a valid STAFF_EMAIL, and STAFF_PASSWORD with at least 8 characters",
    );
  }

  await connectDB();

  const hashedPassword = await bcrypt.hash(password, 12);
  const existingUser = await User.findOne({ email }).select("+password");

  if (existingUser) {
    existingUser.fullName = fullName;
    existingUser.password = hashedPassword;
    existingUser.role = "staff";
    await existingUser.save();
    console.log(`Staff updated: ${email}`);
    return;
  }

  await User.create({
    fullName,
    email,
    password: hashedPassword,
    role: "staff",
  });

  console.log(`Staff created: ${email}`);
};

createStaff()
  .catch((error) => {
    console.error("Could not create staff:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.connection.close();
  });
