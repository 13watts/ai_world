#!/usr/bin/env bash
set -euo pipefail

FEEDS_FILE="src/config/feeds.ts"

if [[ ! -f "$FEEDS_FILE" ]]; then
  echo "ERROR: $FEEDS_FILE not found. Run this from the ai_world repo root." >&2
  exit 1
fi

cp "$FEEDS_FILE" "${FEEDS_FILE}.bak.$(date +%Y%m%d%H%M%S)"

python3 - <<'PY'
from pathlib import Path

path = Path("src/config/feeds.ts")
text = path.read_text()

target = "https://paperswithcode.com/rss"

if target not in text:
    # Clean up any leftovers from prior failed patch attempts anyway.
    lines = text.splitlines()
    cleaned = []
    skip_phrases = [
        "Papers with Code RSS redirects",
        "Native Papers with Code RSS endpoint",
    ]

    for line in lines:
        stripped = line.strip()
        if stripped == "enabled: false,":
            continue
        if stripped.startswith("disabledReason:") and any(p in stripped for p in skip_phrases):
            continue
        cleaned.append(line)

    path.write_text("\n".join(cleaned) + "\n")
    print("Papers with Code URL not found; cleaned prior patch leftovers.")
    raise SystemExit(0)

idx = text.index(target)

# Find object start by walking backward to the nearest opening brace.
start = text.rfind("{", 0, idx)
if start == -1:
    raise SystemExit("ERROR: Could not find start of feed object.")

# Find matching closing brace for that object.
depth = 0
end = None
for pos in range(start, len(text)):
    ch = text[pos]
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            end = pos + 1
            break

if end is None:
    raise SystemExit("ERROR: Could not find end of feed object.")

# Also remove a trailing comma after the object, or a leading comma before it.
remove_start = start
remove_end = end

# Prefer removing following comma/newline if present.
pos = remove_end
while pos < len(text) and text[pos] in " \t\r\n":
    pos += 1

if pos < len(text) and text[pos] == ",":
    remove_end = pos + 1
else:
    # Otherwise remove preceding comma.
    pos = remove_start - 1
    while pos >= 0 and text[pos] in " \t\r\n":
        pos -= 1
    if pos >= 0 and text[pos] == ",":
        remove_start = pos

new_text = text[:remove_start] + text[remove_end:]

# Clean possible blank line pileups.
while "\n\n\n" in new_text:
    new_text = new_text.replace("\n\n\n", "\n\n")

path.write_text(new_text.rstrip() + "\n")
print("Removed broken Papers with Code RSS feed object.")
PY
