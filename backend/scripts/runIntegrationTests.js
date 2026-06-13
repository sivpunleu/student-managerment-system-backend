const { spawnSync } = require("child_process");

const result = spawnSync(
  process.execPath,
  ["--test", "tests/integration.test.js"],
  {
    stdio: "inherit",
    env: {
      ...process.env,
      RUN_INTEGRATION_TESTS: "1",
    },
  },
);

process.exit(result.status ?? 1);
