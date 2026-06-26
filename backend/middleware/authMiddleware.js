const jwt = require("jsonwebtoken");
const User = require("../models/User");

exports.protect = async (req, res, next) => {
  const authorization = req.headers.authorization;

  if (!authorization || !authorization.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authentication token is required" });
  }

  const token = authorization.split(" ")[1];
  let decoded;

  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    return res.status(401).json({ message: "Invalid or expired token" });
  }

  const user = await User.findById(decoded.id).select("+tokenVersion");

  if (!user || (decoded.version || 0) !== (user.tokenVersion || 0)) {
    return res.status(401).json({ message: "User no longer exists" });
  }

  req.user = user;
  req.userRole = user.role === "user" ? "student" : user.role;
  next();
};

exports.authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.userRole)) {
    return res.status(403).json({
      message: "You do not have permission to perform this action",
    });
  }

  next();
};
