#!/usr/bin/env bash
# Point sources.json at the deb in Oneleet's update feed (the one its self-updater
# reads). The feed is unsigned, so the hash is only as trustworthy as its TLS.
set -euo pipefail

base="https://downloads.oneleet.com/agent/linux"
here="$(cd "$(dirname "$0")" && pwd)"

feed="$(curl -fsSL "$base/beta-linux.yml")"
version="$(awk '/^version: / { print $2 }' <<<"$feed")"
file="Oneleet_${version}_amd64.deb"
sha512="$(awk -v f="$file" '$0 ~ "url: " f "$" { s = 1; next } s && /sha512: / { print $2; exit }' <<<"$feed")"

if ! [[ $version =~ ^[0-9]+(\.[0-9]+)+$ && $sha512 =~ ^[A-Za-z0-9+/]{86}==$ ]]; then
  echo "unexpected entry in the feed: $version $sha512" >&2
  exit 1
fi

jq -n --arg version "$version" --arg url "$base/$file" --arg hash "sha512-$sha512" \
  '{ version: $version, url: $url, hash: $hash }' >"$here/sources.json"
echo "oneleet $version"
