const Department = require("../models/Department");
const Student = require("../models/Student");
const ClassGroup = require("../models/ClassGroup");
const createHttpError = require("../utils/httpError");
const {
  escapeRegex,
  parsePagination,
  pickFields,
} = require("../utils/validation");

exports.getDepartments = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = {};

  if (req.query.search) {
    const search = new RegExp(escapeRegex(req.query.search), "i");
    filter.$or = [{ name: search }, { description: search }];
  }

  const [departments, total] = await Promise.all([
    Department.find(filter).sort({ name: 1 }).skip(skip).limit(limit),
    Department.countDocuments(filter),
  ]);

  res.json({
    departments,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.getDepartmentById = async (req, res) => {
  const department = await Department.findById(req.params.id);

  if (!department) {
    throw createHttpError(404, "Department not found");
  }

  res.json(department);
};

exports.createDepartment = async (req, res) => {
  const data = pickFields(req.body, ["name", "description"]);

  if (!data.name) {
    throw createHttpError(400, "Department name is required");
  }

  const department = await Department.create(data);
  res.status(201).json(department);
};

exports.updateDepartment = async (req, res) => {
  const updates = pickFields(req.body, ["name", "description"]);

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid fields were provided");
  }

  const department = await Department.findByIdAndUpdate(
    req.params.id,
    updates,
    { returnDocument: "after", runValidators: true },
  );

  if (!department) {
    throw createHttpError(404, "Department not found");
  }

  res.json(department);
};

exports.deleteDepartment = async (req, res) => {
  const department = await Department.findById(req.params.id);

  if (!department) {
    throw createHttpError(404, "Department not found");
  }

  const [students, classes] = await Promise.all([
    Student.countDocuments({ department: department._id }),
    ClassGroup.countDocuments({ department: department._id }),
  ]);

  if (students > 0 || classes > 0) {
    const error = createHttpError(
      409,
      "Department cannot be deleted while students or classes are assigned to it",
    );
    error.details = { students, classes };
    throw error;
  }

  await department.deleteOne();
  res.json({ message: "Department deleted" });
};
