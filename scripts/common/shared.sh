#!/usr/bin/env bash

# This script provides common utility functions for logging, directory management,
# and dependency checking used across the devcertkit scripts.

fail() {
  # Prints an error message to stderr and exits the script with status 1.
  # Arguments:
  #   $*: error message

  echo "Error: $*" >&2
  exit 1
}

info() {
  # Prints an informational message to stdout.
  # Arguments:
  #   $*: message to print

  echo -e "$*"
}

warn() {
  # Prints a warning message in yellow to stderr.
  # Arguments:
  #   $*: warning message

  echo -e "\033[0;33mWarning: $*\033[0m" >&2
}

prepare_dir() {
  # Creates a directory (including parent directories) if it doesn't exist.
  # Arguments:
  #   $1: directory path

  mkdir -p "$1"
}

check_dir() {
  # Verifies that the specified directory exists.
  # Fails if it doesn't exist.
  # Arguments:
  #   $1: directory path

  [[ -d "$1" ]] || fail "Missing directory: $1"
}

check_file() {
  # Verifies that the specified file exists.
  # Fails if it doesn't exist.
  # Arguments:
  #   $1: file path

  [[ -f "$1" ]] || fail "Missing file: $1"
}

need_cmd() {
  # Checks if a command/executable is available in the system PATH.
  # Fails if the command is not found.
  # Arguments:
  #   $1: command name

  command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: '$1'"
}

sanitize_name() {
  # Converts a name (e.g. domain) into a filesystem-safe identifier by replacing
  # dots and other special characters with underscores.
  # Arguments:
  #   $1: input string
  # Returns:
  #   A sanitized string suitable for file and directory names.
  #
  # Examples:
  #   "*.example.com"  -> "wildcard_example_com"
  #   "example.com"    -> "example_com"
  #
  local input="$1"
  local name

  # Handle wildcard prefix explicitly
  if [[ "$input" == \*.* ]]; then
    name="wildcard_${input#*.}"
  else
    name="$input"
  fi

  # Replace dots with underscores
  name="${name//./_}"

  # Replace any remaining invalid characters with underscore
  name="$(echo "$name" | sed 's/[^a-zA-Z0-9_-]/_/g')"

  echo "$name"
}
