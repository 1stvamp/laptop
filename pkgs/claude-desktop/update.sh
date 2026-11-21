#!/usr/bin/env bash
# Point sources.json at the newest claude-desktop in Anthropic's apt repo. The deb's
# hash is trusted only through InRelease, which must be signed by archive-keyring.asc.
set -euo pipefail

repo="https://downloads.claude.ai/claude-desktop/apt/stable"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL -o "$work/InRelease" "$repo/dists/stable/InRelease"
curl -fsSL -o "$work/Packages" "$repo/dists/stable/main/binary-amd64/Packages"

gpg --dearmor <"$here/archive-keyring.asc" >"$work/keyring.gpg"
gpgv --keyring "$work/keyring.gpg" --output "$work/Release" "$work/InRelease"

want="$(awk '/^SHA256:/ { s = 1; next } /^[^ ]/ { s = 0 } s && $3 == "main/binary-amd64/Packages" { print $1 }' "$work/Release")"
got="$(sha256sum "$work/Packages" | cut -d' ' -f1)"
if [ -z "$want" ] || [ "$want" != "$got" ]; then
  echo "Packages index does not match the signed InRelease" >&2
  exit 1
fi

read -r version file sha256 < <(awk '
  /^Version: /  { v = $2 }
  /^Filename: / { f = $2 }
  /^SHA256: /   { s = $2 }
  /^$/          { if (v) print v, f, s; v = f = s = "" }
  END           { if (v) print v, f, s }
' "$work/Packages" | sort -V -k1,1 | tail -n1)

if ! [[ $version =~ ^[0-9]+(\.[0-9]+)+$ && $sha256 =~ ^[0-9a-f]{64}$ && $file =~ ^pool/[A-Za-z0-9_./+~-]+\.deb$ ]]; then
  echo "unexpected entry in the Packages index: $version $file $sha256" >&2
  exit 1
fi

jq -n --arg version "$version" --arg url "$repo/$file" --arg sha256 "$sha256" \
  '{ version: $version, url: $url, sha256: $sha256 }' >"$here/sources.json"
echo "claude-desktop $version"
