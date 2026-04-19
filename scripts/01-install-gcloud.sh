#!/usr/bin/env bash
# Step 1. Install gcloud CLI.
# Works on macOS (Homebrew) and Debian/Ubuntu. For other systems see
# https://cloud.google.com/sdk/docs/install
set -euo pipefail

if command -v gcloud >/dev/null 2>&1; then
  echo "gcloud already installed: $(gcloud --version | head -1)"
  exit 0
fi

os="$(uname -s)"
case "$os" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew is required. Install from https://brew.sh and re-run."
      exit 1
    fi
    brew install --cask google-cloud-sdk
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y google-cloud-cli
    else
      echo "Unsupported Linux distribution. See https://cloud.google.com/sdk/docs/install"
      exit 1
    fi
    ;;
  *)
    echo "Unsupported OS: $os"
    exit 1
    ;;
esac

gcloud --version | head -1
