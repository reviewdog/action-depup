#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

FILE="${INPUT_FILE:-Dockerfile}"
REPO="${INPUT_REPO:-reviewdog/reviewdog}"
VERSION_NAME="${INPUT_VERSION_NAME:-REVIEWDOG_VERSION}"

# Get current version.
CURRENT_VERSION=$(grep -oP "${VERSION_NAME}=\K\d+\.\d+\.\d+" "${FILE}")
if [ -z "${CURRENT_VERSION}" ]; then
  echo "cannot parse ${VERSION_NAME}"
  exit 1
fi
echo "Current ${VERSION_NAME}=${CURRENT_VERSION}"

# Get latest semantic version release tag name from GitHub Release API.
GITHUB_AUTH_HEADER=()
if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
  GITHUB_AUTH_HEADER=(-H "Authorization: token ${INPUT_GITHUB_TOKEN}")
  echo "Use INPUT_GITHUB_TOKEN to get release data."
else
  echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call can fail due to API limit."
fi

LATEST_VERSION=$(\
  curl -s ${GITHUB_AUTH_HEADER[@]} "https://api.github.com/repos/${REPO}/releases" | \
  jq -r '.[] | .tag_name' | \
  sed 's/^v//' | \
  grep -P '\d+\.\d+\.\d+' | \
  sort --version-sort --reverse | \
  head -n1
)
if [ -z "${LATEST_VERSION}" ]; then
  echo "cannot get latest ${REPO} version"
  exit 1
fi
echo "Latest ${VERSION_NAME}=${LATEST_VERSION}"

if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]; then
  echo "${VERSION_NAME} is latest. Nothing to do."
  exit 0
fi

echo "Updating ${VERSION_NAME} to ${LATEST_VERSION} in ${FILE}"
sed -i "s/\(${VERSION_NAME}=\)\([0-9]\+\.[0-9]\+\.\?[0-9]\+\)/\1${LATEST_VERSION}/" "${FILE}"

echo "Updated. Commit and create Pull-Request as you need."
echo "::set-output name=current::${CURRENT_VERSION}"
echo "::set-output name=latest::${LATEST_VERSION}"
