#!/usr/bin/env bash
set -euo pipefail

SERVER_FILE="src/server.ts"
ENV_FILE=".env.example"

if [[ ! -f "$SERVER_FILE" ]]; then
  echo "ERROR: $SERVER_FILE not found. Run this from the ai_world repo root." >&2
  exit 1
fi

cp "$SERVER_FILE" "${SERVER_FILE}.bak.$(date +%Y%m%d%H%M%S)"

python3 - <<'PY'
from pathlib import Path

path = Path("src/server.ts")
text = path.read_text()

if "AI_WORLD_FEED_REFRESH_MINUTES" in text:
    print("30-minute feed refresh logic already appears to be present.")
    raise SystemExit(0)

# Add child_process import. This scheduler calls the existing refresh script,
# so it does not depend on feedService internal function names.
if 'from "node:child_process"' not in text and "from 'node:child_process'" not in text:
    lines = text.splitlines()
    insert_at = 0
    while insert_at < len(lines) and lines[insert_at].startswith("import "):
        insert_at += 1
    lines.insert(insert_at, 'import { spawn } from "node:child_process";')
    text = "\n".join(lines) + "\n"

scheduler = r'''

const feedRefreshMinutes = Number.parseInt(
  process.env.AI_WORLD_FEED_REFRESH_MINUTES ?? "30",
  10,
);

const feedRefreshIntervalMs =
  Number.isFinite(feedRefreshMinutes) && feedRefreshMinutes > 0
    ? feedRefreshMinutes * 60 * 1000
    : 30 * 60 * 1000;

let feedRefreshRunning = false;

function refreshFeedsInBackground(reason: string): void {
  if (feedRefreshRunning) {
    console.log(`[feeds] Skipping ${reason} refresh because a previous refresh is still running.`);
    return;
  }

  feedRefreshRunning = true;
  const startedAt = new Date();

  console.log(`[feeds] Starting ${reason} feed refresh at ${startedAt.toISOString()}`);

  const child = spawn("npm", ["run", "refresh:feeds", "--silent"], {
    cwd: process.cwd(),
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  });

  child.stdout.on("data", (data: Buffer) => {
    process.stdout.write(`[feeds] ${data.toString()}`);
  });

  child.stderr.on("data", (data: Buffer) => {
    process.stderr.write(`[feeds] ${data.toString()}`);
  });

  child.on("error", (error: Error) => {
    feedRefreshRunning = false;
    console.error(`[feeds] Refresh failed to start: ${error.message}`);
  });

  child.on("close", (code: number | null) => {
    feedRefreshRunning = false;
    const finishedAt = new Date();
    const elapsedSeconds = Math.round((finishedAt.getTime() - startedAt.getTime()) / 1000);

    if (code === 0) {
      console.log(`[feeds] Completed ${reason} feed refresh in ${elapsedSeconds}s.`);
    } else {
      console.warn(`[feeds] ${reason} feed refresh exited with code ${code} after ${elapsedSeconds}s.`);
    }
  });
}

refreshFeedsInBackground("startup");

setInterval(() => {
  refreshFeedsInBackground("scheduled");
}, feedRefreshIntervalMs);
'''

# Put scheduler before app.listen if present, otherwise append.
listen_markers = [
    "\napp.listen(",
    "\nserver.listen(",
]

insert_pos = -1
for marker in listen_markers:
    insert_pos = text.find(marker)
    if insert_pos != -1:
        break

if insert_pos == -1:
    text = text.rstrip() + scheduler + "\n"
else:
    text = text[:insert_pos] + scheduler + text[insert_pos:]

path.write_text(text)
print("Added background feed refresh scheduler to src/server.ts")
PY

if [[ -f "$ENV_FILE" ]]; then
  cp "$ENV_FILE" "${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"

  if ! grep -q '^AI_WORLD_FEED_REFRESH_MINUTES=' "$ENV_FILE"; then
    cat >> "$ENV_FILE" <<'ENVADD'

# Feed refresh interval used by the web server background scheduler.
# Set to 30 for twice-hourly refreshes.
AI_WORLD_FEED_REFRESH_MINUTES=30
ENVADD
    echo "Updated .env.example"
  else
    echo ".env.example already has AI_WORLD_FEED_REFRESH_MINUTES"
  fi
fi

echo "Added 30-minute feed refresh patch."
