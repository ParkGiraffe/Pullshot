# Pullshot

Nintendo Switch 2와 Nintendo Switch에서 찍은 스크린샷과 영상을 USB 케이블로 Mac에 옮기는 앱입니다. 캡처를 게임별로 묶어 보여 주고, 필요한 것만 골라 가져올 수 있습니다. Nintendo Switch 지원은 실험 단계입니다.

## 진행 상황

앱 화면은 아직 없습니다. 스위치와 통신하는 라이브러리(PullshotKit)와 개발용 CLI(`pullshot`)로 캡처 목록 보기, 가져오기, 번호 붙여 내보내기까지 할 수 있고, 다음 단계에서 앱 화면을 만듭니다.

## 요구 사항

- macOS 15 이상
- 데이터 전송을 지원하는 USB-C 케이블

## 연결 방법

1. 독이 아니라 본체 아래쪽 USB-C 포트에 케이블을 연결합니다.
2. 본체 설정의 데이터 관리 메뉴에서 PC로 복사를 켭니다.

## CLI

개발과 문제 확인에 쓰는 명령입니다. `swift run pullshot <명령>`으로 실행합니다.

- `probe`: 기기 정보, 지원 명령, 저장소를 보여 줍니다.
- `list [--new]`: 게임별 캡처 목록을 보여 줍니다. 새 항목에는 줄 끝에 "새"가 붙습니다.
- `pull (--all | --new | <파일 이름>...)`: 캡처를 `~/Pictures/Pullshot/<게임 이름>/`에 원본 그대로 받습니다.
- `export (--all | --new | <파일 이름>...) --out <폴더> [--numbered] [--no-game-folder] [--dry-run]`: 고른 캡처를 내보냅니다. `--numbered`를 주면 찍은 순서대로 `001_20261114_211205.jpg`처럼 번호를 붙입니다.
- `ledger (--from-folder <폴더> | --mark-all | --leave-new)`: 이미 받아 둔 캡처를 옮긴 기록에 넣습니다.
- `dump --out <폴더>`: 실기기 응답을 그대로 기록합니다. 기기 일련번호가 들어 있으므로 공개하지 않습니다.

가져오기와 내보내기는 `~/Library/Application Support/Pullshot/`에 옮긴 기록을 남깁니다. 기록에 없는 캡처, 곧 아직 한 번도 Mac으로 옮기지 않은 캡처가 새 항목입니다.

## 개발

```bash
brew bundle        # SwiftLint, SwiftFormat 설치
make setup-hooks   # 커밋 전 린트와 포맷 검사 설정
make build
make test
make check         # SwiftLint --strict, SwiftFormat --lint
```

코딩 규칙은 [docs/conventions.md](docs/conventions.md), 용어는 [docs/glossary.md](docs/glossary.md), 설계 문서는 [docs/superpowers/specs](docs/superpowers/specs)에 있습니다.

## 라이선스

MIT 라이선스로 배포합니다. 전문은 [LICENSE](LICENSE)에 있고, CLI가 쓰는 swift-argument-parser의 라이선스 고지는 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)에 있습니다.

Pullshot은 Nintendo가 만들거나 승인한 프로젝트가 아닌 개인 오픈소스 프로젝트입니다. Nintendo Switch와 Nintendo Switch 2는 Nintendo의 상표이며, 이 문서에서는 지원하는 기기를 밝히는 데에만 씁니다.

## 참고한 프로젝트

스위치가 응답하는 기본 PTP(카메라와 컴퓨터가 사진을 주고받는 USB 규약) 명령 10개, 스위치의 USB 제품 ID, 앞 연결이 닫지 못한 세션을 정리하는 순서는 [Tethersnap](https://github.com/Luminoid/Tethersnap)의 README와 CHANGELOG에서 알게 되었습니다. 코드는 가져오지 않고 처음부터 새로 작성했습니다.
