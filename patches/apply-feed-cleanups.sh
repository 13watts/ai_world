#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

bash patches/001-feed-source-cleanups.sh
bash patches/002-harden-feed-refresh.sh
bash patches/003-add-feed-validator.sh

npm run build
npm run validate:feeds
