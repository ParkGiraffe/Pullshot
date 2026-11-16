/// `UserDefaults`에 두는 설정의 키입니다. 실행 인자(`-ledgerFolder <경로>`, `-demoAlbum YES`)도 같은 키로 덮어씁니다.
enum SettingsKey: String {
    case ledgerFolder
    case importFolder
    case exportFolder
    case makesGameFolder
    case exportNaming
    case thumbnailSize
    case viewMode
    case isVerboseLog
    case demoAlbum
}
