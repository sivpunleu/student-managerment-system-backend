const express = require("express");
const router = express.Router();

const {
  getClassGroups,
  getClassGroupById,
  createClassGroup,
  updateClassGroup,
  deleteClassGroup,
} = require("../controllers/classGroupController");
const { protect, authorize } = require("../middleware/authMiddleware");

router.use(protect);

router.get("/", getClassGroups);
router.get("/:id", getClassGroupById);
router.post("/", authorize("admin"), createClassGroup);
router.put("/:id", authorize("admin"), updateClassGroup);
router.delete("/:id", authorize("admin"), deleteClassGroup);

module.exports = router;
