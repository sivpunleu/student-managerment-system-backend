const attempts = new Map();
let requestCount = 0;

const cleanupExpiredEntries = (now) => {
  requestCount += 1;

  if (requestCount % 100 !== 0) {
    return;
  }

  for (const [key, value] of attempts.entries()) {
    if (value.resetAt <= now) {
      attempts.delete(key);
    }
  }
};

const createRateLimiter = ({ windowMs, max }) => (req, res, next) => {
  const now = Date.now();
  const key = `${req.ip}:${req.path}`;
  const current = attempts.get(key);

  cleanupExpiredEntries(now);

  if (!current || current.resetAt <= now) {
    attempts.set(key, { count: 1, resetAt: now + windowMs });
    return next();
  }

  current.count += 1;

  if (current.count > max) {
    const retryAfter = Math.ceil((current.resetAt - now) / 1000);
    res.set("Retry-After", String(retryAfter));

    return res.status(429).json({
      message: "Too many attempts. Please try again later",
    });
  }

  next();
};

module.exports = createRateLimiter;
