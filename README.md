# Pullshot

Nintendo Switch 2와 Nintendo Switch(실험적 지원)의 스크린샷과 영상을 USB로 Mac에 옮기는 앱입니다. 캡처를 게임별, 플레이별로 보고 골라 가져옵니다.

지금은 개발 중입니다. 1단계로 기기와 통신하는 라이브러리(PullshotKit)와 개발용 CLI(`pullshot`)를 만들고 있습니다.

## 요구 사항

- macOS 15 이상
- 데이터 전송이 되는 USB-C 케이블
- 본체 아래쪽 USB-C 포트(독 아님)에 연결하고, 본체 설정의 데이터 관리 메뉴에서 PC로 복사 모드를 켭니다.

## 개발

```bash
brew bundle        # SwiftLint, SwiftFormat
make setup-hooks   # pre-commit 린트와 포맷 검사
make build
make test
make check         # SwiftLint --strict, SwiftFormat --lint
```

코딩 규칙은 [docs/conventions.md](docs/conventions.md), 용어는 [docs/glossary.md](docs/glossary.md), 설계는 [docs/superpowers/specs](docs/superpowers/specs)에 있습니다.

## 라이선스

MIT. [LICENSE](LICENSE)를 봅니다.

Pullshot은 Nintendo와 관계없는 독립 오픈소스 프로젝트입니다. Nintendo Switch와 Nintendo Switch 2는 Nintendo의 상표이며, 호환 기기를 설명하는 데만 씁니다.

## 감사의 글

스위치가 기본 PTP 명령 10개만 응답한다는 것, USB ID, 세션 복구에 관한 사실은 [Tethersnap](https://github.com/Luminoid/Tethersnap)의 README와 CHANGELOG에서 배웠습니다. 코드는 가져오지 않았습니다.
