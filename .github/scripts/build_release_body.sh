#!/usr/bin/env bash
# Builds the GitHub release body: this version's changelog section, a downloads
# counter, and a per-OS download table.
#
# Badges are emitted only for assets that are actually present, so a partially
# failed build matrix produces a shorter table rather than a page full of links
# that 404.
#
# Usage: build_release_body.sh <tag> <asset-dir> <changelog> > body.md
set -euo pipefail

TAG="${1:?tag required}"
ASSET_DIR="${2:?asset directory required}"
CHANGELOG="${3:?changelog path required}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"

VERSION="${TAG#v}"
BASE="https://github.com/${REPO}/releases/download/${TAG}"

# One linked shields.io badge. $2 is the badge's "left-right" text, already
# URL-escaped by the caller where it contains spaces.
badge() {
  local file="$1" text="$2" color="$3" logo="$4"
  [ -f "${ASSET_DIR}/${file}" ] || return 0
  printf '                <a href="%s/%s"><img src="https://img.shields.io/badge/%s-%s.svg?logo=%s"></a><br>\n' \
    "$BASE" "$file" "$text" "$color" "$logo"
}

# A table row, printed only if at least one of its badges survived.
row() {
  local os="$1" body="$2"
  [ -n "$body" ] || return 0
  printf '        <tr>\n            <td>%s</td>\n            <td>\n%s\n            </td>\n        </tr>\n' \
    "$os" "$body"
}

android=$(
  badge "LongyunVPN-arm64-v8a.apk"   "APK-ARMv8" "168039" "android"
  badge "LongyunVPN-armeabi-v7a.apk" "APK-ARMv7" "45bf55" "android"
  badge "LongyunVPN-x86_64.apk"      "APK-x64"   "96ed89" "android"
)
windows=$(
  badge "LongyunVPN-${VERSION}-windows-amd64-setup.exe" "Setup-x64"      "2d7d9a" "windows"
  badge "LongyunVPN-${VERSION}-windows-amd64.zip"       "Portable-x64"   "67b7d1" "windows"
  badge "LongyunVPN-${VERSION}-windows-arm64-setup.exe" "Setup-ARM64"    "2d7d9a" "windows"
  badge "LongyunVPN-${VERSION}-windows-arm64.zip"       "Portable-ARM64" "67b7d1" "windows"
)
macos=$(
  badge "LongyunVPN-${VERSION}-macos-arm64.dmg" "DMG-Apple%20Silicon" "%23000000" "apple"
  badge "LongyunVPN-${VERSION}-macos-amd64.dmg" "DMG-Intel%20X64"     "%2300A9E0" "apple"
)
linux=$(
  badge "LongyunVPN-${VERSION}-linux-amd64.AppImage" "AppImage-x64"   "f84e29" "linux"
  badge "LongyunVPN-${VERSION}-linux-amd64.deb"      "DebPackage-x64" "FF9966" "debian"
  badge "LongyunVPN-${VERSION}-linux-amd64.rpm"      "RpmPackage-x64" "F1B42F" "redhat"
)

# The section of CHANGELOG.md for this version: everything between its own
# heading and the next one. Absent entry just means no bullet list.
if [ -f "$CHANGELOG" ]; then
  awk -v want="## v${VERSION}" '
    $0 == want { found = 1; next }
    found && /^## / { exit }
    found { print }
  ' "$CHANGELOG"
fi

cat <<EOF
<div align=center>

[![Release Downloads](https://img.shields.io/github/downloads/${REPO}/${TAG}/total?style=flat-square&logo=github)](https://github.com/${REPO}/releases/tag/${TAG})

</div>

**Download based on your OS:**

<div align=left>
<table>
    <thead align=left>
        <tr>
            <th>OS</th>
            <th>Download</th>
        </tr>
    </thead>
    <tbody align=left>
EOF

row "Android" "$android"
row "Windows" "$windows"
row "macOS"   "$macos"
row "Linux"   "$linux"

cat <<EOF
    </tbody>
</table>

</div>

<div dir="ltr">

**List of all changes:** [ChangeLog](https://github.com/${REPO}/blob/main/CHANGELOG.md)

</div>
EOF
