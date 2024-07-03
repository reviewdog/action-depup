#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

FILE="${INPUT_FILE:-testdata/testfile}"
REPO="${INPUT_REPO:-reviewdog/reviewdog}"
VERSION_NAME="${INPUT_VERSION_NAME:-REVIEWDOG_VERSION}"

# Get current version.
# NOTE: Go to https://regex101.com/r/t1JcmL/13 To see the current regex in action.
CURRENT_VERSION=$(grep -oP "${VERSION_NAME}(?:\s*=\s*|:?\s*)[\"|\']?v?\K\d+\.\d+(\.\d+)?(-[^\'\"\s]*)?" "${FILE}" | head -n1)
if [ -z "${CURRENT_VERSION}" ]; then
  echo "cannot parse ${VERSION_NAME}"
  exit 1
fi
echo "Current ${VERSION_NAME}=${CURRENT_VERSION}"

# Get latest semantic version release tag name from GitHub Release API.
list_releases() {
  if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
    curl -s -H "Authorization: token ${INPUT_GITHUB_TOKEN}" "https://api.github.com/repos/${REPO}/releases"
  else
    echo "INPUT_GITHUB_TOKEN is not available. Subscequent GitHub API call can fail due to API limit." >&2
    curl -s "https://api.github.com/repos/${REPO}/releases"
  fi
}

# Return version list from tags(refs/tags/vA.B.C and vA.B.C^{}) or releases
list_versions() {
  if [ "${INPUT_TAG:-false}" = "true" ]; then
    git ls-remote -q --tags "https://github.com/${REPO}.git" | awk '{ print $2 }'
  else
    list_releases |  jq -r '.[] | .tag_name'
  fi
}

# Filter given version list using given include/exclude regular expressions.
filter_versions() {
    list=$(cat)

    if [ -n "${INPUT_INCLUDE}" ]; then
        echo "include pattern: ${INPUT_INCLUDE}" >&2
        list="$(echo "${list}" | grep -P -- "${INPUT_INCLUDE}")"
    fi

    if [ -n "${INPUT_EXCLUDE}" ]; then
        echo "exclude pattern: ${INPUT_EXCLUDE}" >&2
        list="$(echo "${list}" | grep -vP -- "${INPUT_EXCLUDE}")"
    fi

    echo "${list}"
}

set_output() {
  name=$1
  value=$2
  if [ -n "${GITHUB_OUTPUT}" ]; then
    echo "$name=$value" >> "${GITHUB_OUTPUT}"
  else
    echo "::set-output name=$name::$value"
  fi
}

LATEST_VERSION="$(\
  list_versions | \
  grep -oP '\d+(\.\d+)+(-[^'\''\"\s]*)?$'| \
  filter_versions | \
  sort --version-sort --reverse | \
  head -n1 \
  )"

if [ -z "${LATEST_VERSION}" ]; then
  echo "cannot get latest ${REPO} version"
  exit 1
fi
echo "Latest ${VERSION_NAME}=${LATEST_VERSION}"

# Set outputs.
set_output "current" "${CURRENT_VERSION}"
set_output "latest" "${LATEST_VERSION}"
set_output "repo" "${REPO}"

if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]; then
  echo "${VERSION_NAME} is latest. Nothing to do."
  exit 0
fi

echo "Updating ${VERSION_NAME} to ${LATEST_VERSION} in ${FILE}"
perl -i -pe "s/${VERSION_NAME}(?:\s*=\s*|:?\s*)[\"|\']?v?\K\d+\.\d+(\.\d+)?(-[^\'\"\s]*)?/${LATEST_VERSION}/g" "${FILE}"

echo "Updated. Commit and create Pull-Request as you need."
