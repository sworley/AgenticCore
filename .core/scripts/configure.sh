#!/bin/bash
# configure.sh — Validate AgenticCore environment

set -e

echo "[configure] Validating AgenticCore environment..."

fail=0

for cmd in git bash python3; do
  if command -v "$cmd" &>/dev/null; then
    echo "[configure] OK: $cmd ($(command -v "$cmd"))"
  else
    echo "[configure] FAIL: $cmd not found"
    fail=1
  fi
done

# Required directories
for dir in .00 .01 .02 .work .audit; do
  if [ -d "$dir" ]; then
    echo "[configure] OK: $dir/"
  else
    echo "[configure] WARN: $dir/ not present; run provision-bench.sh to create"
  fi
done

# Required files
for file in tasks.yaml bench-registry.yaml .core/Core.md .core/invariants.md; do
  if [ -f "$file" ]; then
    echo "[configure] OK: $file"
  else
    echo "[configure] FAIL: $file missing"
    fail=1
  fi
done

# Git repository check
if [ -d ".git" ]; then
  echo "[configure] OK: git repository"
else
  echo "[configure] FAIL: not a git repository"
  fail=1
fi

# Hook wiring check
if [ -f ".core/scripts/check-hook-wiring.py" ]; then
  python3 .core/scripts/check-hook-wiring.py || fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "[configure] PASS: environment is ready"
else
  echo "[configure] FAIL: environment has missing requirements"
  exit 1
fi
