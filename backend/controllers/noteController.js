const Note = require("../models/Note");
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

exports.getNotes = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = ownershipFilter(req);

  if (req.query.student) {
    filter.student = req.query.student;
  }

  if (req.query.search) {
    const search = new RegExp(escapeRegex(req.query.search), "i");
    filter.$or = [{ title: search }, { content: search }];
  }

  const [notes, total] = await Promise.all([
    Note.find(filter)
      .populate("student", "studentId fullName")
      .populate("createdBy", "fullName email")
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(limit),
    Note.countDocuments(filter),
  ]);

  res.json({
    notes,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.getNoteById = async (req, res) => {
  const note = await Note.findOne({
    _id: req.params.id,
    ...ownershipFilter(req),
  })
    .populate("student", "studentId fullName")
    .populate("createdBy", "fullName email");

  if (!note) {
    throw createHttpError(404, "Note not found");
  }

  res.json(note);
};

exports.createNote = async (req, res) => {
  const data = pickFields(req.body, ["title", "content", "student"]);

  if (!data.title || !data.content) {
    throw createHttpError(400, "Title and content are required");
  }

  await ensureStudentExists(data.student);

  const note = await Note.create({
    ...data,
    createdBy: req.user._id,
  });

  await note.populate([
    { path: "student", select: "studentId fullName" },
    { path: "createdBy", select: "fullName email" },
  ]);

  res.status(201).json(note);
};

exports.updateNote = async (req, res) => {
  const updates = pickFields(req.body, ["title", "content", "student"]);

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid fields were provided");
  }

  await ensureStudentExists(updates.student);

  const note = await Note.findOneAndUpdate(
    { _id: req.params.id, ...ownershipFilter(req) },
    updates,
    { returnDocument: "after", runValidators: true },
  )
    .populate("student", "studentId fullName")
    .populate("createdBy", "fullName email");

  if (!note) {
    throw createHttpError(404, "Note not found");
  }

  res.json(note);
};

exports.deleteNote = async (req, res) => {
  const note = await Note.findOneAndDelete({
    _id: req.params.id,
    ...ownershipFilter(req),
  });

  if (!note) {
    throw createHttpError(404, "Note not found");
  }

  res.json({ message: "Note deleted" });
};
