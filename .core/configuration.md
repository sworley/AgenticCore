# .core/configuration.md — AgenticCore Configuration Reference

<!-- schema: configuration/v1 -->

## Overview

AgenticCore requires minimal hard requirements. Everything else is adopter choice.

## Hard Requirements

| Tool | Purpose | Min version |
|---|---|---|
| `git` | Worktree model, version control, provenance | 2.30+ (worktree support) |
| `bash` / `zsh` | Script execution, session shell | Any modern version |
| Python 3 | Hook execution, audit logging | 3.8+ |
| AI coding toolchain | Agent runtime | opencode, or compatible with the adapter layer |

## Environment Variables

| Variable | Purpose | Required | Default |
|---|---|---|---|
| `AGENTICCORE_HOME` | Root of the AgenticCore installation | No | `.` (current directory) |
| `BENCH_PATTERN` | Bench naming pattern | No | `AgenticCore.{NN}` |
| `LLM_BASE_URL` | Inference endpoint | Yes for Tier 1/2 | `http://llm-inference-service:8000/v1` |
| `LLM_MODEL` | Default model ID | No | `<model-id>` |

## Optional Tooling

| Tool | Purpose | Notes |
|---|---|---|
| `mdbook` | Documentation site generation | Required if maintaining `mddocs/` |
| `pass` | Credential injection (HIL workflow) | Optional; credentials may come from any source |
| `direnv` | Environment loading per-directory | Optional convenience |
| `jq` | JSON processing in scripts | Used in some audit scripts |
| `yq` | YAML processing in scripts | Used in task queue scripts |
| `just` | Task runner alternative to Make | Optional; Make is also fine |
| `docker` / `podman` | Container runtime for agent pods | Required for K8s deployment |

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
  echo "WARNING: bench-registry.yaml not found. Run provision-bench.sh to initialize."
fi

# Verify .git/worktrees directory exists
if [ ! -d .git/worktrees ]; then
  mkdir -p .git/worktrees
fi

echo "AgenticCore environment validated."
```

## Platform Integration Notes

### Git Hosting (Git hosting / Git / GitHub)

The harness assumes a standard Git remote. The `origin` remote should point to
the project's canonical repository. Framework-specific concerns (adoption, severed
copies) are handled by `adopt.sh` (v0.2+ feature).

### Credential Injection

Credentials are injected via environment or vault at deploy-time. The harness does
not manage secrets. HIL workflows typically use `pass` + `direnv`, but any mechanism
that populates environment variables before session start is acceptable.

### LLM Endpoint

Agents address inference via the `LLM_BASE_URL` environment variable. The harness
does not provide an LLM. See `mddocs/AGENTICCORE_SPEC.md` §9 for the ExternalName
service pattern.

### Container Runtime

For K8s deployment (Tier 3 / Path A ephemeral agents), a container runtime is
required. The harness does not manage container images or the K8s API. Agent pods
are deployed via standard Kubernetes manifests managed by the infrastructure team.

## adopt.sh — Future Feature

`adopt.sh` (severed-copy export for adopter onboarding) is deferred to v0.2.
See ADR-0005 for the adoption model specification. v0.1 operators are expected
to clone the repo directly and configure their own environment.
