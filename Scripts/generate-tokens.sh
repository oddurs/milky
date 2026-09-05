#!/bin/bash
# Regenerates the Swift and CSS token files from DesignSystem/tokens.json.
# Pass --check to verify the committed files are in sync instead of writing.
set -euo pipefail
cd "$(dirname "$0")/.."
exec node DesignSystem/generate.mjs "$@"
