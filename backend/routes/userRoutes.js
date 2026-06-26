const express = require("express");
const router = express.Router();

const {
  getUsers,
  updateUserRole,
  updateUserStatus,
  resetUserPassword,
} = require("../controllers/userController");
const { protect, authorize } = require("../middleware/authMiddleware");

router.use(protect, authorize("admin"));

router.get("/", getUsers);
router.patch("/:id/role", updateUserRole);
router.patch("/:id/status", updateUserStatus);
router.post("/:id/reset-password", resetUserPassword);

module.exports = router;
