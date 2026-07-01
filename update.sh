#!/usr/bin/env bash
set -euo pipefail

repo="https://downloads.claude.ai/claude-desktop/apt/stable"
pkg="package.nix"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch_packages() {
  local arch="$1"
  curl -fsSL "$repo/dists/stable/main/binary-$arch/Packages"
}

latest_field() {
  local arch="$1"
  local field="$2"
  fetch_packages "$arch" | awk -v field="$field" '
    BEGIN { RS = ""; FS = "\n" }
    /Package: claude-desktop/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ "^" field ": ") {
          sub("^" field ": ", "", $i)
          print $i
        }
      }
    }
  ' | tail -1
}

version="$(latest_field amd64 Version)"
amd64_file="$(latest_field amd64 Filename)"
arm64_file="$(latest_field arm64 Filename)"
amd64_sha="$(latest_field amd64 SHA256)"
arm64_sha="$(latest_field arm64 SHA256)"

amd64_hash="$(nix hash convert --hash-algo sha256 "$amd64_sha")"
arm64_hash="$(nix hash convert --hash-algo sha256 "$arm64_sha")"

perl -0pi -e "s/version = \"[^\"]+\";/version = \"$version\";/" "$pkg"
perl -0pi -e "s#url = \"$repo/[^\"]+_amd64\\.deb\";#url = \"$repo/$amd64_file\";#" "$pkg"
perl -0pi -e "s#url = \"$repo/[^\"]+_arm64\\.deb\";#url = \"$repo/$arm64_file\";#" "$pkg"
perl -0pi -e "s#hash = \"sha256-[^\"]+\";#hash = \"$amd64_hash\";#s" "$pkg"
perl -0pi -e "s#(aarch64-linux = fetchurl \\{[^}]+hash = \")sha256-[^\"]+\";#\${1}$arm64_hash\";#s" "$pkg"

echo "Updated claude-desktop to $version"
