#!/usr/bin/env bash
#
# Applies a release computed by semantic-release to the working tree:
#   1. bumps `version:` in pubspec.yaml (pub.dev semver, no build number)
#   2. prepends the release notes to CHANGELOG.md (pub.dev renders this section)
#
# Inputs via environment (set by .github/workflows/version.yaml):
#   RELEASE_VERSION  required, e.g. 0.0.4
#   RELEASE_NOTES    optional, markdown produced by semantic-release
#
# Passing notes via the environment (not as a CLI argument) keeps multi-line
# markdown with quotes/backticks safe from shell word-splitting.
set -euo pipefail

: "${RELEASE_VERSION:?RELEASE_VERSION is required}"

# 1) Bump the pubspec version. Matches the top-level `version:` line only.
sed -i.bak -E "s/^version:.*/version: ${RELEASE_VERSION}/" pubspec.yaml
rm -f pubspec.yaml.bak

# 2) Prepend release notes to the changelog. Fall back to a bare version header
#    so pub.dev always finds an entry for the published version.
NOTES="${RELEASE_NOTES:-}"
if [ -z "${NOTES}" ]; then
  NOTES="## ${RELEASE_VERSION}"
fi

TMP="$(mktemp)"
printf '%s\n\n' "${NOTES}" > "${TMP}"
cat CHANGELOG.md >> "${TMP}"
mv "${TMP}" CHANGELOG.md

echo "Applied release ${RELEASE_VERSION}: pubspec.yaml + CHANGELOG.md updated"
