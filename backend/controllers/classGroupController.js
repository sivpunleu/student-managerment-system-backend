const ClassGroup = require("../models/ClassGroup");
const Department = require("../models/Department");
const Student = require("../models/Student");
const createHttpError = require("../utils/httpError");
const {
  escapeRegex,
  parsePagination,
  pickFields,
} = require("../utils/validation");

const populateClassGroup = (query) =>
  query.populate("department", "name description");

const ensureDepartmentExists = async (departmentId) => {
  if (!departmentId) {
    return;
  }

  const departmentExists = await Department.exists({ _id: departmentId });
  if (!departmentExists) {
    throw createHttpError(404, "Department not found");
  }
};

exports.getClassGroups = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = {};

  if (req.query.search) {
    const search = new RegExp(escapeRegex(req.query.search), "i");
    filter.$or = [{ name: search }, { shift: search }, { description: search }];
  }

  if (req.query.department) {
    filter.department = req.query.department;
  }

  if (req.query.year) {
    filter.year = req.query.year;
  }

  const [classes, total] = await Promise.all([
    populateClassGroup(
      ClassGroup.find(filter).sort({ name: 1 }).skip(skip).limit(limit),
    ),
    ClassGroup.countDocuments(filter),
  ]);

  res.json({
    classes,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.getClassGroupById = async (req, res) => {
  const classGroup = await populateClassGroup(
    ClassGroup.findById(req.params.id),
  );

  if (!classGroup) {
    throw createHttpError(404, "Class not found");
  }

  res.json(classGroup);
};

exports.createClassGroup = async (req, res) => {
  const data = pickFields(req.body, [
    "name",
    "department",
    "year",
    "shift",
    "description",
  ]);

  if (!data.name || data.name.trim().length < 1) {
    throw createHttpError(400, "Class name is required");
  }

  await ensureDepartmentExists(data.department);

  const classGroup = await ClassGroup.create(data);
  await classGroup.populate("department", "name description");
  res.status(201).json(classGroup);
};

exports.updateClassGroup = async (req, res) => {
  const updates = pickFields(req.body, [
    "name",
    "department",
    "year",
    "shift",
    "description",
  ]);

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid fields were provided");
  }

  await ensureDepartmentExists(updates.department);

  const classGroup = await populateClassGroup(
    ClassGroup.findByIdAndUpdate(req.params.id, updates, {
      returnDocument: "after",
      runValidators: true,
    }),
  );

  if (!classGroup) {
    throw createHttpError(404, "Class not found");
  }

  res.json(classGroup);
};

exports.deleteClassGroup = async (req, res) => {
  const classGroup = await ClassGroup.findById(req.params.id);

  if (!classGroup) {
    throw createHttpError(404, "Class not found");
  }

  const students = await Student.countDocuments({ classGroup: classGroup._id });

  if (students > 0) {
    const error = createHttpError(
      409,
      "Class cannot be deleted while students are assigned to it",
    );
    error.details = { students };
    throw error;
  }

  await classGroup.deleteOne();
  res.json({ message: "Class deleted" });
};
