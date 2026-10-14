import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";

const [distDirectory, configPath] = process.argv.slice(2);
const {
  TARGET_ENVIRONMENT,
  LEGAL_API_BASE_URL,
  WEB_WORKER_NAME,
  WEB_HOSTNAME,
} = process.env;

if (
  !distDirectory ||
  !configPath ||
  !["dev", "prod"].includes(TARGET_ENVIRONMENT)
) {
  throw new Error(
    "A dist directory, config path and dev/prod target are required",
  );
}
if (!/^[a-z][a-z0-9-]{0,62}$/.test(WEB_WORKER_NAME ?? "")) {
  throw new Error("WEB_WORKER_NAME must be a valid Worker name");
}
if (
  !/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/i.test(WEB_HOSTNAME ?? "")
) {
  throw new Error("WEB_HOSTNAME must be a hostname without a protocol or path");
}

const api = new URL(LEGAL_API_BASE_URL);
if (
  api.protocol !== "https:" ||
  api.username ||
  api.password ||
  api.pathname !== "/" ||
  api.search ||
  api.hash
) {
  throw new Error("LEGAL_API_BASE_URL must be an HTTPS origin");
}

const dist = resolve(distDirectory);
if (!statSync(join(dist, "index.html")).isFile()) {
  throw new Error("The release package must contain index.html");
}
const runtimePath = join(dist, "runtime/landing-config.json");
const runtime = JSON.parse(readFileSync(runtimePath, "utf8"));
if (runtime.version !== 1) {
  throw new Error(
    "This release does not support the runtime configuration contract",
  );
}

function validateFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (
      entry.isSymbolicLink() ||
      /^(?:\.env(?:\..*)?|\.npmrc(?:\..*)?|\.git|node_modules|src|test)$/.test(
        entry.name,
      ) ||
      entry.name.endsWith(".map")
    ) {
      throw new Error("The release package contains a forbidden public file");
    }
    if (entry.isDirectory()) validateFiles(join(directory, entry.name));
  }
}
validateFiles(dist);

writeFileSync(
  runtimePath,
  JSON.stringify({ version: 1, legalApiBaseUrl: api.origin }, null, 2) + "\n",
);
const headersPath = join(dist, "_headers");
let headers = readFileSync(headersPath, "utf8");
if (TARGET_ENVIRONMENT === "dev") {
  headers += "\n/*\n  X-Robots-Tag: noindex, nofollow\n";
  writeFileSync(join(dist, "robots.txt"), "User-agent: *\nDisallow: /\n");
}
writeFileSync(headersPath, headers);
writeFileSync(
  configPath,
  JSON.stringify(
    {
      name: WEB_WORKER_NAME,
      compatibility_date: "2026-10-14",
      workers_dev: false,
      preview_urls: false,
      routes: [{ pattern: WEB_HOSTNAME, custom_domain: true }],
      assets: {
        directory: dist,
        not_found_handling: "single-page-application",
      },
    },
    null,
    2,
  ) + "\n",
);
