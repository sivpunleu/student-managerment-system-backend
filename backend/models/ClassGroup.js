const mongoose = require("mongoose");

const classGroupSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      minlength: 1,
      maxlength: 60,
    },
    department: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Department",
      default: null,
    },
    year: {
      type: Number,
      min: 1,
      max: 6,
      validate: {
        validator(value) {
          return value == null || Number.isInteger(value);
        },
        message: "Year must be a whole number",
      },
      default: null,
    },
    shift: {
      type: String,
      enum: ["Morning", "Afternoon", "Evening", "Weekend", ""],
      default: "",
    },
    description: {
      type: String,
      default: "",
      trim: true,
      maxlength: 500,
    },
  },
  { timestamps: true },
);

classGroupSchema.index({ department: 1, year: 1, name: 1 });

module.exports = mongoose.model("ClassGroup", classGroupSchema);
