import Foundation

enum UpdateCheck: Equatable {
    case available(version: String, page: URL)
    case upToDate
    case failed

    static func fetch(current: String) async -> Self {
        guard let url = URL(string: "https://api.github.com/repos/ParkGiraffe/Pullshot/releases/latest") else {
            return .failed
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (body, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return .failed }
        return Self(current: current, status: status, body: body)
    }

    init(current: String, status: Int, body: Data) {
        switch status {
        case 200:
            guard let release = try? JSONDecoder().decode(LatestRelease.self, from: body) else {
                self = .failed
                return
            }
            let version = String(release.tagName.trimmingPrefix("v"))
            self = Self.numbers(of: current).lexicographicallyPrecedes(Self.numbers(of: version))
                ? .available(version: version, page: release.htmlURL)
                : .upToDate
        case 404:
            self = .upToDate
        default:
            self = .failed
        }
    }

    private static func numbers(of version: String) -> [Int] {
        let numbers = version.split(separator: ".").map { Int($0) ?? 0 }
        return numbers + Array(repeating: 0, count: max(0, 3 - numbers.count))
    }
}

private struct LatestRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
