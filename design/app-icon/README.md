# 앱 아이콘

Pullshot 앱 아이콘 세 가지입니다. 설정에서 고를 수 있고, 기본은 빨강입니다. `make app`이 `make-icns.sh`로 `.icns`를 만들어 앱에 넣습니다.

## 파일

- `icon-<이름>.svg`, `icon-<이름>.png`: 아이콘 원본과 1024x1024로 그린 것입니다.
- `icon-<이름>-small.svg`, `icon-<이름>-small.png`: 32, 16 크기 칸에 쓰는 굵은 선 판입니다.
- `icon-set-compare.png`: 밝은 배경과 어두운 배경에서 세 아이콘을 256, 128, 64, 32, 16 크기로 나란히 둔 비교 이미지입니다.
- `icon-set-preview.png`: 세 아이콘을 512 크기로 나란히 둔 그림입니다.
- `make-icns.sh`: 1024 PNG로 `.icns`를 만드는 스크립트입니다.
- `render.swift`: SVG를 PNG로 그리는 스크립트입니다.

## 규격

- 1024x1024 캔버스 가운데에 824x824 둥근 사각형을 두고, 아래쪽에 은은한 그림자를 깔았습니다. 모서리는 macOS 아이콘처럼 곡률이 이어지는 모양이며 반지름 185.4에 해당합니다.
- 네 모서리 괄호와 가운데 그림을 1024 기준 38 굵기의 끝이 둥근 흰 선으로 그립니다.
- 바탕은 렌더러가 색을 틀지 않도록 단색 위에 위아래 명암을 덧칠했습니다.
- Nintendo 로고 모양, 컨트롤러 실루엣, 글자는 쓰지 않습니다.

## 세 가지

- 빨강(`icon-red-gamepad`): 괄호 안에 게임패드를 둔 기본 아이콘이며, 바탕은 빨강 `#E60012`입니다.
- 보라(`icon-purple-gamepad`): 같은 그림에 바탕만 앱 강조색 보라 `#7A69FF`입니다.
- 셔터 프레임(`icon-shutter`): 같은 괄호 안에 게임패드 대신 원과 조리개 날 여섯 개로 그린 조리개를 두었고, 바탕은 짙은 흑연색 `#2B2838`입니다.

작은 크기용 판은 선을 56 굵기로 키웠습니다. 게임패드 판은 십자키와 단추를 뺐고, 셔터 프레임 판은 조리개 날을 빼고 원과 가운데 육각형만 남겼습니다.

## .icns 만들기

1024 PNG와 출력 경로를 넘기고, 작은 크기용 판을 셋째 인자로 넘깁니다. `sips`로 16, 32, 128, 256, 512 크기의 1x와 2x 그림을 만들고 `iconutil`로 묶으며, 16, 16@2x, 32 칸은 작은 크기용 판에서 만듭니다.

```bash
cd design/app-icon
./make-icns.sh icon-red-gamepad.png "$TMPDIR/icon-red-gamepad.icns" icon-red-gamepad-small.png
```

`make app`은 세 아이콘의 `.icns`를 `.build/app-icons/`에 만들어 번들의 `Contents/Resources/`에 넣은 뒤 서명합니다. `.icns`는 리포에 넣지 않습니다. `App/Info.plist`의 `CFBundleIconFile`이 빨강이라 Finder, Launchpad, DMG에는 빨강이 보이고, 설정에서 고른 아이콘은 앱이 열려 있는 동안 Dock과 앱 전환기에만 보입니다.

## PNG 다시 그리기

SVG를 고쳤으면 PNG를 다시 그린 뒤 `.icns`를 만듭니다. macOS AppKit의 `NSImage`로 SVG를 읽어 1024 크기로 그립니다.

```bash
cd design/app-icon
swiftc render.swift -o "$TMPDIR/render-icon"
"$TMPDIR/render-icon" icon-red-gamepad.svg icon-red-gamepad.png
```
