# AgenticCore Configuration Guide

<!-- schema: configuration/v1 -->

## Overview

AgenticCore requires minimal hard requirements. Everything else is adopter choice.

## Hard Requirements

| Tool | Purpose | Min version |
|---|---|---|
| `git` | Worktree model, version control, provenance | 2.30+ (worktree support) |
| `bash` / `zsh` | Script execution, session shell | Any modern version |
| Python 3 | Hook execution, audit logging | 3.8+ |
| AI coding toolchain | Agent runtime | opencode (primary), Codex CLI (deferred) |

## Environment Variables

| Variable | Purpose | Required | Default |
|---|---|---|---|
| `LLM_BASE_URL` | Inference endpoint URL | Yes for Tier 1/2 | `http://llm-inference-service:8000/v1` |
| `LLM_MODEL` | Default model ID | No | `<model-id>` |
| `LLM_API_KEY` | API key for inference | No | `none` |
| `LLM_CONTEXT` | Context window size | No | `262144` |
| `LLM_OUTPUT` | Max output tokens | No | `30000` |

## configure.sh — Environment Bootstrap

```bash
#!/usr/bin/env bash
# .core/scripts/configure.sh — Set up AgenticCore environment

set -e

# Verify hard requirements
for cmd in git bash python3; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is required but not found"
    exit 1
  fi
done

# Create required directories
mkdir -p .00 .01 .02 .work .audit

# Verify bench-registry.yaml exists
if [ ! -f bench-registry.yaml ]; then
  echo "WARNING: bench-registry.yaml not found. Create with initial bench entries."
fi

echo "AgenticCore environment validated."
```

## adopt.sh — Future Feature

`adopt.sh` (severed-copy export for adopter onboarding) is deferred to v0.2.
See ADR-0005 for the adoption model specification. v0.1 operators are expected
to clone the repo directly and configure their own environment.

## External Dependencies

AgenticCore is designed to run on a local Kubernetes cluster (harness-cluster). The harness
does not manage the cluster lifecycle — that is an infrastructure concern consumed
via configuration:

| Concern | Integration point |
|---|---|
| LLM inference | `LLM_BASE_URL` environment variable; K8s ExternalName service |
| Git hosting | A standard git remote \u2014 GitHub, GitLab, or a self-hosted forge (tool-specific integration noted where it differs) |
| Credentials | Injected via environment or vault at deploy-time |
| Container registry | Future; Harbor or equivalent for agent pod images |
