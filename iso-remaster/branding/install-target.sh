#!/usr/bin/env bash
set -euo pipefail
root=${1:?expected mounted target root}
logo=${2:?expected rendered logo}
here=$(cd "$(dirname "$0")" && pwd)

install -Dm644 "$here/grub.theme" "$root/boot/grub/themes/azusa/theme.txt"
install -Dm644 "$here/95-azusa-grub.cfg" "$root/etc/default/grub.d/95-azusa.cfg"
install -Dm644 "$logo" "$root/usr/share/pixmaps/azusalinux-greeter.png"
install -Dm644 "$here/95-azusa-greeter.gschema.override" \
    "$root/usr/share/glib-2.0/schemas/95-azusa-greeter.gschema.override"
chroot "$root" glib-compile-schemas --strict /usr/share/glib-2.0/schemas

# Retain the Ubuntu spinner's animation, dialogs and update modes.
themes=/usr/share/plymouth/themes
mkdir "$root$themes/azusa"
cp -a "$root$themes/spinner/." "$root$themes/azusa/"
unlink "$root$themes/azusa/watermark.png"
install -m644 "$logo" "$root$themes/azusa/watermark.png"
sed -e '/^Name\[/d' -e 's/^Name=.*/Name=AzusaLinux/' \
    -e 's|^ImageDir=.*|ImageDir=/usr/share/plymouth/themes/azusa|' \
    "$root$themes/spinner/spinner.plymouth" > "$root$themes/azusa/azusa.plymouth"
unlink "$root$themes/azusa/spinner.plymouth"
chroot "$root" update-alternatives --install "$themes/default.plymouth" \
    default.plymouth "$themes/azusa/azusa.plymouth" 200
