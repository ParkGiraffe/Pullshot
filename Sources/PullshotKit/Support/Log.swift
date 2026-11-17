import os

public enum Log {
    private static let subsystem = "com.parkgiraffe.Pullshot"

    public static let usb = Logger(subsystem: subsystem, category: "usb")
    public static let ptp = Logger(subsystem: subsystem, category: "ptp")
    public static let album = Logger(subsystem: subsystem, category: "album")
    public static let library = Logger(subsystem: subsystem, category: "library")
    public static let app = Logger(subsystem: subsystem, category: "app")
}
