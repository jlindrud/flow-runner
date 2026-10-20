#!/bin/sh
# Shunter's Linux x64 installer. Downloads a complete, versioned runner; no Python/Qt needed.
set -eu
version=${1:?Usage: install.sh <exact-runner-version>}
cache=${SHUNTER_CACHE:-"${XDG_CACHE_HOME:-$HOME/.cache}/shunter/runner"}
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || { echo 'An exact four-part version is required' >&2; exit 1; }
repository=${SHUNTER_REPOSITORY:?Set SHUNTER_REPOSITORY to the owner/repository that publishes Shunt releases}
printf '%s\n' "$repository" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || { echo 'Invalid release repository' >&2; exit 1; }
[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo 'Supported target: Linux x64 (glibc)' >&2; exit 1; }
mkdir -p "$cache/$repository"
cache=$(cd "$cache/$repository" && pwd)
target="$cache/$version-linux-x64"
if [ ! -f "$target/.complete" ]; then
    [ ! -e "$target" ] || { echo "Incomplete install at $target; choose another SHUNTER_CACHE" >&2; exit 1; }
    stage=$(mktemp -d "$cache/.shunter-install-XXXXXXXX")
    cleanup() {
        case "$stage" in "$cache"/.shunter-install-*) rm -r -- "$stage" ;; esac
    }
    trap cleanup EXIT HUP INT TERM
    asset="shunt-$version-linux-x64.tar.gz"
    url="https://github.com/$repository/releases/download/v$version/$asset"
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 "$url" -o "$stage/$asset"
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 "$url.sha256" -o "$stage/checksum"
    expected=$(cut -d ' ' -f 1 "$stage/checksum")
    printf '%s\n' "$expected" | grep -Eq '^[a-fA-F0-9]{64}$' || { echo 'Invalid checksum' >&2; exit 1; }
    printf '%s  %s\n' "$expected" "$stage/$asset" | sha256sum --check --status
    mkdir "$stage/package"
    tar -xzf "$stage/$asset" -C "$stage/package"
    [ "$("$stage/package/bin/shunt" --version)" = "shunt $version" ]
    "$stage/package/bin/python-runtime/bin/python3" -I -c 'import hashlib, json, ssl, urllib.request'
    printf '%s\n' "$version" > "$stage/package/.complete"
    mv "$stage/package" "$target"
fi
[ "$("$target/bin/shunt" --version)" = "shunt $version" ]
if [ -n "${GITHUB_PATH:-}" ]; then printf '%s\n' "$target/bin" >> "$GITHUB_PATH"; fi
if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'SHUNTER_HOME=%s\nSHUNTER_RUNTIME_PYTHON=%s\n' "$target" "$target/bin/python-runtime/bin/python3" >> "$GITHUB_ENV"
fi
printf '%s\n' "$target/bin/shunt"
