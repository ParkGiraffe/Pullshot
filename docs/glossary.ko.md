# 용어

[English](glossary.md) | 한국어 <!-- write-exempt -->

| 용어 | 뜻 | 코드 |
|---|---|---|
| 기기 | 기기는 사진과 동영상을 보내 주는 Nintendo Switch 2 또는 Nintendo Switch입니다. | `ConsoleModel`, `AttachedConsole` |
| PC로 복사 모드 | PC로 복사 모드는 기기가 USB로 사진과 동영상을 보내는 상태이며, 본체 설정의 데이터 관리 메뉴에서 켭니다. 꺼진 채 연결된 기기는 대기 상태라고 합니다. | `LibraryModel.Connection.notInTransferMode`, `ConsoleLocator.idle()` |
| 전송 | 전송은 기기와 바이트를 주고받는 통로이며, 실제 USB, 테스트용 목, 기록과 재생이 있습니다. | `Transport` |
| 세션 | 세션은 기기와 연 PTP 세션이며, 핸들과 저장소 ID는 세션 안에서만 유효합니다. | `Session` |
| 앨범 | 앨범은 기기에 저장된 사진과 동영상 전체입니다. | `AlbumScan` |
| 캡처 | 캡처는 기기가 찍은 사진 한 장이나 동영상 하나이며, 코드에서만 쓰는 이름입니다. 앱 화면과 문서에서는 "사진과 동영상"이나 "사진", "동영상"이라고 씁니다. | `Capture` |
| 항목 | 항목은 화면의 목록과 칸 이름(모든 항목, 새 항목, 선택한 항목)에서 사진과 동영상을 부르는 이름입니다. | |
| 게임 | 게임은 사진과 동영상이 든 앨범 폴더이며, 폴더 이름이 게임 이름입니다. 앱 사이드바에서는 폴더라고 씁니다. | `Game`, `Capture.gameName`, `LibraryModel.gameSearch` |
| 기타 | 기타는 게임 폴더 밖에 있거나 스위치의 "기타" 폴더에 든 사진과 동영상의 묶음입니다. 가져온 기록의 키에는 원래 폴더 이름을 그대로 저장합니다. | `Game.isOther`, `Game.otherFolderName` |
| 저장 위치 | 저장 위치는 앱이 가져온 사진과 동영상을 저장하는 기준 폴더이며, 기본값은 `~/Pictures/Pullshot`입니다. | `AppSettings.importFolder` |
| 가져오기 | 가져오기는 앱의 가져오기 버튼, Finder로 드래그하기, CLI의 `pull`로 사진과 동영상을 Mac에 복사하고 가져온 기록에 추가하는 것입니다. 앱에서 새 항목과 모두 가져오기는 저장 위치의 게임 이름 폴더에 원래 이름 그대로 저장하고, 선택한 항목을 가져올 때는 폴더별로 나눠 저장할지와 번호를 붙일지 선택할 수 있습니다. Finder로 드래그하면 놓은 곳에 저장합니다. 하나만 드래그하면 파일 하나를 저장하고, 여러 개는 게임 이름 폴더를 만들어 그 안에 저장하며, 여러 게임이 섞이면 Pullshot 폴더를 만들어 저장합니다. | `Transfer`, `ImportTarget`, `CaptureDrag`, `TransferKind.imported` |
| 내보내기 | 내보내기는 가져온 기록에서 일반 가져오기와 구분해 남기는 기록 종류이며, 앱 화면과 CLI 명령에는 쓰지 않습니다. 앱에서 선택한 항목을 가져오거나 Finder로 드래그하면 폴더별 저장과 파일 이름 설정과 상관없이 늘 내보내기로 기록하고, CLI `pull`은 `--numbered`나 `--no-game-folder`를 지정할 때만 내보내기로 기록합니다. | `TransferKind.exported`, `ExportOptions` |
| 가져온 기록 | 가져온 기록은 가져오거나 폴더에서 찾았거나 모두 가져온 것으로 표시한 사진과 동영상을 기기 일련번호, 기록 종류와 함께 저장한 파일이며, 새 항목은 이 기록으로 구분합니다. | `TransferLedger`, `TransferKind`, `CaptureKey` |
| 새 항목 | 새 항목은 가져온 기록에 없는 사진과 동영상입니다. | `LedgerIndex.newCaptures` |
