public enum PTP {
    public static let rootParent: UInt32 = 0xFFFF_FFFF
    public static let sessionID: UInt32 = 1

    public enum ContainerKind: UInt16, Sendable {
        case command = 1
        case data = 2
        case response = 3
        case event = 4
    }

    public struct Operation: RawRepresentable, Hashable, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static let getDeviceInfo = Self(rawValue: 0x1001)
        public static let openSession = Self(rawValue: 0x1002)
        public static let closeSession = Self(rawValue: 0x1003)
        public static let getStorageIDs = Self(rawValue: 0x1004)
        public static let getStorageInfo = Self(rawValue: 0x1005)
        public static let getNumObjects = Self(rawValue: 0x1006)
        public static let getObjectHandles = Self(rawValue: 0x1007)
        public static let getObjectInfo = Self(rawValue: 0x1008)
        public static let getObject = Self(rawValue: 0x1009)
        public static let getThumb = Self(rawValue: 0x100A)
    }

    public struct Response: RawRepresentable, Hashable, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static let ok = Self(rawValue: 0x2001)
        public static let generalError = Self(rawValue: 0x2002)
        public static let sessionNotOpen = Self(rawValue: 0x2003)
        public static let invalidTransactionID = Self(rawValue: 0x2004)
        public static let operationNotSupported = Self(rawValue: 0x2005)
        public static let parameterNotSupported = Self(rawValue: 0x2006)
        public static let incompleteTransfer = Self(rawValue: 0x2007)
        public static let invalidObjectHandle = Self(rawValue: 0x2009)
        public static let accessDenied = Self(rawValue: 0x200F)
        public static let noThumbnailPresent = Self(rawValue: 0x2010)
        public static let storeNotAvailable = Self(rawValue: 0x2013)
        public static let deviceBusy = Self(rawValue: 0x2019)
        public static let sessionAlreadyOpen = Self(rawValue: 0x201E)
    }

    public struct ObjectFormat: RawRepresentable, Hashable, Sendable {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static let undefined = Self(rawValue: 0x3000)
        public static let association = Self(rawValue: 0x3001)
        public static let mpeg = Self(rawValue: 0x300B)
        public static let exifJPEG = Self(rawValue: 0x3801)
        public static let png = Self(rawValue: 0x380B)
        public static let mp4Container = Self(rawValue: 0xB982)
    }
}
