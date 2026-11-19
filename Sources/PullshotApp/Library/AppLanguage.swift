enum AppLanguage: String, CaseIterable {
    case system
    case english
    case korean

    var preferredLanguages: [String]? {
        switch self {
        case .system: nil
        case .english: ["en"]
        case .korean: ["ko"]
        }
    }
}
