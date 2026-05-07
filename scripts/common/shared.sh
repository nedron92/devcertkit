#!/usr/bin/env bash

fail() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo "$*"
}

check_file() {
  [[ -f "$1" ]] || fail "Missing file: $1"
}

check_dir() {
  [[ -d "$1" ]] || fail "Missing directory: $1"
}

prepare_dir() {
  mkdir -p "$1"
}