#!/bin/bash
set -euo pipefail

latest="$(git tag --list 'v[0-9]*' --sort=-v:refname | head -n 1)"
latest="${latest#v}"
latest="${latest:-0.0.0}"

if [ -n "${2:-}" ]; then
    next="$2"
else
    IFS=. read -r major minor patch <<< "$latest"
    case "${1:-}" in
        major) next="$((major + 1)).0.0" ;;
        minor) next="$major.$((minor + 1)).0" ;;
        patch) next="$major.$minor.$((patch + 1))" ;;
        *) echo "error: patch, minor, major 가운데 하나를 지정해야 합니다" >&2; exit 1 ;;
    esac
fi

[[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: 버전은 0.1.0 형태여야 합니다: $next" >&2; exit 1; }
if [ "$next" = "$latest" ] || [ "$(printf '%s\n%s\n' "$latest" "$next" | sort -V | tail -n 1)" != "$next" ]; then
    echo "error: $next 은 마지막 릴리스 $latest 보다 높아야 합니다" >&2
    exit 1
fi
echo "$next"
