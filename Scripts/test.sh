#!/bin/bash
# Runs the test suite. Swift Testing lives outside the default search path when
# only the Command Line Tools are installed, so point the compiler and linker at it.
set -euo pipefail
cd "$(dirname "$0")/.."
FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$FRAMEWORKS/Testing.framework" ]; then
  exec swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" "$@"
fi
exec swift test "$@"
