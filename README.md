# Pullshot

Nintendo Switch 2와 Nintendo Switch에서 찍은 스크린샷과 동영상(캡처)을 USB 케이블로 Mac에 옮기는 앱입니다. 캡처를 게임별로 묶어 보여 주고, 필요한 것만 골라 가져올 수 있습니다. Nintendo Switch 지원은 실험 단계입니다.

## 진행 상황

앱으로 캡처를 게임별로 보고, 새 항목이나 고른 캡처를 가져올 수 있습니다. 내려받을 수 있는 릴리스는 아직 없어서 소스에서 앱을 만들어 씁니다.

## 요구 사항

- macOS 15 이상
- 데이터 전송을 지원하는 USB-C 케이블

## 연결 방법

1. 독이 아니라 본체 아래쪽 USB-C 포트에 케이블을 연결합니다.
2. 본체 설정의 데이터 관리 메뉴에서 PC로 복사를 켭니다.

## 앱

소스에서 앱을 만들어 엽니다.

```bash
make app                 # Apple 실리콘과 Intel을 함께 담은 dist/Pullshot.app을 만들고 ad-hoc 서명
open dist/Pullshot.app
```

다른 Mac에 설치할 때는 `make dmg`로 `dist/Pullshot-<버전>.dmg`를 만듭니다. DMG를 열어 Pullshot.app을 Applications로 끌어 놓으면 설치가 끝납니다.

Apple 공증을 받지 않은 ad-hoc 서명 앱이라, 내려받은 DMG로 설치한 앱을 처음 열면 열 수 없다는 안내가 뜹니다. 그때는 시스템 설정의 개인정보 보호 및 보안 아래쪽에 나타나는 "그래도 열기"를 누릅니다.

스위치를 꽂고 PC로 복사를 켜면 앱이 저절로 연결해 앨범을 읽습니다. 화면에서 할 수 있는 일은 이렇습니다.

- 게임별 보기: 사이드바에서 게임을 고르면 그 게임의 캡처를 최신순이나 날짜별로 봅니다. 아직 Mac으로 옮기지 않은 캡처에는 새 항목 표시가 붙습니다.
- 새 항목 가져오기: "새 항목 N개 가져오기"를 누르면 보이는 캡처 가운데 새 항목을 저장 위치의 게임 이름 폴더에 원본 그대로 받습니다. "모두 가져오기"는 보이는 캡처를 모두 받고, 같은 파일이 이미 있으면 건너뜁니다. 저장 위치는 처음에 `~/Pictures/Pullshot`이고, 오른쪽 칸이나 설정에서 바꿉니다.
- 골라서 가져오기: 캡처를 골라 "N개 가져오기"를 누르면 저장 위치로 받습니다. "폴더별로 나눠 저장"을 끄면 게임 이름 폴더 없이 저장 위치에 바로 두고, "찍은 순서대로 번호 붙이기"를 고르면 `001_20261114_211205.jpg`처럼 번호를 붙입니다.
- 스페이스 바를 눌러 크게 보기: 캡처를 고르고 스페이스 바를 누르면 원본을 받아 Quick Look으로 봅니다. 연 채로 화살표 키를 누르면 Finder처럼 옆 캡처나 윗줄, 아랫줄 캡처로 넘어갑니다.

로그는 `~/Library/Logs/Pullshot/pullshot.log`에 남고, 도움말 메뉴의 로그 파일 보기로 Finder에서 찾을 수 있습니다. 로그에는 파일 이름, 게임 이름, 경로, 일련번호를 남기지 않습니다. 문제를 알릴 때는 설정에서 "자세한 로그 남기기"를 켜고 다시 해 본 뒤, 로그 파일과 함께 GitHub 이슈로 알립니다.

## CLI

개발과 문제 확인에 쓰는 명령입니다. `swift run pullshot <명령>`으로 실행합니다.

- `probe`: 기기 정보, 지원 명령, 저장소를 보여 줍니다.
- `list [--new]`: 게임별 캡처 목록을 보여 줍니다. 새 항목에는 줄 끝에 "새"가 붙습니다.
- `pull (--all | --new | <파일 이름>...) [--out <폴더>] [--numbered] [--no-game-folder] [--dry-run]`: 고른 캡처를 저장 위치(기본 `~/Pictures/Pullshot`)의 게임 이름 폴더에 원본 그대로 가져옵니다. `--numbered`를 주면 찍은 순서대로 `001_20261114_211205.jpg`처럼 번호를 붙입니다.
- `ledger (--from-folder <폴더> | --mark-all | --leave-new)`: 이미 받아 둔 캡처를 옮긴 기록에 넣습니다.
- `dump --out <폴더>`: 실기기 응답을 그대로 기록합니다. 기기 일련번호가 들어 있으므로 공개하지 않습니다.

가져오기는 `~/Library/Application Support/Pullshot/`에 옮긴 기록을 남깁니다. 기록에 없는 캡처, 곧 아직 한 번도 Mac으로 옮기지 않은 캡처가 새 항목입니다.

## 개발

```bash
brew bundle        # SwiftLint, SwiftFormat 설치
make setup-hooks   # 커밋 전 린트와 포맷 검사 설정
make build
make test
make check         # SwiftLint --strict, SwiftFormat --lint
```

코딩 규칙은 [docs/conventions.md](docs/conventions.md), 용어는 [docs/glossary.md](docs/glossary.md)에 있습니다. 이슈와 PR을 여는 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)에 있습니다.

## 라이선스

MIT 라이선스로 배포합니다. 전문은 [LICENSE](LICENSE)에 있습니다.

Pullshot은 Nintendo가 만들거나 승인한 프로젝트가 아닌 개인 오픈소스 프로젝트입니다. Nintendo Switch와 Nintendo Switch 2는 Nintendo의 상표이며, 이 문서에서는 지원하는 기기를 밝히는 데에만 씁니다.

## 참고한 프로젝트

스위치가 응답하는 기본 PTP(카메라와 컴퓨터가 사진을 주고받는 USB 규약) 명령 10개, 스위치의 USB 제품 ID, 앞 연결이 닫지 못한 세션을 정리하는 순서는 [Tethersnap](https://github.com/Luminoid/Tethersnap)의 README와 CHANGELOG에서 알게 되었습니다. 코드는 가져오지 않고 처음부터 새로 작성했습니다.
