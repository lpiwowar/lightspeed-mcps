#!/usr/bin/env bash
# Download checksum-pinned artifacts listed in an artifacts.txt file.
#
# Usage:
#   /path/to/get_artifacts.sh /path/to/artifacts.txt
#
# Each non-comment line in the file must be:
#   <filename> <sha256> <url>
# Files are downloaded into the current working directory.  A pre-existing
# file is retained only when its SHA-256 matches the recorded checksum.

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 <artifacts.txt>" >&2
  exit 2
fi

artifacts_file="$1"
if [[ ! -f "${artifacts_file}" ]]; then
  echo "ERROR: artifacts file not found: ${artifacts_file}" >&2
  exit 1
fi

if ! command -v curl >/dev/null; then
  echo "ERROR: curl is required to fetch artifacts from ${artifacts_file}" >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null; then
  echo "ERROR: sha256sum is required to verify artifacts" >&2
  exit 1
fi

while IFS=' ' read -r filename sha256 url; do
  [[ -z "${filename}" || "${filename}" == \#* ]] && continue
  if [[ -z "${sha256}" || -z "${url}" ]]; then
    echo "ERROR: invalid artifact entry for ${filename} in ${artifacts_file}" >&2
    exit 1
  fi

  dest="${PWD}/${filename}"
  actual=""
  if [[ -f "${dest}" ]]; then
    actual="$(sha256sum "${dest}" | awk '{print $1}')"
    if [[ "${actual}" == "${sha256}" ]]; then
      echo "--- Artifact ${filename} already present ---"
      continue
    fi
    echo "--- Artifact ${filename} checksum mismatch, re-fetching ---"
    rm -f "${dest}"
  fi

  echo "--- Fetching ${filename} ---"
  curl -fsSL -o "${dest}" "${url}"
  actual="$(sha256sum "${dest}" | awk '{print $1}')"
  if [[ "${actual}" != "${sha256}" ]]; then
    echo "ERROR: checksum mismatch for ${filename}" >&2
    echo "       expected ${sha256}" >&2
    echo "       got      ${actual}" >&2
    rm -f "${dest}"
    exit 1
  fi
done < "${artifacts_file}"
