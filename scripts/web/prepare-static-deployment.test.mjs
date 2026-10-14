import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const script = fileURLToPath(
  new URL("./prepare-static-deployment.mjs", import.meta.url),
);

function fixture(t) {
  const directory = mkdtempSync(join(tmpdir(), "wendara-web-deploy-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const dist = join(directory, "dist");
  mkdirSync(join(dist, "runtime"), { recursive: true });
  writeFileSync(join(dist, "index.html"), "<html>Release application</html>");
  writeFileSync(join(dist, "app.js"), "console.log('unchanged release');");
  writeFileSync(
    join(dist, "runtime/landing-config.json"),
    JSON.stringify({ version: 1, legalApiBaseUrl: null }),
  );
  writeFileSync(
    join(dist, "_headers"),
    "/runtime/*\n  Cache-Control: no-store\n",
  );
  const config = join(directory, "wrangler.json");
  const env = {
    ...process.env,
    TARGET_ENVIRONMENT: "prod",
    LEGAL_API_BASE_URL: "https://api.example",
    WEB_WORKER_NAME: "wendara-landing",
    WEB_HOSTNAME: "wendara.example",
  };
  return {
    dist,
    config,
    run: (overrides = {}) =>
      spawnSync(process.execPath, [script, dist, config], {
        env: { ...env, ...overrides },
        encoding: "utf8",
      }),
  };
}

test("configuration-only publication changes the API without changing compiled application files", (t) => {
  const f = fixture(t);
  const application = readFileSync(join(f.dist, "app.js"));
  assert.equal(f.run().status, 0);
  assert.equal(
    f.run({ LEGAL_API_BASE_URL: "https://replacement.example" }).status,
    0,
  );
  assert.equal(
    JSON.parse(readFileSync(join(f.dist, "runtime/landing-config.json")))
      .legalApiBaseUrl,
    "https://replacement.example",
  );
  assert.deepEqual(readFileSync(join(f.dist, "app.js")), application);
  const config = JSON.parse(readFileSync(f.config));
  assert.equal(config.assets.not_found_handling, "single-page-application");
  assert.equal(config.workers_dev, false);
});

test("DEV is excluded from indexing", (t) => {
  const f = fixture(t);
  assert.equal(f.run({ TARGET_ENVIRONMENT: "dev" }).status, 0);
  assert.match(
    readFileSync(join(f.dist, "_headers"), "utf8"),
    /X-Robots-Tag: noindex, nofollow/,
  );
  assert.match(
    readFileSync(join(f.dist, "robots.txt"), "utf8"),
    /Disallow: \//,
  );
});

test("deployment rejects missing or unsafe API configuration", (t) => {
  const f = fixture(t);
  for (const value of [
    "",
    "http://api.example",
    "https://user:secret@api.example",
    "https://api.example/path",
  ]) {
    assert.notEqual(f.run({ LEGAL_API_BASE_URL: value }).status, 0);
  }
});

test("deployment rejects source maps and credentials in the public package", (t) => {
  const f = fixture(t);
  for (const file of ["app.js.map", ".env", ".npmrc.ci"]) {
    writeFileSync(join(f.dist, file), "must not be public");
    assert.notEqual(f.run().status, 0);
    rmSync(join(f.dist, file));
  }
});

test("older releases without the runtime contract cannot be reconfigured silently", (t) => {
  const f = fixture(t);
  writeFileSync(
    join(f.dist, "runtime/landing-config.json"),
    JSON.stringify({ version: 2 }),
  );
  assert.notEqual(f.run().status, 0);
});
