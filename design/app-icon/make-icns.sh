#!/bin/bash
# 1024x1024 PNG 하나로 macOS 앱 아이콘(.icns)을 만듭니다. 사용법: ./make-icns.sh <1024 PNG> <출력 .icns>
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "사용법: $0 <1024x1024 PNG> <출력 .icns>" >&2
    exit 2
fi
source_png=$1
output_icns=$2

width=$(sips -g pixelWidth "$source_png" | awk '/pixelWidth/ { print $2 }')
height=$(sips -g pixelHeight "$source_png" | awk '/pixelHeight/ { print $2 }')
if [ "$width" != 1024 ] || [ "$height" != 1024 ]; then
    echo "error: 1024x1024 PNG가 필요합니다 ($source_png, ${width}x${height})" >&2
    exit 1
fi

# iconutil은 폴더 이름이 .iconset으로 끝나야 읽습니다.
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
iconset="$work_dir/AppIcon.iconset"
mkdir "$iconset"

for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$source_png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -s format png -z $((size * 2)) $((size * 2)) "$source_png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p "$(dirname "$output_icns")"
iconutil -c icns "$iconset" -o "$output_icns"
echo "$output_icns"
