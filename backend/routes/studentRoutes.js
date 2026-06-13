const express = require("express");
const router = express.Router();

const {
  getStudents,
  getStudentById,
  getStudentOverview,
  createStudent,
  updateStudent,
  deleteStudent,
} = require("../controllers/studentController");
const { protect, authorize } = require("../middleware/authMiddleware");

router.use(protect);

router.get("/", getStudents);
router.get("/:id/overview", getStudentOverview);
router.get("/:id", getStudentById);
router.post("/", authorize("admin"), createStudent);
router.put("/:id", authorize("admin"), updateStudent);
router.delete("/:id", authorize("admin"), deleteStudent);

module.exports = router;
