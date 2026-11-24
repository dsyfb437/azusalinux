#!/usr/bin/env bash
# Read-only acceptance check, run as the new user after installing from the ISO.
set -uo pipefail
failed=0
expected_hostname=${1:-azusalinux}

check() {
    local name="$1"
    shift
    if "$@"; then
        printf 'PASS %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name" >&2
        failed=$((failed + 1))
    fi
}

setting() {
    local schema="$1" key="$2" expected="$3"
    local actual
    actual="$(gsettings get "$schema" "$key")" || return 1
    [ "$actual" = "'$expected'" ]
}

package_installed() {
    [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = 'install ok installed' ]
}

wallpaper_exists() {
    local uri
    uri="$(gsettings get org.gnome.desktop.background "$1")" || return 1
    uri="${uri#\'}"; uri="${uri%\'}"
    [[ "$uri" = file:///usr/share/backgrounds/azusa/* ]] && [ -r "${uri#file://}" ]
}

font_available() {
    fc-match -f '%{family}' "$1" | grep -Fq "$1"
}

check 'os-release syntax and Azusa identity' sh -c \
    '. /etc/os-release && [ "$ID" = azusalinux ] && [ "$UBUNTU_CODENAME" = resolute ]'
check 'hostname' test "$(hostname)" = "$expected_hostname"
for package in azusa-tools azusa-artwork azusa-settings azusa-desktop azusa-icons azusa-release; do
    check "package $package" package_installed "$package"
done
check 'GNOME graphical target' systemctl is-active --quiet graphical.target
check 'accent' setting org.gnome.desktop.interface accent-color purple
check 'dark mode' setting org.gnome.desktop.interface color-scheme prefer-dark
check 'interface font' setting org.gnome.desktop.interface font-name 'Inter 11'
check 'monospace font' setting org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11'
check 'icon theme' setting org.gnome.desktop.interface icon-theme Azusa-Papirus
check 'Inter resolves to installed font' font_available Inter
check 'JetBrains Mono resolves to installed font' font_available 'JetBrains Mono'
check 'light wallpaper' wallpaper_exists picture-uri
check 'dark wallpaper' wallpaper_exists picture-uri-dark
check 'violet folder link resolves' test -e /usr/share/icons/Azusa-Papirus/48x48/places/folder.svg
check 'palette tool executes' sh -c 'azusa-palette >/dev/null'
check 'mascot renderer loads' sh -c 'azusa-logo --help >/dev/null'
check 'fetch tool executes' sh -c 'azusa-fetch >/dev/null'

printf '\nFailed checks: %s\n' "$failed"
[ "$failed" -eq 0 ]
