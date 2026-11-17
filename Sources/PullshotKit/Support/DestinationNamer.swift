import Foundation

public enum DestinationNamer {
    public enum Decision: Equatable {
        case write(URL)
        case skip(URL)
    }

    public static func decide(filename: String, size: UInt64?, in folder: URL) -> Decision {
        let original = folder.appending(path: filename)
        guard let existingSize = sizeOfFile(at: original) else { return .write(original) }
        if existingSize == size {
            return .skip(original)
        }
        let name = filename as NSString
        let numbered = { (number: Int) in
            name.pathExtension.isEmpty
                ? folder.appending(path: "\(name) \(number)")
                : folder.appending(path: "\(name.deletingPathExtension) \(number).\(name.pathExtension)")
        }
        var number = 2
        while let numberedSize = sizeOfFile(at: numbered(number)) {
            if numberedSize == size {
                return .skip(numbered(number))
            }
            number += 1
        }
        return .write(numbered(number))
    }

    private static func sizeOfFile(at url: URL) -> UInt64? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return (attributes?[.size] as? NSNumber)?.uint64Value
    }
}
