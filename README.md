# Pullshot

Nintendo Switch 2와 Nintendo Switch로 찍은 스크린샷과 동영상을 USB 케이블로 Mac에 옮기는 앱입니다. 게임별로 묶어서 보여 주고, 필요한 것만 선택해서 가져올 수 있습니다. Nintendo Switch 지원은 실험 단계입니다.

## 진행 상황

앱에서 게임별 보기와 가져오기를 사용할 수 있습니다. 아직 릴리스가 없어서 소스에서 직접 빌드해 사용합니다.

## 요구 사항

- macOS 15 이상
- 데이터 전송을 지원하는 USB-C 케이블

## 연결 방법

1. 독이 아니라 본체 아래쪽 USB-C 포트에 케이블을 연결합니다.
2. 본체 설정의 데이터 관리 메뉴에서 PC로 복사를 켭니다.

## 앱

소스에서 빌드한 뒤 실행합니다.

```bash
make app                 # dist/Pullshot.app을 Apple 실리콘과 Intel 유니버설로 빌드하고 ad-hoc 서명
open dist/Pullshot.app
```

다른 Mac에 설치하려면 `make dmg`로 `dist/Pullshot-<버전>.dmg`를 만들고, DMG를 열어 Pullshot.app을 Applications 폴더로 드래그합니다.

Apple 공증을 받지 않은 ad-hoc 서명 앱이기 때문에, 다운로드한 DMG로 설치한 앱을 처음 실행하면 열 수 없다는 안내가 나옵니다. 이때 시스템 설정의 개인정보 보호 및 보안 아래쪽에 나오는 "그래도 열기"를 누르면 됩니다.

스위치를 연결하고 PC로 복사를 켜면 앱이 자동으로 연결해 앨범을 읽어 옵니다. 게임별로 사진과 동영상을 보고, 새 항목이나 선택한 항목을 저장 위치(기본값 `~/Pictures/Pullshot`)로 가져올 수 있습니다.

로그는 `~/Library/Logs/Pullshot/pullshot.log`에 저장되며, 도움말 메뉴의 "로그 파일 보기"로 Finder에서 열 수 있습니다. 로그에는 파일 이름, 게임 이름, 경로, 일련번호가 기록되지 않습니다. 문제가 생기면 설정에서 "자세한 로그 남기기"를 켜고 다시 시도한 뒤, 로그 파일을 첨부해 GitHub 이슈로 알려 주시면 됩니다.

## CLI

개발과 디버깅에 사용하는 명령어입니다. `swift run pullshot <명령>`으로 실행합니다.

- `probe`: 기기 정보, 지원하는 PTP 명령, 저장소를 출력합니다.
- `list [--new]`: 게임별 사진과 동영상 목록을 출력합니다. 새 항목은 줄 끝에 "새"로 표시합니다.
- `pull (--all | --new | <파일 이름>...) [--out <폴더>] [--numbered] [--no-game-folder] [--dry-run]`: 지정한 사진과 동영상을 저장 위치(기본값 `~/Pictures/Pullshot`)의 게임 이름 폴더에 원본 그대로 저장합니다. `--numbered`를 지정하면 찍은 순서대로 `001_20261114_211205.jpg`처럼 번호를 붙입니다.
- `ledger (--from-folder <폴더> | --mark-all | --leave-new)`: 이미 Mac에 받아 둔 사진과 동영상을 옮긴 기록에 추가합니다.
- `dump --out <폴더>`: 실기기 응답을 그대로 저장합니다. 기기 일련번호가 들어 있기 때문에 공개하지 않습니다.

가져오기를 하면 `~/Library/Application Support/Pullshot/`에 옮긴 기록이 저장됩니다. 새 항목은 이 기록에 없는, 즉 아직 한 번도 Mac으로 옮기지 않은 사진과 동영상입니다.

## 개발

```bash
brew bundle        # SwiftLint, SwiftFormat 설치
make setup-hooks   # 커밋 전 린트와 포맷 검사 설정
make build
make test
make check         # SwiftLint --strict, SwiftFormat --lint
```

코드 작성 규칙은 [docs/conventions.md](docs/conventions.md), 용어는 [docs/glossary.md](docs/glossary.md), 이슈와 PR 작성 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)에 정리되어 있습니다.

## 라이선스

MIT 라이선스로 배포합니다. 전문은 [LICENSE](LICENSE)에 있습니다.

Pullshot은 Nintendo가 만들거나 승인한 프로젝트가 아닌 개인 오픈소스 프로젝트입니다. Nintendo Switch와 Nintendo Switch 2는 Nintendo의 상표이며, 이 문서에서는 지원 기기를 표기하는 용도로만 사용합니다.

## 참고한 프로젝트

스위치가 응답하는 기본 PTP(카메라와 컴퓨터가 사진을 주고받는 USB 규약) 명령 10개, 스위치의 USB 제품 ID, 이전 연결이 닫지 못한 세션을 정리하는 순서는 [Tethersnap](https://github.com/Luminoid/Tethersnap)의 README와 CHANGELOG를 참고했습니다. 코드는 가져오지 않고 처음부터 새로 작성했습니다.
