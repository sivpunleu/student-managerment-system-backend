const bcrypt = require("bcryptjs");
const Student = require("../models/Student");
const Department = require("../models/Department");
const Attendance = require("../models/Attendance");
const Note = require("../models/Note");
const Task = require("../models/Task");
const User = require("../models/User");
const createHttpError = require("../utils/httpError");
const {
  escapeRegex,
  isValidEmail,
  normalizeEmail,
  parsePagination,
  pickFields,
} = require("../utils/validation");

const populateDepartment = (query) =>
  query.populate("department", "name description");

const isStudentRole = (req) => req.userRole === "student";

const ensureCanAccessStudent = (req, student) => {
  if (!isStudentRole(req)) {
    return;
  }

  if (student.email !== req.user.email) {
    throw createHttpError(403, "You can only access your own student profile");
  }
};

const ensureDepartmentExists = async (departmentId) => {
  if (!departmentId) {
    return;
  }

  const departmentExists = await Department.exists({ _id: departmentId });
  if (!departmentExists) {
    throw createHttpError(404, "Department not found");
  }
};

const createAttendanceCounts = () => ({
  present: 0,
  absent: 0,
  late: 0,
  excused: 0,
});

const calculatePercentage = (value, total) =>
  total > 0 ? Number(((value / total) * 100).toFixed(2)) : 0;

const activityFilter = (req, studentId) => ({
  student: studentId,
  ...(req.userRole === "admin" ? {} : { createdBy: req.user._id }),
});

const validateAccountPassword = (password) => {
  if (typeof password !== "string" || password.length < 8) {
    throw createHttpError(
      400,
      "Student account password must contain at least 8 characters",
    );
  }
};

const ensureStudentAccount = async ({ fullName, email, password }) => {
  const existingUser = await User.findOne({ email });

  if (existingUser) {
    const role = existingUser.role === "user" ? "student" : existingUser.role;
    if (role !== "student") {
      throw createHttpError(
        409,
        "This email already belongs to another staff or admin account",
      );
    }

    return { user: existingUser, created: false };
  }

  validateAccountPassword(password);

  const user = await User.create({
    fullName,
    email,
    password: await bcrypt.hash(password, 12),
    role: "student",
  });
  return { user, created: true };
};

exports.getStudents = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = {};

  if (isStudentRole(req)) {
    filter.email = req.user.email;
  }

  if (req.query.search) {
    const search = new RegExp(escapeRegex(req.query.search), "i");
    filter.$or = [
      { studentId: search },
      { fullName: search },
      { email: search },
    ];
  }

  if (req.query.department) {
    filter.department = req.query.department;
  }

  if (req.query.year) {
    filter.year = req.query.year;
  }

  const [students, total] = await Promise.all([
    populateDepartment(
      Student.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
    ),
    Student.countDocuments(filter),
  ]);

  res.json({
    students,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.getStudentById = async (req, res) => {
  const student = await populateDepartment(Student.findById(req.params.id));

  if (!student) {
    throw createHttpError(404, "Student not found");
  }

  ensureCanAccessStudent(req, student);

  res.json(student);
};

exports.getStudentOverview = async (req, res) => {
  const student = await populateDepartment(Student.findById(req.params.id));

  if (!student) {
    throw createHttpError(404, "Student not found");
  }

  ensureCanAccessStudent(req, student);

  const noteFilter = activityFilter(req, student._id);
  const taskFilter = activityFilter(req, student._id);
  const now = new Date();

  const [
    attendanceRows,
    recentAttendance,
    noteTotal,
    recentNotes,
    taskRows,
    overdueTasks,
    upcomingTasks,
  ] = await Promise.all([
    Attendance.aggregate([
      { $match: { student: student._id } },
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]),
    Attendance.find({ student: student._id })
      .sort({ date: -1, createdAt: -1 })
      .limit(5)
      .populate("student", "studentId fullName"),
    Note.countDocuments(noteFilter),
    Note.find(noteFilter)
      .sort({ updatedAt: -1 })
      .limit(3)
      .populate("student", "studentId fullName"),
    Task.aggregate([
      { $match: taskFilter },
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]),
    Task.countDocuments({
      ...taskFilter,
      status: { $ne: "completed" },
      dueDate: { $ne: null, $lt: now },
    }),
    Task.find({
      ...taskFilter,
      status: { $ne: "completed" },
      dueDate: { $ne: null },
    })
      .sort({ dueDate: 1, createdAt: -1 })
      .limit(5)
      .populate("student", "studentId fullName"),
  ]);

  const attendanceCounts = createAttendanceCounts();
  for (const row of attendanceRows) {
    if (Object.prototype.hasOwnProperty.call(attendanceCounts, row._id)) {
      attendanceCounts[row._id] = row.count;
    }
  }

  const taskCounts = {
    pending: 0,
    inProgress: 0,
    completed: 0,
  };
  for (const row of taskRows) {
    if (row._id === "in-progress") {
      taskCounts.inProgress = row.count;
    } else if (Object.prototype.hasOwnProperty.call(taskCounts, row._id)) {
      taskCounts[row._id] = row.count;
    }
  }

  const totalAttendance = Object.values(attendanceCounts).reduce(
    (total, count) => total + count,
    0,
  );
  const totalTasks = Object.values(taskCounts).reduce(
    (total, count) => total + count,
    0,
  );

  res.json({
    student,
    attendance: {
      counts: attendanceCounts,
      totalRecords: totalAttendance,
      attendanceRate: calculatePercentage(
        attendanceCounts.present + attendanceCounts.late,
        totalAttendance,
      ),
      recent: recentAttendance,
    },
    notes: {
      total: noteTotal,
      recent: recentNotes,
    },
    tasks: {
      total: totalTasks,
      ...taskCounts,
      overdue: overdueTasks,
      upcoming: upcomingTasks,
    },
  });
};

exports.createStudent = async (req, res) => {
  const data = pickFields(req.body, [
    "studentId",
    "fullName",
    "gender",
    "email",
    "phone",
    "department",
    "year",
  ]);
  const createAccount = req.body.createAccount === true;
  const accountPassword = req.body.accountPassword;

  if (!data.studentId || !data.fullName || !data.email || !data.department) {
    throw createHttpError(
      400,
      "Student ID, full name, email, and department are required",
    );
  }

  data.email = normalizeEmail(data.email);
  if (!isValidEmail(data.email)) {
    throw createHttpError(400, "A valid email is required");
  }

  await ensureDepartmentExists(data.department);

  const existingStudent = await Student.exists({
    $or: [{ studentId: data.studentId }, { email: data.email }],
  });
  if (existingStudent) {
    throw createHttpError(409, "Student ID or email already exists");
  }

  const student = new Student(data);
  await student.validate();

  let accountCreated = false;
  if (createAccount) {
    const account = await ensureStudentAccount({
      fullName: data.fullName.trim(),
      email: data.email,
      password: accountPassword,
    });
    accountCreated = account.created;
  }

  await student.save();
  await student.populate("department", "name description");
  res.status(201).json({
    ...student.toObject(),
    accountCreated,
  });
};

exports.updateStudent = async (req, res) => {
  const updates = pickFields(req.body, [
    "studentId",
    "fullName",
    "gender",
    "email",
    "phone",
    "department",
    "year",
  ]);

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid fields were provided");
  }

  await ensureDepartmentExists(updates.department);

  const student = await populateDepartment(
    Student.findByIdAndUpdate(req.params.id, updates, {
      returnDocument: "after",
      runValidators: true,
    }),
  );

  if (!student) {
    throw createHttpError(404, "Student not found");
  }

  res.json(student);
};

exports.deleteStudent = async (req, res) => {
  const student = await Student.findById(req.params.id);

  if (!student) {
    throw createHttpError(404, "Student not found");
  }

  const [attendances, notes, tasks] = await Promise.all([
    Attendance.countDocuments({ student: student._id }),
    Note.countDocuments({ student: student._id }),
    Task.countDocuments({ student: student._id }),
  ]);

  if (attendances || notes || tasks) {
    const error = createHttpError(
      409,
      "Student cannot be deleted while related records exist",
    );
    error.details = { attendances, notes, tasks };
    throw error;
  }

  await student.deleteOne();
  res.json({ message: "Student deleted" });
};
