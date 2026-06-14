const express = require("express");
const router = express.Router();

const {
  register,
  login,
  refresh,
  logout,
  getMe,
  updateProfile,
  updateAvatar,
  deleteAvatar,
  getAvatar,
  changePassword,
  forgotPassword,
  resetPassword,
} = require("../controllers/authController");
const { protect } = require("../middleware/authMiddleware");
const createRateLimiter = require("../middleware/rateLimitMiddleware");

const authLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
});

router.post("/register", authLimiter, register);
router.post("/login", authLimiter, login);
router.post("/refresh", authLimiter, refresh);
router.post("/forgot-password", authLimiter, forgotPassword);
router.post("/reset-password", authLimiter, resetPassword);
router.get("/avatar/:userId", getAvatar);
router.get("/me", protect, getMe);
router.put("/profile", protect, updateProfile);
router.put("/profile/avatar", protect, updateAvatar);
router.delete("/profile/avatar", protect, deleteAvatar);
router.put("/change-password", protect, changePassword);
router.post("/logout", protect, logout);

module.exports = router;
