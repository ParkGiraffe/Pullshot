import Foundation
import PullshotKit
import UniformTypeIdentifiers

struct CaptureDrag {
    let captures: [Capture]
    let shouldMakeGameFolder: Bool
    let naming: ExportNaming

    var isFolder: Bool {
        captures.count > 1
    }

    private var hasManyGames: Bool {
        Set(captures.map(\.gameName)).count > 1
    }

    var name: String {
        guard isFolder else { return items(at: .temporaryDirectory).first?.filename ?? "" }
        return hasManyGames ? "Pullshot" : captures[0].gameName
    }

    var fileType: UTType {
        isFolder ? .folder : UTType(filenameExtension: (name as NSString).pathExtension) ?? .data
    }

    func items(at destination: URL) -> [TransferItem] {
        let options = ExportOptions(
            baseFolder: isFolder ? destination : destination.deletingLastPathComponent(),
            shouldMakeGameFolder: isFolder && hasManyGames && shouldMakeGameFolder,
            naming: naming
        )
        return TransferItem.exports(captures, options: options)
    }
}
