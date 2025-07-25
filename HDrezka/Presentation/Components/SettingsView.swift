import AVFoundation
import Defaults
import Sparkle
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Default(.mirror) private var currentMirror
    @Default(.isLoggedIn) private var isLoggedIn
    @Default(.playerFullscreen) private var playerFullscreen
    @Default(.hideMainWindow) private var hideMainWindow
    @Default(.defaultQuality) private var defaultQuality
    @Default(.spatialAudio) private var spatialAudio
    @Default(.theme) private var theme

    @Environment(\.modelContext) private var modelContext

    @Query(animation: .easeInOut) private var playerPositions: [PlayerPosition]
    @Query(animation: .easeInOut) private var selectPositions: [SelectPosition]

    @State private var mirror: URL?
    @State private var mirrorValid: Bool?
    @State private var mirrorCheck: DispatchWorkItem?

    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool
    @State private var updateCheckInterval: TimeInterval

    init(updater: SPUUpdater) {
        self.updater = updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        updateCheckInterval = updater.updateCheckInterval
    }

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text("key.mirror")

                    TextField("key.mirror", value: $mirror, format: .url, prompt: Text(currentMirror.absoluteString))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .onChange(of: mirror) {
                            withAnimation(.easeInOut) {
                                mirrorValid = nil
                            }

                            mirrorCheck?.cancel()

                            if mirror != nil {
                                mirrorCheck = DispatchWorkItem {
                                    withAnimation(.easeInOut) {
                                        mirrorValid = if let mirror,
                                                         !mirror.isFileURL,
                                                         let host = mirror.host(),
                                                         host != currentMirror.host()
                                        {
                                            true
                                        } else {
                                            false
                                        }
                                    }
                                }

                                if let mirrorCheck {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: mirrorCheck)
                                }
                            }
                        }

                    Button {
                        if currentMirror != _currentMirror.defaultValue {
                            migrateCookies(currentMirror, _currentMirror.defaultValue)

                            _currentMirror.reset()
                        }

                        mirrorValid = nil
                        mirrorCheck?.cancel()
                    } label: {
                        Image(systemName: "gobackward")
                    }
                    .buttonStyle(NavbarButtonStyle(width: 22, height: 22))
                }
                .padding(.horizontal, 15)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quinary)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(.tertiary, in: .rect(cornerRadius: 6).stroke(lineWidth: 1))

                if mirrorValid == true, let mirror, var urlComponents = URLComponents(url: mirror, resolvingAgainstBaseURL: false) {
                    Button {
                        urlComponents.scheme = "https"
                        urlComponents.path = "/"
                        urlComponents.port = nil
                        urlComponents.query = nil
                        urlComponents.fragment = nil
                        urlComponents.user = nil
                        urlComponents.password = nil

                        if let newMirror = urlComponents.url, currentMirror != newMirror {
                            migrateCookies(currentMirror, newMirror)

                            currentMirror = newMirror
                        }

                        withAnimation(.easeInOut) {
                            mirrorValid = nil
                        }

                        mirrorCheck?.cancel()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .bold()
                            .imageFill(1)
                            .clipShape(.rect(cornerRadius: 6))
                            .contentShape(.rect(cornerRadius: 6))
                            .overlay(Color.accentColor, in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 40)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text("key.theme")

                    Spacer()

                    Picker("key.theme", selection: $theme) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.localizedKey)
                                .tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                }
                .frame(height: 40)

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.playerFullscreen")

                    Spacer()

                    Toggle("key.playerFullscreen", isOn: $playerFullscreen)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .frame(height: 40)

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.hideMainWindow")

                    Spacer()

                    Toggle("key.hideMainWindow", isOn: $hideMainWindow)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .frame(height: 40)

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.spatialAudio")

                    Spacer()

                    Picker("key.spatialAudio", selection: $spatialAudio) {
                        ForEach(SpatialAudio.allCases) { format in
                            Text(format.localizedKey)
                                .tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                }
                .frame(height: 40)

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.defaultQuality")

                    Spacer()

                    Picker("key.defaultQuality", selection: $defaultQuality) {
                        ForEach(DefaultQuality.allCases) { quality in
                            Text(quality.localizedKey)
                                .tag(quality)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                }
                .frame(height: 40)

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.playerPositions-\(playerPositions.count.description)")
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(playerPositions.count)))

                    Spacer()

                    Button {
                        for position in playerPositions {
                            modelContext.delete(position)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.accentColor)
                            .bold()
                            .imageFill(1)
                            .frame(height: 30)
                            .clipShape(.rect(cornerRadius: 6))
                            .contentShape(.rect(cornerRadius: 6))
                            .overlay(Color.accentColor, in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(playerPositions.isEmpty)
                }
                .frame(height: 40)

                if !isLoggedIn {
                    Divider()

                    HStack(alignment: .center, spacing: 8) {
                        Text("key.selectPositions-\(selectPositions.count.description)")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(selectPositions.count)))

                        Spacer()

                        Button {
                            for position in selectPositions {
                                modelContext.delete(position)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.accentColor)
                                .bold()
                                .imageFill(1)
                                .frame(height: 30)
                                .clipShape(.rect(cornerRadius: 6))
                                .contentShape(.rect(cornerRadius: 6))
                                .overlay(Color.accentColor, in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectPositions.isEmpty)
                    }
                    .frame(height: 40)
                }
            }
            .padding(.horizontal, 15)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(.tertiary, in: .rect(cornerRadius: 6).stroke(lineWidth: 1))

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text("key.autoCheckUpdates")

                    Spacer()

                    Toggle("key.autoCheckUpdates", isOn: $automaticallyChecksForUpdates)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .frame(height: 40)
                .onChange(of: automaticallyChecksForUpdates) {
                    updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
                }

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.autoDownloadUpdates")

                    Spacer()

                    Toggle("key.autoDownloadUpdates", isOn: $automaticallyDownloadsUpdates)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .frame(height: 40)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) {
                    updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
                }

                Divider()

                HStack(alignment: .center, spacing: 8) {
                    Text("key.updateCheckInterval")

                    Spacer()

                    Picker("key.updateCheckInterval", selection: $updateCheckInterval) {
                        ForEach(UpdateInterval.allCases) { interval in
                            Text(interval.localizedKey)
                                .tag(TimeInterval(interval.rawValue))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                }
                .frame(height: 40)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: updateCheckInterval) {
                    updater.updateCheckInterval = updateCheckInterval
                }
            }
            .padding(.horizontal, 15)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(.tertiary, in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
        }
        .padding(25)
        .background(.background)
        .onChange(of: currentMirror) {
            mirror = nil
        }
    }

    private func migrateCookies(_ from: URL, _ to: URL) {
        if isLoggedIn {
            HTTPCookieStorage.shared.cookies(for: from)?.forEach { cookie in
                var cookieProperties = [HTTPCookiePropertyKey: Any]()
                cookieProperties[.version] = cookie.version
                cookieProperties[.name] = cookie.name
                cookieProperties[.value] = cookie.value
                cookieProperties[.expires] = cookie.expiresDate
                cookieProperties[.domain] = ".\(to.host() ?? "")"
                cookieProperties[.path] = cookie.path

                if let newCookie = HTTPCookie(properties: cookieProperties) {
                    HTTPCookieStorage.shared.setCookie(newCookie)
                }
            }
        }
    }
}

enum UpdateInterval: Double, CaseIterable, Identifiable {
    case hourly = 3600
    case daily = 86400
    case weekly = 604_800
    case monthly = 2_629_800

    var id: Self { self }

    var localizedKey: LocalizedStringKey {
        switch self {
        case .hourly:
            "key.hourly"
        case .daily:
            "key.daily"
        case .weekly:
            "key.weekly"
        case .monthly:
            "key.monthly"
        }
    }
}

enum DefaultQuality: String, CaseIterable, Identifiable, Defaults.Serializable {
    case ask
    case highest
    case p360 = "360p"
    case p480 = "480p"
    case p720 = "720p"
    case p1080 = "1080p"
    case p1080u = "1080p Ultra"
    case k2 = "2K"
    case k4 = "4K"

    var id: Self { self }

    var localizedKey: LocalizedStringKey {
        switch self {
        case .ask:
            "key.ask"
        case .highest:
            "key.highest"
        case .p360:
            "key.360p"
        case .p480:
            "key.480p"
        case .p720:
            "key.720p"
        case .p1080:
            "key.1080p"
        case .p1080u:
            "key.1080pu"
        case .k2:
            "key.2k"
        case .k4:
            "key.4k"
        }
    }
}

enum SpatialAudio: Int, CaseIterable, Identifiable, Defaults.Serializable {
    case off = 0
    case monoAndStereo
    case multichannel
    case monoStereoAndMultichannel

    var id: Self { self }

    var localizedKey: LocalizedStringKey {
        switch self {
        case .off:
            "key.off"
        case .monoAndStereo:
            "key.monoAndStereo"
        case .multichannel:
            "key.multichannel"
        case .monoStereoAndMultichannel:
            "key.monoStereoAndMultichannel"
        }
    }

    var format: AVAudioSpatializationFormats {
        switch self {
        case .off:
            .init(rawValue: 0)
        case .monoAndStereo:
            .monoAndStereo
        case .multichannel:
            .multichannel
        case .monoStereoAndMultichannel:
            .monoStereoAndMultichannel
        }
    }
}

enum Theme: Int, CaseIterable, Identifiable, Defaults.Serializable {
    case system = 0
    case light
    case dark

    var id: Self { self }

    var localizedKey: LocalizedStringKey {
        switch self {
        case .system:
            "key.theme.system"
        case .light:
            "key.theme.light"
        case .dark:
            "key.theme.dark"
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
