import os

/// 통합 로그 분류입니다. 파일 이름, 게임 이름, 경로, 일련번호는 `privacy: .private`로 남깁니다.
public enum Log {
    private static let subsystem = "com.parkgiraffe.Pullshot"

    public static let usb = Logger(subsystem: subsystem, category: "usb")
    public static let ptp = Logger(subsystem: subsystem, category: "ptp")
    public static let album = Logger(subsystem: subsystem, category: "album")
    public static let library = Logger(subsystem: subsystem, category: "library")
}
