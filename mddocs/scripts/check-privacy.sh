#!/bin/sh
# check-privacy.sh - Fail if operator-specific / personal values appear in tracked content.
#
# Guards the framework repo against the personal-environment bleed class:
# absolute local filesystem paths, private/link-local network ranges, and
# home-lab / cluster hostnames. Deployer-neutral by design - it does not encode a
# specific maintainer's identity, so it is safe to ship to adopters or run in any
# repo. Vendor/minified and build artifacts are skipped, as is this scanner.
#
# Usage:
#   ./mddocs/scripts/check-privacy.sh
#
# Exit codes:
#   0  Clean - no personal/private values found
#   1  Personal/private value(s) found

set -u

# Files skipped entirely: build output, vendor/minified asset, this scanner + its
# metadata companion (which share the same base name).
EXCLUDE_RE='^(mddocs/book/.*|mddocs/mermaid\.min\.js|mddocs/scripts/check-privacy\.sh(\..*)?)$'

# Disallowed personal/private value patterns (extended regex). Deployer-neutral:
#   absolute local filesystem paths (Linux/macOS)
#   RFC1918 private ranges (10./172.16-31./192.168.)
#   common home-lab / cluster hostnames and dynamic-DNS suffixes
PATTERNS="$(cat <<'EOF'
(/home/[a-zA-Z0-9._-]+/|/Users/[a-zA-Z0-9._-]+/|/Volumes/[a-zA-Z0-9._-]+/|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.|inference-node-[0-9]+|harness-cluster|operator workstation|worleyinfra)
EOF
)"

found=0
while IFS= read -r f; do
  case "$f" in
    mddocs/book/*|mddocs/mermaid.min.js|mddocs/scripts/check-privacy.sh|mddocs/scripts/check-privacy.sh.meta.yaml) continue ;;
  esac
  if grep -niE "$PATTERNS" "$f" 2>/dev/null | grep -q .; then
    found=1
    echo "check-privacy: personal/private value in $f"
    grep -niE "$PATTERNS" "$f" 2>/dev/null | sed 's/^/    /' | head -5
  fi
done < <(git ls-files)

if [ "$found" -eq 0 ]; then
  echo "check-privacy: clean (no personal/private values)"
else
  echo "check-privacy: FAIL - personal/private value(s) found"
fi
exit "$found"
