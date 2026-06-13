const test = require("node:test");
const assert = require("node:assert/strict");
const app = require("../app");

const withServer = async (callback) => {
  const server = app.listen(0);
  await new Promise((resolve) => server.once("listening", resolve));

  const { port } = server.address();

  try {
    await callback(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
};

test("health endpoint reports that the API is available", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/health`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.status, "ok");
  });
});

test("protected routes reject requests without a token", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/students`);
    const body = await response.json();

    assert.equal(response.status, 401);
    assert.equal(body.message, "Authentication token is required");
  });
});

test("registration validates input before accessing the database", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        fullName: "",
        email: "invalid",
        password: "123",
        role: "admin",
      }),
    });
    const body = await response.json();

    assert.equal(response.status, 400);
    assert.match(body.message, /Full name/);
  });
});

test("unknown routes return a JSON 404 response", async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/unknown`);
    const body = await response.json();

    assert.equal(response.status, 404);
    assert.match(body.message, /Route not found/);
  });
});
