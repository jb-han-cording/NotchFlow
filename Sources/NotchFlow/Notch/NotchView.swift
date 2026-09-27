import SwiftUI
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import NotchFlowCore
#endif

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct NotchView: View {
    @ObservedObject var app: AppState
    @ObservedObject var model: NotchViewModel
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject var notifications: NotificationManager
    @ObservedObject var music: MusicViewModel
    @ObservedObject var calendar: CalendarViewModel
    @Environment(\.colorScheme) private var systemScheme
    private var scheme: ColorScheme { settings.value.theme == "Light" ? .light : settings.value.theme == "Dark" ? .dark : systemScheme }
    private var isExpandedOrHover: Bool { model.state == .expanded || model.state == .hover }
    private var isShowingNotificationBanner: Bool {
        model.state == .notification && notifications.current != nil && !isExpandedOrHover
    }

    var body: some View {
        GeometryReader { viewport in
        VStack(spacing: 0) {
            islandHeader
            if isShowingNotificationBanner, let item = notifications.current {
                notificationBanner(item)
            } else if isExpandedOrHover {
                expanded
                    // Lay out controls once at their final width, then reveal
                    // equally on both sides instead of reflowing from an edge.
                    .frame(width: min(settings.value.expandedWidth, model.geometry.screen.width - 16))
                    .frame(width: viewport.size.width, alignment: .center)
            }
        }
        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
        }
        .clipped()
        .background(background)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: (isExpandedOrHover || isShowingNotificationBanner) ? settings.value.cornerRadius : 10,
                bottomTrailingRadius: (isExpandedOrHover || isShowingNotificationBanner) ? settings.value.cornerRadius : 10
            )
        )
        .preferredColorScheme(settings.value.theme == "Light" ? .light : settings.value.theme == "Dark" ? .dark : nil)
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { model.state == .dragActive }, set: { active in if active { model.send(.dragEnter) } else { model.send(.dragExit) } })) { providers in
            for provider in providers {
                let _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in app.shelf.add([url]) }
                    } else if let url = item as? URL {
                        Task { @MainActor in app.shelf.add([url]) }
                    }
                }
            }
            model.send(.drop)
            return true
        }
    }

    private var islandHeader: some View {
        Button {
            model.activateHeader()
        } label: {
            ZStack {
                Color.black.opacity(0.001)
                    .frame(width: max(model.geometry.cutout.width, 160))

                if app.timer.active {
                    CompactTimerView(timer: app.timer, cutoutWidth: max(model.geometry.cutout.width, 160))
                        .opacity((!isExpandedOrHover && !isShowingNotificationBanner) ? 1 : 0)
                } else if model.musicIslandVisible {
                    let cutoutWidth = max(model.geometry.cutout.width, 160)
                    let sideOffset = cutoutWidth / 2 + 22

                    AlbumArtworkView(track: music.track ?? music.lastTrack, size: min(24, max(18, model.geometry.cutout.height - 4)))
                        .opacity((!isExpandedOrHover && !isShowingNotificationBanner) ? 1 : 0)
                        .offset(x: -sideOffset)

                    AudioEqualizerView(isPlaying: music.track?.isPlaying ?? false, style: settings.value.equalizerColor, barCount: 5, isVisible: !isExpandedOrHover && !isShowingNotificationBanner)
                        .opacity((!isExpandedOrHover && !isShowingNotificationBanner) ? 1 : 0)
                        .offset(x: sideOffset)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(model.geometry.cutout.height, 24))
            .background(
                isExpandedOrHover
                    ? Color.clear
                    : Color.black
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("NotchFlow 펼치기")
    }

    @ViewBuilder private var background: some View {
        ZStack {
            VisualEffectView()
                .opacity((settings.value.liquidGlass || (settings.value.blur && isExpandedOrHover)) ? 1 : 0)

            if settings.value.liquidGlass {
                let glassOpacity = settings.value.liquidGlassGlassiness
                (scheme == .dark ? Color.black.opacity(glassOpacity) : Color.white.opacity(glassOpacity * 0.75))
                UnevenRoundedRectangle(
                    bottomLeadingRadius: (isExpandedOrHover || isShowingNotificationBanner) ? settings.value.cornerRadius : 10,
                    bottomTrailingRadius: (isExpandedOrHover || isShowingNotificationBanner) ? settings.value.cornerRadius : 10
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(max(0.15, glassOpacity * 1.1)),
                            Color.white.opacity(max(0.05, glassOpacity * 0.35))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
            } else {
                Color.black
                if isExpandedOrHover {
                    (scheme == .dark ? Color.black : Color(nsColor: .windowBackgroundColor)).opacity(settings.value.opacity)
                }
            }
        }
    }

    private var expanded: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Module.allCases.filter { app.isEnabled($0) }) { module in
                    Button {
                        app.selectedModule = module
                    } label: { Image(systemName: module.icon).frame(width: 44, height: 44) }
                    .buttonStyle(NotchIconButtonStyle(selected: app.selectedModule == module))
                    .help(module.rawValue)
                    .accessibilityLabel(module.rawValue)
                }
                Spacer()
                Button {
                    app.showSettings?()
                } label: { Image(systemName: "gearshape") }.buttonStyle(NotchIconButtonStyle()).help("설정").accessibilityLabel("설정")
                Button { model.send(.close) } label: { Image(systemName: "chevron.up") }.buttonStyle(NotchIconButtonStyle()).help("접기 · Esc").accessibilityLabel("접기")
            }
            .frame(height: 44)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 6)

            if let item = notifications.current {
                notificationBanner(item)
                    .padding(4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 18)
            }

            selectedModuleContent
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190, alignment: .topLeading)
        .clipped()
        .buttonStyle(NotchActionButtonStyle()).controlSize(.large)
    }

    @ViewBuilder
    private var selectedModuleContent: some View {
        ZStack(alignment: .topLeading) {
            switch app.selectedModule {
            case .dashboard: DashboardView(app: app, music: app.music, calendar: app.calendar, shelf: app.shelf, memo: app.memo)
            case .music: MusicView(model: app.music, settings: app.settings)
            case .calendar: CalendarView(model: app.calendar)
            case .shelf: FileShelfView(model: app.shelf)
        case .memo: MemoView(model: app.memo)
        case .timer: FocusTimerView(timer: app.timer)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .id(app.selectedModule)
    }

    private func notificationBanner(_ item: NotchNotification) -> some View {
        HStack(spacing: 12) {
            if item.kind == .music {
                AlbumArtworkView(track: music.track, size: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if item.kind == .music {
                        Text("NOW PLAYING")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.notchBlue)
                    }
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                Text(item.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if item.kind == .music {
                AudioEqualizerView(isPlaying: music.track?.isPlaying ?? false, style: settings.value.equalizerColor, barCount: 6, maxHeight: 18)
            }

            Button {
                notifications.dismissCurrent()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(NotchIconButtonStyle())
            .accessibilityLabel("알림 닫기")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
