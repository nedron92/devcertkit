#!/usr/bin/env bash

fail() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo "$*"
}

need_file() {
  [[ -f "$1" ]] || fail "Missing file: $1"
}

need_dir() {
  [[ -d "$1" ]] || fail "Missing directory: $1"
}