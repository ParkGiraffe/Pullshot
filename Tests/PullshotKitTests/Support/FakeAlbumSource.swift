import Foundation
@testable import PullshotKit

/// 폴더 나무를 흉내 내는 앨범입니다. 받은 부모 인자를 모아 두어 평면 질의를 했는지 확인합니다.
final class FakeAlbumSource: AlbumSource {
    enum Node {
        case folder(UInt32, String, [Self])
        case file(UInt32, String, format: PTP.ObjectFormat = .exifJPEG, size: UInt32 = 1000, captureDate: String = "")
    }

    static let storage: UInt32 = 0x0001_0001

    private var children: [UInt32: [UInt32]] = [:]
    private var infos: [UInt32: ObjectInfo] = [:]
    private var storages = [storage]
    var storageErrors: [UInt32: SessionError] = [:]
    var objectInfoErrors: [UInt32: Error] = [:]
    private(set) var requestedParents: [UInt32] = []

    static func tree(
        _ nodes: [Node],
        extraStorage: UInt32? = nil,
        extraStorageError: SessionError? = nil
    ) -> FakeAlbumSource {
        let source = FakeAlbumSource()
        source.add(nodes, under: PTP.rootParent, parentField: 0)
        if let extraStorage {
            source.storages.append(extraStorage)
            source.storageErrors[extraStorage] = extraStorageError
        }
        return source
    }

    /// 폴더 하나가 자기 자신을 자식으로 다시 돌려주게 만듭니다.
    func makeCycle(at folder: UInt32) {
        children[folder, default: []].append(folder)
    }

    func storageIDs() throws -> [UInt32] {
        storages
    }

    func objectHandles(storage: UInt32, parent: UInt32) throws -> [UInt32] {
        requestedParents.append(parent)
        if let error = storageErrors[storage] {
            throw error
        }
        return children[parent] ?? []
    }

    func objectInfo(_ handle: UInt32) throws -> ObjectInfo {
        if let error = objectInfoErrors[handle] {
            throw error
        }
        guard let info = infos[handle] else {
            throw SessionError.response(.invalidObjectHandle, operation: .getObjectInfo)
        }
        return info
    }

    private func add(_ nodes: [Node], under parent: UInt32, parentField: UInt32) {
        for node in nodes {
            switch node {
            case let .folder(handle, name, inner):
                children[parent, default: []].append(handle)
                infos[handle] = info(name, format: .association, size: 0, parent: parentField, captureDate: "")
                add(inner, under: handle, parentField: handle)
            case let .file(handle, name, format, size, captureDate):
                children[parent, default: []].append(handle)
                infos[handle] = info(name, format: format, size: size, parent: parentField, captureDate: captureDate)
            }
        }
    }

    private func info(
        _ name: String,
        format: PTP.ObjectFormat,
        size: UInt32,
        parent: UInt32,
        captureDate: String
    ) -> ObjectInfo {
        ObjectInfo(
            storageID: Self.storage,
            format: format,
            compressedSize: size,
            parent: parent,
            filename: name,
            captureDate: captureDate,
            modificationDate: ""
        )
    }
}
