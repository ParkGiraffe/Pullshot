import ArgumentParser
import Foundation

struct Path: ExpressibleByArgument {
    var url: URL

    var defaultValueDescription: String {
        url.path(percentEncoded: false)
    }

    init(argument: String) {
        url = URL(filePath: (argument as NSString).expandingTildeInPath)
    }
}
