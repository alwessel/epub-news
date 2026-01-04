#!/bin/bash
  set -euo pipefail

  UPLOAD_PATTERN="${1:-heise*.pdf}"
  UPLOAD_DIR="${2:-/Heise/}"

  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) file="rmapi-linux-amd64.tar.gz" ;;
    aarch64|arm64) file="rmapi-linux-arm64.tar.gz" ;;
    *) echo "Unknown arch"; exit 1 ;;
  esac

  rm -f "$file" rmapi
  wget "https://github.com/ddvk/rmapi/releases/download/v0.0.32/$file"
  tar -xzf "$file"
  chmod +x rmapi

  export RMAPI_CONFIG=rmapi.conf
  if [ -n "${RM_CONFIG:-}" ]; then
    echo "$RM_CONFIG" | base64 -d > rmapi.conf
  else
    if [ ! -f rmapi.conf ]; then
      echo "RM_CONFIG is not set and rmapi.conf does not exist, skip publishing."
      exit 0
    fi
    echo "RM_CONFIG is empty, us existing rmapi.conf"
  fi

  ./rmapi -ni put "$UPLOAD_PATTERN" "$UPLOAD_DIR"
  echo "Successfully uploaded to reMarkable."
