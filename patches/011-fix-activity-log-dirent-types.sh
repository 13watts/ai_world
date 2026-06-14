#!/usr/bin/env bash
set -euo pipefail

LOG_SERVICE_FILE="src/services/activityLog.ts"

if [[ ! -f "$LOG_SERVICE_FILE" ]]; then
  echo "ERROR: $LOG_SERVICE_FILE not found. Run this from the ai_world repo root." >&2
  exit 1
fi

cp "$LOG_SERVICE_FILE" "${LOG_SERVICE_FILE}.bak.$(date +%Y%m%d%H%M%S)"

python3 - <<'PY'
from pathlib import Path
import re

path = Path("src/services/activityLog.ts")
text = path.read_text()

replacement = r'''type JsonlDirent = {
  name: string;
  isDirectory(): boolean;
  isFile(): boolean;
};

async function listJsonlFiles(dir: string): Promise<string[]> {
  let entries: JsonlDirent[];

  try {
    entries = (await fs.readdir(dir, {
      withFileTypes: true,
      encoding: 'utf8'
    })) as unknown as JsonlDirent[];
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }

  const files: string[] = [];
  for (const entry of entries) {
    const entryName = String(entry.name);
    const fullPath = path.join(dir, entryName);

    if (entry.isDirectory()) {
      files.push(...await listJsonlFiles(fullPath));
    } else if (entry.isFile() && entryName.endsWith('.jsonl')) {
      files.push(fullPath);
    }
  }

  return files;
}'''

pattern = re.compile(
    r"async function listJsonlFiles\(dir: string\): Promise<string\[\]> \{.*?\n\}",
    re.DOTALL,
)

new_text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit("ERROR: Could not replace listJsonlFiles() in src/services/activityLog.ts")

path.write_text(new_text)
PY

echo "Fixed Node 22 Dirent typing in src/services/activityLog.ts"
