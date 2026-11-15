# Pullshot

Nintendo Switch 2와 Nintendo Switch에서 찍은 스크린샷과 영상을 USB 케이블로 Mac에 옮기는 앱입니다. 캡처를 게임별로 묶고, 게임 안에서는 한 번 앉아서 플레이한 단위로 나눠 보여 주며, 필요한 것만 골라 가져올 수 있습니다. Nintendo Switch 지원은 실험 단계입니다.

## 진행 상황

앱 화면은 아직 없습니다. 스위치와 통신하는 라이브러리(PullshotKit)와 개발용 CLI(`pullshot`)가 완성된 상태이고, 지금은 가져오기와 내보내기 기능을 개발하고 있습니다.

## 요구 사항

- macOS 15 이상
- 데이터 전송을 지원하는 USB-C 케이블

## 연결 방법

1. 독이 아니라 본체 아래쪽 USB-C 포트에 케이블을 연결합니다.
2. 본체 설정의 데이터 관리 메뉴에서 PC로 복사를 켭니다.

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
