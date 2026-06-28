#!/usr/bin/env bash
#set -uo pipefail
source "$(dirname "$0")/helpers.sh"
APP_ENV="${1:-dev}"
shift

(
  cd projects || exit 1
  make_all_projects "build-$APP_ENV" "$@"
)
