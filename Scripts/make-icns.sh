#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "사용법: $0 <1024x1024 PNG> <출력 .icns> [작은 크기용 1024x1024 PNG]" >&2
    exit 2
fi
source_png=$1
output_icns=$2
small_png=${3:-$1}

for png in "$source_png" "$small_png"; do
    width=$(sips -g pixelWidth "$png" | awk '/pixelWidth/ { print $2 }')
    height=$(sips -g pixelHeight "$png" | awk '/pixelHeight/ { print $2 }')
    if [ "$width" != 1024 ] || [ "$height" != 1024 ]; then
        echo "error: 1024x1024 PNG가 필요합니다 ($png, ${width}x${height})" >&2
        exit 1
    fi
done

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
iconset="$work_dir/AppIcon.iconset"
mkdir "$iconset"

resize() {
    sips -s format png -z "$2" "$2" "$1" --out "$iconset/$3.png" >/dev/null
}

resize "$small_png" 16 icon_16x16
resize "$small_png" 32 icon_16x16@2x
resize "$small_png" 32 icon_32x32
resize "$source_png" 64 icon_32x32@2x
for size in 128 256 512; do
    resize "$source_png" "$size" "icon_${size}x${size}"
    resize "$source_png" $((size * 2)) "icon_${size}x${size}@2x"
done

mkdir -p "$(dirname "$output_icns")"
iconutil -c icns "$iconset" -o "$output_icns"
echo "$output_icns"
