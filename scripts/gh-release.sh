#!/usr/bin/env bash
# Builds the spark-redshift release assets for a given version and prepares (or, with
# --run, executes) the `gh release create` command that attaches them to a GitHub Release.
#
# Asset naming must match the pattern resolver in starlake-core's project/Common.scala
# (Resolvers.sparkRedshiftGithubReleases): v<version>/<artifact>-<version>[-<classifier>].<ext>
#
# Usage:
#   scripts/gh-release.sh <version>          # build assets, print the gh release create command
#   scripts/gh-release.sh <version> --run    # build assets and actually run gh release create
#
# Prerequisites: the working tree must already be tagged v<version> (this script does not
# tag or push).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [--run]" >&2
  exit 1
fi

VERSION="$1"
RUN=false
if [[ "${2:-}" == "--run" ]]; then
  RUN=true
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IVY_MODULE_DIR="$HOME/.ivy2/local/ai.starlake/spark-redshift_2.13/${VERSION}"
STAGING_DIR="${REPO_ROOT}/target/gh-release/${VERSION}"

echo "==> Building spark-redshift ${VERSION} and publishing to the local ivy repo"
rm -rf "${IVY_MODULE_DIR}"
(cd "${REPO_ROOT}" && sbt "set ThisBuild / version := \"${VERSION}\"" publishLocal)

echo "==> Staging release assets in ${STAGING_DIR}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

cp "${IVY_MODULE_DIR}/jars/spark-redshift_2.13.jar" \
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}.jar"
cp "${IVY_MODULE_DIR}/srcs/spark-redshift_2.13-sources.jar" \
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}-sources.jar"
cp "${IVY_MODULE_DIR}/docs/spark-redshift_2.13-javadoc.jar" \
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}-javadoc.jar"
cp "${IVY_MODULE_DIR}/poms/spark-redshift_2.13.pom" \
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}.pom"
cp "${IVY_MODULE_DIR}/ivys/ivy.xml" \
  "${STAGING_DIR}/ivy-${VERSION}.xml"

echo "==> Staged assets:"
ls -la "${STAGING_DIR}"

GH_CMD=(gh release create "v${VERSION}"
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}.jar"
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}-sources.jar"
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}-javadoc.jar"
  "${STAGING_DIR}/spark-redshift_2.13-${VERSION}.pom"
  "${STAGING_DIR}/ivy-${VERSION}.xml"
  --title "v${VERSION}"
  --generate-notes)

if $RUN; then
  echo "==> Running: ${GH_CMD[*]}"
  "${GH_CMD[@]}"
else
  echo "==> Dry run. Re-run with --run to execute, or run manually:"
  printf '%q ' "${GH_CMD[@]}"
  echo
fi
