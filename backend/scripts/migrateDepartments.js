require("dotenv").config();

const mongoose = require("mongoose");
const connectDB = require("../config/db");
const Department = require("../models/Department");

const normalizeName = (value) =>
  String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");

const getInitials = (value) =>
  String(value)
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word[0])
    .join("")
    .toLowerCase();

const migrateDepartments = async () => {
  await connectDB();

  const departments = await Department.find().lean();
  const studentsCollection = mongoose.connection.collection("students");
  const students = await studentsCollection
    .find({ department: { $type: "string" } })
    .toArray();

  let migrated = 0;
  let created = 0;

  for (const student of students) {
    const legacyName = student.department.trim();
    const normalizedLegacyName = normalizeName(legacyName);

    let department = departments.find(
      (item) => normalizeName(item.name) === normalizedLegacyName,
    );

    if (!department) {
      const initialMatches = departments.filter(
        (item) => getInitials(item.name) === normalizedLegacyName,
      );

      if (initialMatches.length === 1) {
        [department] = initialMatches;
      }
    }

    if (!department) {
      department = await Department.create({
        name: legacyName,
        description: "Created from legacy student data",
      });
      departments.push(department.toObject());
      created += 1;
    }

    await studentsCollection.updateOne(
      { _id: student._id },
      { $set: { department: department._id } },
    );
    migrated += 1;
  }

  console.log(
    `Department migration complete: ${migrated} students migrated, ${created} departments created`,
  );
};

migrateDepartments()
  .catch((error) => {
    console.error("Department migration failed:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.connection.close();
  });
