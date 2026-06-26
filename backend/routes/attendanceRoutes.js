const express = require("express");
const {
  getAttendances,
  getAttendanceById,
  createAttendance,
  bulkUpsertAttendance,
  updateAttendance,
  deleteAttendance,
  getAttendanceSummary,
  getAttendanceReport,
} = require("../controllers/attendanceController");
const { protect, authorize } = require("../middleware/authMiddleware");

const router = express.Router();

router.use(protect);

router.get("/", getAttendances);
router.get("/summary", getAttendanceSummary);
router.get("/report", getAttendanceReport);
router.get("/:id", getAttendanceById);
router.post("/bulk", authorize("admin", "staff"), bulkUpsertAttendance);
router.post("/", authorize("admin", "staff"), createAttendance);
router.put("/:id", authorize("admin", "staff"), updateAttendance);
router.delete("/:id", authorize("admin", "staff"), deleteAttendance);

module.exports = router;
