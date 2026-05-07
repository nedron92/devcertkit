#!/usr/bin/env bash
fail() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo -e "$*"
}

prepare_dir() {
  mkdir -p "$1"
}

check_dir() {
  [[ -d "$1" ]] || fail "Missing directory: $1"
}

check_file() {
  [[ -f "$1" ]] || fail "Missing file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: '$1'"
}