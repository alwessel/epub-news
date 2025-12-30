#!/bin/bash
set -e

if [ -n "${RM_CONFIG:-}" ]; then
  RMAPI_ZIP=rmapi-linux-amd64.tar.gz
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) file=rmapi-linux-amd64.tar.gz ;;
    aarch64|arm64) file=rmapi-linux-arm64.tar.gz ;;
    *) echo "Unknown arch"; exit 1;;
  esac
  wget "https://github.com/ddvk/rmapi/releases/download/v0.0.32/$file"
  tar -xzf "$file"
  chmod +x rmapi
  echo "$RM_CONFIG" | base64 -d > rmapi.conf
  export RMAPI_CONFIG=rmapi.conf
  ./rmapi put heise*.epub /Heise/
  echo "Successfully uploaded to reMarkable."
else
  echo "RM_CONFIG not set, skipping upload to reMarkable."
fi
