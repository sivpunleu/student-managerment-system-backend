const Task = require("../models/Task");
const Student = require("../models/Student");
const createHttpError = require("../utils/httpError");
const {
  escapeRegex,
  parsePagination,
  pickFields,
} = require("../utils/validation");

const ownershipFilter = (req) =>
  req.user.role === "admin" ? {} : { createdBy: req.user._id };

const ensureStudentExists = async (studentId) => {
  if (!studentId) {
    return;
  }

  const studentExists = await Student.exists({ _id: studentId });
  if (!studentExists) {
    throw createHttpError(404, "Student not found");
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

  await ensureStudentExists(data.student);

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

  await ensureStudentExists(updates.student);

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
