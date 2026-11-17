# 용어

| 용어 | 뜻 | 코드 |
|---|---|---|
| 기기 | 캡처를 보내 주는 Nintendo Switch 2 또는 Nintendo Switch입니다. | `ConsoleModel`, `AttachedConsole` |
| PC로 복사 모드 | 기기가 USB로 캡처를 보내는 상태입니다. 본체 설정의 데이터 관리 메뉴에서 켭니다. | |
| 전송 | 기기와 바이트를 주고받는 통로입니다. 실제 USB, 테스트용 가짜, 기록과 재생이 있습니다. | `Transport` |
| 세션 | 기기와 연 PTP 세션입니다. 핸들과 저장소 ID는 세션 안에서만 뜻이 있습니다. | `Session` |
| 앨범 | 기기에 저장된 캡처 전체입니다. | `AlbumScan` |
| 캡처 | 기기가 찍은 사진 한 장이나 동영상 하나입니다. 앱 화면에는 캡처라고 쓰지 않고 "사진과 동영상"이나 "사진", "동영상"이라고 씁니다. | `Capture` |
| 항목 | 화면의 목록과 칸 이름(모든 항목, 새 항목, 고른 항목)에서 캡처를 부르는 말입니다. 화면 문장에서는 "사진과 동영상"이라고 쓰고, 코드와 문서의 문장에서는 캡처라고 씁니다. | |
| 게임 | 캡처가 든 앨범 폴더입니다. 폴더 이름이 게임 이름입니다. | `Game`, `Capture.gameName` |
| 기타 | 게임 폴더 밖에 있거나 스위치의 "기타" 폴더에 든 캡처의 묶음입니다. 옮긴 기록의 키에는 원래 폴더 이름을 그대로 둡니다. | `Game.isOther`, `Game.otherFolderName` |
| 옮김 | 가져오기나 CLI의 `pull`, `export`로 캡처를 Mac에 저장한 일입니다. | `Transfer`, `TransferKind` |
| 저장 위치 | 앱이 가져온 캡처를 두는 기준 폴더입니다. 기본값은 `~/Pictures/Pullshot`입니다. | `AppSettings.importFolder` |
| 가져오기 | 캡처를 저장 위치에 받는 일입니다. 새 항목과 모두 가져오기는 게임 이름 폴더에 원래 이름 그대로 받고, 고른 것을 가져올 때는 폴더별로 나눠 저장할지와 번호 붙이기를 고를 수 있습니다. | `ImportTarget`, `TransferKind.imported` |
| 내보내기 | CLI의 `export`가 고른 캡처를 `--out` 폴더에 받는 일입니다. 앱의 고른 것 가져오기도 같은 규칙으로 두고 옮긴 기록에 내보내기로 남깁니다. 앱 화면에는 쓰지 않습니다. | `TransferKind.exported`, `ExportOptions` |
| 옮긴 기록 | 옮긴 캡처를 기기 일련번호와 함께 적어 둔 파일입니다. 새 항목은 이 기록으로 가립니다. | `TransferLedger`, `CaptureKey` |
| 새 항목 | 아직 한 번도 옮기지 않은 캡처입니다. | `LedgerIndex.newCaptures` |
