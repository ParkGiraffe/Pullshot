# 앱 아이콘 시안

Pullshot 앱 아이콘 시안 다섯 개입니다. 하나를 고르면 `make-icns.sh`로 `.icns`를 만들어 앱에 붙입니다.

## 파일

- `concept-<번호>-<이름>.svg`: 시안 원본입니다.
- `concept-<번호>-<이름>.png`: 원본을 1024x1024로 그린 것입니다.
- `concepts-light.png`, `concepts-dark.png`: 밝은 배경과 어두운 배경에서 시안마다 256, 128, 64, 32, 16 크기를 나란히 둔 비교 이미지입니다.
- `make-icns.sh`: 1024 PNG 하나로 `.icns`를 만드는 스크립트입니다.

## 공통 규격

- 1024x1024 캔버스 가운데에 824x824 둥근 사각형을 두고, 아래쪽에 은은한 그림자를 깔았습니다. 모서리는 macOS 아이콘처럼 곡률이 이어지는 모양이며 반지름 185.4에 해당합니다.
- 색은 앱 강조색 보라 `#7A69FF` 계열과 새 항목 표시 주황 `#FF9F2E`을 씁니다.
- 카드 속 장면은 하늘, 언덕, 해로 만든 가상 장면입니다. Nintendo 상표와 로고, 컨트롤러 모양, 실제 게임 캐릭터와 화면은 쓰지 않았습니다.

## 시안

1. 격자와 당김(`concept-1-grid-pull`): 앨범 격자 세 칸과 아래 화살표가 든 주황 원으로, 캡처 앨범에서 Mac으로 당겨 오는 일을 나타냅니다. 32에서도 보라 바탕의 세 칸과 주황 원이 남고, 16에서는 주황 원이 새 항목 표시처럼 보입니다.
2. 겹친 캡처(`concept-2-stacked-cards`): 16:9 캡처 카드 세 장이 부채꼴로 겹치고 맨 앞 카드가 아래로 빠져나온 모양으로, 게임별로 쌓인 캡처를 나타냅니다. 흰 테두리 덕분에 32에서도 카드 모양이 남지만, 이름의 Pull은 다른 시안보다 약하게 드러납니다.
3. 셔터 프레임(`concept-3-shutter-frame`): 16:9 화면 모서리 표시 안에 보라 조리개를 둔 모양으로, 게임 화면을 찍는 일을 나타냅니다. 32에서는 모서리 표시가 가늘어지고 16에서는 보라 점만 또렷하며, 바탕이 밝아 밝은 Dock에서는 테두리가 옅게 보입니다.
4. 케이블과 사진(`concept-4-cable-photo`): 위에서 내려온 USB-C 단자와 그 아래 캡처 한 장으로, 케이블을 꽂아 캡처를 가져오는 쓰임새를 그대로 보여 줍니다. 64까지는 단자가 또렷하지만 32 아래에서는 단자가 보라 덩어리로 줄어들어, 다섯 시안 가운데 작은 크기에서 가장 약합니다.
5. P 모노그램(`concept-5-monogram-p`): 기둥 끝이 아래 화살표인 P이고, 고리 안에 하늘과 언덕 장면을 넣어 Pull과 shot을 한 글자에 담았습니다. 굵고 단순한 형태라 16에서도 P와 화살표를 알아볼 수 있습니다.

## 고른 뒤 .icns 만들기

고른 시안의 1024 PNG와 출력 경로를 넘깁니다. `sips`로 16, 32, 128, 256, 512 크기의 1x와 2x 그림을 만들고 `iconutil`로 묶습니다.

```bash
cd design/app-icon
./make-icns.sh concept-5-monogram-p.png ../../App/AppIcon.icns
```

앱에 붙일 때는 `make app`이 `AppIcon.icns`를 `Contents/Resources/`에 복사하게 하고, `App/Info.plist`의 `CFBundleIconFile`을 `AppIcon`으로 적습니다.

SVG를 고쳤으면 PNG를 다시 그린 뒤 `.icns`를 만듭니다. 이번 PNG는 macOS AppKit의 `NSImage`로 SVG를 읽어 1024 크기로 그렸습니다.

```bash
cd design/app-icon
swiftc render.swift -o "$TMPDIR/render-icon"
"$TMPDIR/render-icon" concept-5-monogram-p.svg concept-5-monogram-p.png
```
