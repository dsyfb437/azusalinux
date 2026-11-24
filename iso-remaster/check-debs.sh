#!/usr/bin/env bash
# Validate the complete local package set before producing an installable ISO.
set -euo pipefail

DEBS="${1:?Usage: check-debs.sh DEBS_DIRECTORY}"
shopt -s nullglob
files=("$DEBS"/azusa-*.deb)
if [ "${#files[@]}" -eq 0 ]; then
    echo "No Azusa deb packages found in $DEBS" >&2
    exit 1
fi

declare -A seen=()
cohort_version=""
for file in "${files[@]}"; do
    package="$(dpkg-deb --field "$file" Package)"
    architecture="$(dpkg-deb --field "$file" Architecture)"
    version="$(dpkg-deb --field "$file" Version)"
    if [ -n "$cohort_version" ] && [ "$version" != "$cohort_version" ]; then
        echo "Mixed package versions: expected $cohort_version, got $version in $file" >&2
        exit 1
    fi
    cohort_version="$version"
    case "$package" in
        azusa-*) ;;
        *) echo "Unexpected package $package in $file" >&2; exit 1 ;;
    esac
    case "$architecture" in
        all|amd64) ;;
        *) echo "Unsupported architecture $architecture in $file" >&2; exit 1 ;;
    esac
    if [[ -n "${seen[$package]:-}" ]]; then
        echo "Duplicate package $package: ${seen[$package]} and $file" >&2
        exit 1
    fi
    seen[$package]="$file"
done

for package in azusa-tools azusa-artwork azusa-settings azusa-desktop azusa-icons azusa-release; do
    if [[ -z "${seen[$package]:-}" ]]; then
        echo "Missing required package: $package" >&2
        exit 1
    fi
done
printf 'Validated %s Azusa packages.\n' "${#files[@]}"
