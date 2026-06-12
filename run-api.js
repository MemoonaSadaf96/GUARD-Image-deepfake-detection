/**
 * Start uvicorn with project .venv Python when present, else system python.
 */
const { spawn, spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const venvPython =
  process.platform === "win32"
    ? path.join(root, ".venv", "Scripts", "python.exe")
    : path.join(root, ".venv", "bin", "python");

function resolvePython() {
  if (fs.existsSync(venvPython)) return venvPython;
  if (process.platform === "win32") return "python";
  return "python3";
}

function shouldForceCpuInference() {
  const explicit = String(process.env.FORCE_CPU_INFERENCE || "").trim().toLowerCase();
  if (["1", "true", "yes"].includes(explicit)) return true;
  if (["0", "false", "no"].includes(explicit)) {
    try {
      const probe = spawnSync("nvidia-smi", ["-L"], {
        stdio: "pipe",
        encoding: "utf8",
      });
      if (probe.status === 0 && String(probe.stdout || "").trim().length > 0) {
        return false;
      }
    } catch {
      /* fall back to CPU below */
    }
  }
  return true;
}

const reload = process.env.API_RELOAD === "0" ? [] : ["--reload"];
const forceCpuInference = shouldForceCpuInference();

if (forceCpuInference) {
  console.log(
    "[api] TensorFlow CPU mode enabled (portable default; set FORCE_CPU_INFERENCE=0 to try GPU).",
  );
}

const child = spawn(
  resolvePython(),
  [
    "-m",
    "uvicorn",
    "api.main:app",
    ...reload,
    "--host",
    "0.0.0.0",
    "--port",
    "8000",
    "--log-level",
    "info",
  ],
  {
    cwd: root,
    stdio: "inherit",
    env: {
      ...process.env,
      ...(forceCpuInference ? { FORCE_CPU_INFERENCE: "1" } : {}),
      PYTHONUNBUFFERED: "1",
      CREWAI_VERBOSE: process.env.CREWAI_VERBOSE || "true",
      ...(forceCpuInference
        ? { CUDA_VISIBLE_DEVICES: "-1", TF_CPP_MIN_LOG_LEVEL: "2" }
        : {}),
    },
  },
);

child.on("exit", (code) => process.exit(code ?? 1));
