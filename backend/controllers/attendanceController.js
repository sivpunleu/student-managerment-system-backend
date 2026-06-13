const mongoose = require("mongoose");
const Attendance = require("../models/Attendance");
const Student = require("../models/Student");
const createHttpError = require("../utils/httpError");
const {
  formatDateOnly,
  getTodayDateOnly,
  parseDateOnly,
  parsePagination,
  pickFields,
} = require("../utils/validation");

const populateAttendance = (query) =>
  query
    .populate({
      path: "student",
      select: "studentId fullName email department year",
      populate: { path: "department", select: "name" },
    })
    .populate("markedBy", "fullName email");

const createEmptyCounts = () => ({
  present: 0,
  absent: 0,
  late: 0,
  excused: 0,
});

const calculatePercentage = (value, total) =>
  total > 0 ? Number(((value / total) * 100).toFixed(2)) : 0;

const attendanceStatuses = new Set([
  "present",
  "absent",
  "late",
  "excused",
]);

const parseDateRange = (fromValue, toValue) => {
  const from = parseDateOnly(fromValue);
  const to = parseDateOnly(toValue);

  if (!from || !to) {
    throw createHttpError(400, "Dates must use YYYY-MM-DD format");
  }

  if (from > to) {
    throw createHttpError(400, "From date cannot be after to date");
  }

  const days = Math.floor((to - from) / 86400000) + 1;
  if (days > 366) {
    throw createHttpError(400, "Attendance report cannot exceed 366 days");
  }

  return { from, to, days };
};

exports.getAttendances = async (req, res) => {
  const { page, limit, skip } = parsePagination(req.query);
  const filter = {};

  if (req.query.student) {
    filter.student = req.query.student;
  }

  if (req.query.status) {
    filter.status = req.query.status;
  }

  if (req.query.from || req.query.to) {
    filter.date = {};

    if (req.query.from) {
      const from = parseDateOnly(req.query.from);
      if (!from) {
        throw createHttpError(400, "From date must use YYYY-MM-DD format");
      }
      filter.date.$gte = from;
    }

    if (req.query.to) {
      const to = parseDateOnly(req.query.to);
      if (!to) {
        throw createHttpError(400, "To date must use YYYY-MM-DD format");
      }
      filter.date.$lte = to;
    }

    if (filter.date.$gte && filter.date.$lte && filter.date.$gte > filter.date.$lte) {
      throw createHttpError(400, "From date cannot be after to date");
    }
  }

  const [attendances, total] = await Promise.all([
    populateAttendance(
      Attendance.find(filter)
        .sort({ date: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit),
    ),
    Attendance.countDocuments(filter),
  ]);

  res.json({
    attendances,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  });
};

exports.getAttendanceById = async (req, res) => {
  const attendance = await populateAttendance(
    Attendance.findById(req.params.id),
  );

  if (!attendance) {
    throw createHttpError(404, "Attendance record not found");
  }

  res.json(attendance);
};

exports.createAttendance = async (req, res) => {
  const data = pickFields(req.body, ["student", "date", "status", "note"]);
  const date = parseDateOnly(data.date);

  if (!data.student || !date || !data.status) {
    throw createHttpError(
      400,
      "Student, date in YYYY-MM-DD format, and status are required",
    );
  }

  const studentExists = await Student.exists({ _id: data.student });
  if (!studentExists) {
    throw createHttpError(404, "Student not found");
  }

  const existingAttendance = await Attendance.exists({
    student: data.student,
    date,
  });
  if (existingAttendance) {
    throw createHttpError(
      409,
      "Attendance is already recorded for this student and date",
    );
  }

  const attendance = await Attendance.create({
    ...data,
    date,
    markedBy: req.user._id,
  });

  await attendance.populate([
    {
      path: "student",
      select: "studentId fullName email department year",
      populate: { path: "department", select: "name" },
    },
    { path: "markedBy", select: "fullName email" },
  ]);

  res.status(201).json(attendance);
};

exports.bulkUpsertAttendance = async (req, res) => {
  const date = parseDateOnly(req.body.date);
  const records = req.body.records;

  if (!date) {
    throw createHttpError(400, "Date must use YYYY-MM-DD format");
  }

  if (!Array.isArray(records) || records.length === 0) {
    throw createHttpError(400, "At least one attendance record is required");
  }

  if (records.length > 500) {
    throw createHttpError(400, "A maximum of 500 records can be saved at once");
  }

  const studentIds = [];
  const seenStudentIds = new Set();

  for (const record of records) {
    const studentId = record?.student?.toString();
    const note = record?.note?.toString() ?? "";

    if (!studentId || !mongoose.isValidObjectId(studentId)) {
      throw createHttpError(400, "Every record requires a valid student ID");
    }
    if (!attendanceStatuses.has(record.status)) {
      throw createHttpError(400, `Invalid attendance status for ${studentId}`);
    }
    if (note.length > 500) {
      throw createHttpError(400, "Attendance notes cannot exceed 500 characters");
    }
    if (seenStudentIds.has(studentId)) {
      throw createHttpError(400, "Each student can only appear once per batch");
    }

    seenStudentIds.add(studentId);
    studentIds.push(studentId);
  }

  const existingStudents = await Student.countDocuments({
    _id: { $in: studentIds },
  });
  if (existingStudents !== studentIds.length) {
    throw createHttpError(404, "One or more students were not found");
  }

  await Attendance.bulkWrite(
    records.map((record) => ({
      updateOne: {
        filter: { student: record.student, date },
        update: {
          $set: {
            status: record.status,
            note: record.note?.toString().trim() ?? "",
            markedBy: req.user._id,
          },
        },
        upsert: true,
      },
    })),
    { ordered: false },
  );

  const attendances = await populateAttendance(
    Attendance.find({
      student: { $in: studentIds },
      date,
    }).sort({ createdAt: 1 }),
  );

  res.json({
    message: `${attendances.length} attendance records saved`,
    count: attendances.length,
    attendances,
  });
};

exports.updateAttendance = async (req, res) => {
  const updates = pickFields(req.body, ["student", "date", "status", "note"]);

  if (Object.keys(updates).length === 0) {
    throw createHttpError(400, "No valid fields were provided");
  }

  if (updates.date !== undefined) {
    updates.date = parseDateOnly(updates.date);
    if (!updates.date) {
      throw createHttpError(
        400,
        "Attendance date must use YYYY-MM-DD format",
      );
    }
  }

  if (updates.student) {
    const studentExists = await Student.exists({ _id: updates.student });
    if (!studentExists) {
      throw createHttpError(404, "Student not found");
    }
  }

  const currentAttendance = await Attendance.findById(req.params.id);
  if (!currentAttendance) {
    throw createHttpError(404, "Attendance record not found");
  }

  const duplicateAttendance = await Attendance.exists({
    _id: { $ne: currentAttendance._id },
    student: updates.student || currentAttendance.student,
    date: updates.date || currentAttendance.date,
  });
  if (duplicateAttendance) {
    throw createHttpError(
      409,
      "Attendance is already recorded for this student and date",
    );
  }

  updates.markedBy = req.user._id;

  const attendance = await populateAttendance(
    Attendance.findByIdAndUpdate(req.params.id, updates, {
      returnDocument: "after",
      runValidators: true,
    }),
  );

  res.json(attendance);
};

exports.deleteAttendance = async (req, res) => {
  const attendance = await Attendance.findByIdAndDelete(req.params.id);

  if (!attendance) {
    throw createHttpError(404, "Attendance record not found");
  }

  res.json({ message: "Attendance record deleted" });
};

exports.getAttendanceSummary = async (req, res) => {
  const dateValue =
    req.query.date ||
    getTodayDateOnly(process.env.APP_TIME_ZONE || "Asia/Bangkok");
  const date = parseDateOnly(dateValue);

  if (!date) {
    throw createHttpError(400, "Date must use YYYY-MM-DD format");
  }

  const [statusRows, totalStudents] = await Promise.all([
    Attendance.aggregate([
      { $match: { date } },
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]),
    Student.countDocuments(),
  ]);

  const counts = createEmptyCounts();
  for (const row of statusRows) {
    if (Object.prototype.hasOwnProperty.call(counts, row._id)) {
      counts[row._id] = row.count;
    }
  }

  const recorded = Object.values(counts).reduce(
    (total, count) => total + count,
    0,
  );
  const attended = counts.present + counts.late;

  res.json({
    date: dateValue,
    totalStudents,
    recorded,
    unmarked: Math.max(totalStudents - recorded, 0),
    counts,
    attendanceRate: calculatePercentage(attended, recorded),
    completionRate: calculatePercentage(recorded, totalStudents),
  });
};

exports.getAttendanceReport = async (req, res) => {
  const { from, to, days } = parseDateRange(req.query.from, req.query.to);
  const match = { date: { $gte: from, $lte: to } };

  if (req.query.student) {
    if (!mongoose.isValidObjectId(req.query.student)) {
      throw createHttpError(400, "Invalid student ID");
    }
    match.student = new mongoose.Types.ObjectId(req.query.student);
  }

  const rows = await Attendance.aggregate([
    { $match: match },
    {
      $group: {
        _id: { date: "$date", status: "$status" },
        count: { $sum: 1 },
      },
    },
    { $sort: { "_id.date": 1 } },
  ]);

  const dailyMap = new Map();

  for (const row of rows) {
    const dateKey = formatDateOnly(row._id.date);
    const counts = dailyMap.get(dateKey) || createEmptyCounts();
    counts[row._id.status] = row.count;
    dailyMap.set(dateKey, counts);
  }

  const daily = [];
  const totals = createEmptyCounts();

  for (let index = 0; index < days; index += 1) {
    const date = new Date(from);
    date.setUTCDate(from.getUTCDate() + index);
    const dateKey = formatDateOnly(date);
    const counts = dailyMap.get(dateKey) || createEmptyCounts();
    const recorded = Object.values(counts).reduce(
      (total, count) => total + count,
      0,
    );

    for (const status of Object.keys(totals)) {
      totals[status] += counts[status];
    }

    daily.push({
      date: dateKey,
      counts,
      recorded,
      attendanceRate: calculatePercentage(
        counts.present + counts.late,
        recorded,
      ),
    });
  }

  const totalRecords = Object.values(totals).reduce(
    (total, count) => total + count,
    0,
  );

  res.json({
    from: formatDateOnly(from),
    to: formatDateOnly(to),
    student: req.query.student || null,
    totals,
    totalRecords,
    attendanceRate: calculatePercentage(
      totals.present + totals.late,
      totalRecords,
    ),
    daily,
  });
};
