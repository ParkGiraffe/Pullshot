import Foundation

/// 받을 파일의 자리를 정합니다. 이미 있는 파일은 덮어쓰지 않습니다.
public enum DestinationNamer {
    public enum Decision: Equatable {
        case write(URL)
        /// 같은 이름과 크기의 파일이 이미 있어 받지 않습니다.
        case skip(URL)
    }

    /// 크기까지 같으면 건너뛰고, 이름만 같거나 크기를 모르면 "이름 2.확장자"처럼 비어 있는 다음 번호를 붙입니다.
    /// 번호 붙은 사본이 같은 크기로 이미 있어도 건너뜁니다. 그러지 않으면 다시 받을 때마다 사본이 하나씩 늘어납니다.
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
