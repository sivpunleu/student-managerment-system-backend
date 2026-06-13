const test = require("node:test");
const assert = require("node:assert/strict");
const {
  escapeRegex,
  formatDateOnly,
  getTodayDateOnly,
  isValidEmail,
  normalizeEmail,
  parseDateOnly,
  parsePagination,
  pickFields,
} = require("../utils/validation");

test("normalizes and validates email addresses", () => {
  assert.equal(normalizeEmail("  USER@Example.COM "), "user@example.com");
  assert.equal(isValidEmail("user@example.com"), true);
  assert.equal(isValidEmail("not-an-email"), false);
});

test("escapes regular expression characters in search input", () => {
  assert.equal(escapeRegex("student.*"), "student\\.\\*");
});

test("limits pagination and provides defaults", () => {
  assert.deepEqual(parsePagination({}), { page: 1, limit: 20, skip: 0 });
  assert.deepEqual(parsePagination({ page: "3", limit: "500" }), {
    page: 3,
    limit: 100,
    skip: 200,
  });
});

test("picks only allowed request fields", () => {
  assert.deepEqual(
    pickFields({ title: "Task", role: "admin" }, ["title"]),
    { title: "Task" },
  );
});

test("parses only valid YYYY-MM-DD dates without timezone shifts", () => {
  assert.equal(
    parseDateOnly("2026-06-13").toISOString(),
    "2026-06-13T00:00:00.000Z",
  );
  assert.equal(parseDateOnly("2026-06-13T15:30:00+07:00"), null);
  assert.equal(parseDateOnly("2026-02-30"), null);
  assert.equal(formatDateOnly(parseDateOnly("2026-06-13")), "2026-06-13");
});

test("gets a date-only value for a configured timezone", () => {
  assert.match(getTodayDateOnly("Asia/Bangkok"), /^\d{4}-\d{2}-\d{2}$/);
});
