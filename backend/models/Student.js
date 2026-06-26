const mongoose = require("mongoose");

const studentSchema = new mongoose.Schema(
  {
    studentId: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      maxlength: 30,
    },
    fullName: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 100,
    },
    gender: {
      type: String,
      enum: ["Male", "Female"],
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
      match: [/^[^\s@]+@[^\s@]+\.[^\s@]+$/, "Please enter a valid email"],
    },
    phone: {
      type: String,
      trim: true,
      maxlength: 30,
    },
    department: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Department",
      required: true,
    },
    classGroup: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "ClassGroup",
      default: null,
    },
    year: {
      type: Number,
      min: 1,
      max: 6,
      validate: {
        validator: Number.isInteger,
        message: "Year must be a whole number",
      },
    },
  },
  {
    timestamps: true,
  },
);

studentSchema.index({ department: 1, fullName: 1 });
studentSchema.index({ classGroup: 1, fullName: 1 });

module.exports = mongoose.model("Student", studentSchema);
