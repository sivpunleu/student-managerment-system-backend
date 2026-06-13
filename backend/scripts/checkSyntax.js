const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const projectRoot = path.resolve(__dirname, "..");
const targets = [
  "app.js",
  "server.js",
  "config",
  "controllers",
  "middleware",
  "models",
  "routes",
  "scripts",
  "utils",
  "tests",
];

const collectJavaScriptFiles = (targetPath) => {
  const stat = fs.statSync(targetPath);

  if (stat.isFile()) {
    return targetPath.endsWith(".js") ? [targetPath] : [];
  }

  return fs.readdirSync(targetPath, { withFileTypes: true }).flatMap((entry) =>
    collectJavaScriptFiles(path.join(targetPath, entry.name)),
  );
};

const files = targets.flatMap((target) => {
  const targetPath = path.join(projectRoot, target);
  return fs.existsSync(targetPath) ? collectJavaScriptFiles(targetPath) : [];
});

let failed = false;

for (const file of files) {
  const result = spawnSync(process.execPath, ["--check", file], {
    encoding: "utf8",
  });

  if (result.status !== 0) {
    failed = true;
    process.stderr.write(result.stderr);
  }
}

if (failed) {
  process.exit(1);
}

console.log(`Syntax check passed for ${files.length} JavaScript files`);
