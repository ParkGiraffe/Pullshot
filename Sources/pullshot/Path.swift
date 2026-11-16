import ArgumentParser
import Foundation

/// 명령줄에서 받은 경로입니다. 따옴표 안처럼 셸이 펼치지 않은 `~`도 홈 폴더로 펼칩니다.
struct Path: ExpressibleByArgument {
    var url: URL

    var defaultValueDescription: String {
        url.path(percentEncoded: false)
    }

    init(argument: String) {
        url = URL(filePath: (argument as NSString).expandingTildeInPath)
    }
}
