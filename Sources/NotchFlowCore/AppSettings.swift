import Foundation

public struct AppSettings: Codable, Equatable {
    public var autoHideApps: [String] = []
    public var batteryNotifications: Bool = true
    public var shelfRetentionHours: Int = 0
    public var openOnHover = true
    public var openOnClick = true
    public var hoverDelay = 0.25
    public var animationSpeed = 0.32
    public var showMenuBarIcon = true
    public var hasCompletedOnboarding = false
    public var automaticUpdateChecks = true
    public var musicEnabled = true
    public var calendarEnabled = true
    public var shelfEnabled = true
    public var memoEnabled = true
    public var theme = "System"
    public var expandedWidth = 720.0
    public var cornerRadius = 24.0
    public var opacity = 0.97
    public var blur = true
    public var expandOnTrackChange = true
    public var calendarNotifications = true
    public var fileNotifications = true
    public var memoNotifications = true
    public var screenID = ""
    public var shortcut = "Option + Space"
    public var musicProvider = "Apple Music"
    public var liquidGlass = true
    public var liquidGlassGlassiness = 0.35
    public var equalizerColor = "Blue"

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case autoHideApps, batteryNotifications, shelfRetentionHours
        case openOnHover, openOnClick, hoverDelay, animationSpeed, showMenuBarIcon, hasCompletedOnboarding, automaticUpdateChecks
        case musicEnabled, calendarEnabled, shelfEnabled, memoEnabled
        case theme, expandedWidth, cornerRadius, opacity, blur
        case expandOnTrackChange = "musicNotifications"
        case calendarNotifications, fileNotifications, memoNotifications
        case screenID, shortcut, musicProvider, liquidGlass, liquidGlassGlassiness, equalizerColor
    }

    public init(from decoder: Decoder) throws {
        let defaults = AppSettings()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        autoHideApps = try values.decodeIfPresent([String].self, forKey: .autoHideApps) ?? defaults.autoHideApps
        batteryNotifications = try values.decodeIfPresent(Bool.self, forKey: .batteryNotifications) ?? defaults.batteryNotifications
        shelfRetentionHours = try values.decodeIfPresent(Int.self, forKey: .shelfRetentionHours) ?? defaults.shelfRetentionHours
        openOnHover = try values.decodeIfPresent(Bool.self, forKey: .openOnHover) ?? defaults.openOnHover
        openOnClick = try values.decodeIfPresent(Bool.self, forKey: .openOnClick) ?? defaults.openOnClick
        hoverDelay = try values.decodeIfPresent(Double.self, forKey: .hoverDelay) ?? defaults.hoverDelay
        animationSpeed = try values.decodeIfPresent(Double.self, forKey: .animationSpeed) ?? defaults.animationSpeed
        showMenuBarIcon = try values.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? defaults.showMenuBarIcon
        hasCompletedOnboarding = try values.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
        automaticUpdateChecks = try values.decodeIfPresent(Bool.self, forKey: .automaticUpdateChecks) ?? defaults.automaticUpdateChecks
        musicEnabled = try values.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? defaults.musicEnabled
        calendarEnabled = try values.decodeIfPresent(Bool.self, forKey: .calendarEnabled) ?? defaults.calendarEnabled
        shelfEnabled = try values.decodeIfPresent(Bool.self, forKey: .shelfEnabled) ?? defaults.shelfEnabled
        memoEnabled = try values.decodeIfPresent(Bool.self, forKey: .memoEnabled) ?? defaults.memoEnabled
        theme = try values.decodeIfPresent(String.self, forKey: .theme) ?? defaults.theme
        expandedWidth = try values.decodeIfPresent(Double.self, forKey: .expandedWidth) ?? defaults.expandedWidth
        cornerRadius = try values.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        opacity = try values.decodeIfPresent(Double.self, forKey: .opacity) ?? defaults.opacity
        blur = try values.decodeIfPresent(Bool.self, forKey: .blur) ?? defaults.blur
        expandOnTrackChange = try values.decodeIfPresent(Bool.self, forKey: .expandOnTrackChange) ?? defaults.expandOnTrackChange
        calendarNotifications = try values.decodeIfPresent(Bool.self, forKey: .calendarNotifications) ?? defaults.calendarNotifications
        fileNotifications = try values.decodeIfPresent(Bool.self, forKey: .fileNotifications) ?? defaults.fileNotifications
        memoNotifications = try values.decodeIfPresent(Bool.self, forKey: .memoNotifications) ?? defaults.memoNotifications
        screenID = try values.decodeIfPresent(String.self, forKey: .screenID) ?? defaults.screenID
        shortcut = try values.decodeIfPresent(String.self, forKey: .shortcut) ?? defaults.shortcut
        musicProvider = try values.decodeIfPresent(String.self, forKey: .musicProvider) ?? defaults.musicProvider
        liquidGlass = try values.decodeIfPresent(Bool.self, forKey: .liquidGlass) ?? defaults.liquidGlass
        liquidGlassGlassiness = try values.decodeIfPresent(Double.self, forKey: .liquidGlassGlassiness) ?? defaults.liquidGlassGlassiness
        equalizerColor = try values.decodeIfPresent(String.self, forKey: .equalizerColor) ?? defaults.equalizerColor
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(autoHideApps, forKey: .autoHideApps)
        try container.encode(batteryNotifications, forKey: .batteryNotifications)
        try container.encode(shelfRetentionHours, forKey: .shelfRetentionHours)
        try container.encode(openOnHover, forKey: .openOnHover)
        try container.encode(openOnClick, forKey: .openOnClick)
        try container.encode(hoverDelay, forKey: .hoverDelay)
        try container.encode(animationSpeed, forKey: .animationSpeed)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(automaticUpdateChecks, forKey: .automaticUpdateChecks)
        try container.encode(musicEnabled, forKey: .musicEnabled)
        try container.encode(calendarEnabled, forKey: .calendarEnabled)
        try container.encode(shelfEnabled, forKey: .shelfEnabled)
        try container.encode(memoEnabled, forKey: .memoEnabled)
        try container.encode(theme, forKey: .theme)
        try container.encode(expandedWidth, forKey: .expandedWidth)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(blur, forKey: .blur)
        try container.encode(expandOnTrackChange, forKey: .expandOnTrackChange)
        try container.encode(calendarNotifications, forKey: .calendarNotifications)
        try container.encode(fileNotifications, forKey: .fileNotifications)
        try container.encode(memoNotifications, forKey: .memoNotifications)
        try container.encode(screenID, forKey: .screenID)
        try container.encode(shortcut, forKey: .shortcut)
        try container.encode(musicProvider, forKey: .musicProvider)
        try container.encode(liquidGlass, forKey: .liquidGlass)
        try container.encode(liquidGlassGlassiness, forKey: .liquidGlassGlassiness)
        try container.encode(equalizerColor, forKey: .equalizerColor)
    }

    public mutating func normalize() {
        if ![0, 1, 24, 168].contains(shelfRetentionHours) { shelfRetentionHours = 0 }
        hoverDelay = min(1.5, max(0.05, hoverDelay))
        animationSpeed = min(0.8, max(0.1, animationSpeed))
        expandedWidth = min(900, max(380, expandedWidth))
        cornerRadius = min(40, max(12, cornerRadius))
        opacity = min(1, max(0.75, opacity))
        liquidGlassGlassiness = min(0.80, max(0.05, liquidGlassGlassiness))
        if !["Apple Music", "Spotify"].contains(musicProvider) { musicProvider = "Apple Music" }
        if !["System", "Dark", "Light"].contains(theme) { theme = "System" }
        if !["Option + Space", "Control + Option + Space", "Command + Shift + Space", "Disabled"].contains(shortcut) { shortcut = "Option + Space" }
        if !["Blue", "Neon Pink", "Cyan Wave", "Sunset Gradient", "Flame Red", "Monochrome White", "Rainbow"].contains(equalizerColor) { equalizerColor = "Blue" }
    }
}
