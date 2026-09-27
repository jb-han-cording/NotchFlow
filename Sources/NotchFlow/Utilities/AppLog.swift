import os

enum AppLog {
    static let app = Logger(subsystem: "local.NotchFlow", category: "app")
    static let storage = Logger(subsystem: "local.NotchFlow", category: "storage")
    static let permissions = Logger(subsystem: "local.NotchFlow", category: "permissions")
}
