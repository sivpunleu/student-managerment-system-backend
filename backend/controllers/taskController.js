const Task = require("../models/Task");
const Student = require("../models/Student");
const createHttpError = require("../utils/httpError");
const {
  escapeRegex,
  parsePagination,
  pickFields,
} = require("../utils/validation");

const ownershipFilter = (req) =>
  req.userRole === "admin" ? {} : { createdBy: req.user._id };

const isStudentRole = (req) => req.userRole === "student";

const getCurrentStudentProfile = async (req) => {
  const student = await Student.findOne({ email: req.user.email }).select("_id");

  if (!student) {
    throw createHttpError(404, "Student profile not found for this account");
  }

  return student;
};

const applyStudentScope = async (req, filter) => {
  if (!isStudentRole(req)) {
    return;
  }

  const student = await getCurrentStudentProfile(req);
  if (filter.student && filter.student.toString() !== student._id.toString()) {
    throw createHttpError(403, "You can only access your own student tasks");
  }
  filter.student = student._id;
};

const ensureStudentExists = async (req, studentId) => {
  if (!studentId) {
    return;
  }

  const student = await Student.findById(studentId).select("email");
  if (!student) {
    throw createHttpError(404, "Student not found");
  }
  if (isStudentRole(req) && student.email !== req.user.email) {
    throw createHttpError(403, "You can only link tasks to yourself");
  }
};

const parseOptionalDate = (value) => {
  if (value === null || value === "") {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw createHttpError(400, "Invalid due date");
  }

  return date;
};

exports.getTasks = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = ownershipFilter(req);

  if (req.query.student) {
    filter.student = req.query.student;
  }
  await applyStudentScope(req, filter);

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.priority) {
    filter.priority = req.query.priority;
  }

  if (req.query.search) {
    const search = new RegExp(escapeRegex(req.query.search), "i");
    filter.$or = [{ title: search }, { description: search }];
  }

  const [tasks, total] = await Promise.all([
    Task.find(filter)
      .populate("student", "studentId fullName")
      .populate("createdBy", "fullName email")
      .sort({ dueDate: 1, createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Task.countDocuments(filter),
  ]);

  res.json({
    tasks,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.getTaskById = async (req, res) => {
  const task = await Task.findOne({
    _id: req.params.id,
    ...ownershipFilter(req),
  })
    .populate("student", "studentId fullName")
    .populate("createdBy", "fullName email");

  if (!task) {
    throw createHttpError(404, "Task not found");
  }

  res.json(task);
};

exports.createTask = async (req, res) => {
  const data = pickFields(req.body, [
    "title",
    "description",
    "dueDate",
    "priority",
    "status",
    "student",
  ]);

  if (!data.title) {
    throw createHttpError(400, "Task title is required");
  }

  if (data.dueDate !== undefined) {
    data.dueDate = parseOptionalDate(data.dueDate);
  }

  await ensureStudentExists(req, data.student);

  const task = await Task.create({
    ...data,
    createdBy: req.user._id,
  });

  await task.populate([
    { path: "student", select: "studentId fullName" },
    { path: "createdBy", select: "fullName email" },
  ]);

  res.status(201).json(task);
};

exports.updateTask = async (req, res) => {
  const updates = pickFields(req.body, [
    "title",
    "description",
    "dueDate",
    "priority",
    "status",
    "student",
  ]);

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid fields were provided");
  }

  if (updates.dueDate !== undefined) {
    updates.dueDate = parseOptionalDate(updates.dueDate);
  }

  await ensureStudentExists(req, updates.student);

  const task = await Task.findOneAndUpdate(
    { _id: req.params.id, ...ownershipFilter(req) },
    updates,
    { returnDocument: "after", runValidators: true },
  )
    .populate("student", "studentId fullName")
    .populate("createdBy", "fullName email");

  if (!task) {
    throw createHttpError(404, "Task not found");
  }

  res.json(task);
};

exports.deleteTask = async (req, res) => {
  const task = await Task.findOneAndDelete({
    _id: req.params.id,
    ...ownershipFilter(req),
  });

  if (!task) {
    throw createHttpError(404, "Task not found");
  }

  res.json({ message: "Task deleted" });
};
