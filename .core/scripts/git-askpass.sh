#!/bin/sh
# git-askpass.sh — env->git credential bridge for the AgenticCore workspace.
#
# Git calls GIT_ASKPASS when it needs a username or password and no other
# credential source answered. This script supplies the token that the ADR-0018
# credential-injection layer (.envrc + direnv) already placed in the process
# environment as $GIT_TOKEN — bridging Layer 1 (env injection) to Layer 2
# (git auth) for any ad-hoc git invocation, not just git-sync.sh.
#
# Design (ADR-0018):
#   - D-2: reads the single canonical env var ($GIT_TOKEN). No knowledge of
#     which instance is active; the injection layer guarantees the correct value.
#   - D-3: session-scope. When the operator leaves the workspace tree, direnv
#     unsets $GIT_TOKEN, so this script emits an empty string and git fails
#     closed rather than reusing a stale credential.
#   - No secret is stored in this file, in .git/config, in the remote URL, or in
#     the OS keychain. The value lives only in the environment for the scope the
#     injection layer defines.
#
# Git invokes GIT_ASKPASS with a prompt string as $1. For a token-based flow the
# username is irrelevant to Git (any non-empty value works with a PAT), and
# the password is the token. We answer the password prompt with the token and
# answer any username prompt with "oauth2".
#
# Exit is always 0; git interprets empty output as "no credential" and fails on
# its own if the token is unset.

case "$1" in
  Username*|username*)
    printf '%s\n' "oauth2"
    ;;
  *)
    printf '%s\n' "${GIT_TOKEN:-}"
    ;;
esac
