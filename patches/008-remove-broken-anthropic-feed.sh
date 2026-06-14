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

markers = [
    "anthropic-news",
    "anthropic.com/news/rss",
    "anthropic.com/news/rss.xml",
    "rsshub.app/anthropic",
    "rsshub.rssforever.com/anthropic",
]

hits = [m for m in markers if m in text]

if not hits:
    print("No Anthropic RSS/static feed block found. Nothing to remove.")
    raise SystemExit(0)

idx = min(text.index(m) for m in hits if m in text)

# Find the containing object by walking backward to nearest "{"
start = text.rfind("{", 0, idx)
if start == -1:
    raise SystemExit("ERROR: Found Anthropic marker but could not locate object start.")

# Find matching closing brace.
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
    raise SystemExit("ERROR: Could not locate object end.")

remove_start = start
remove_end = end

# Remove following comma if present.
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

while "\n\n\n" in new_text:
    new_text = new_text.replace("\n\n\n", "\n\n")

path.write_text(new_text.rstrip() + "\n")

print("Removed broken Anthropic RSS/static feed block.")
PY
