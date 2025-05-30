import Combine
import CoreData
import Defaults
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Sparkle
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notifcation: Notification) {
        UNUserNotificationCenter.current().delegate = self

        NSWindow.allowsAutomaticWindowTabbing = false

        UserDefaults.standard.register(
            defaults: ["NSApplicationCrashOnExceptions": true]
        )

        FirebaseApp.configure()

        #if DEBUG
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            FirebaseConfiguration.shared.setLoggerLevel(.min)
            Analytics.setAnalyticsCollectionEnabled(false)
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppState.shared.path.removeAll()

        return Downloader.shared.downloads.isEmpty
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !Downloader.shared.downloads.isEmpty {
            let notificationCenter = UNUserNotificationCenter.current()

            notificationCenter.getPendingNotificationRequests { requests in
                notificationCenter.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.content.categoryIdentifier == "cancel" }.map(\.identifier))
            }

            notificationCenter.getDeliveredNotifications { notifications in
                notificationCenter.removeDeliveredNotifications(withIdentifiers: notifications.filter { $0.request.content.categoryIdentifier == "cancel" }.map(\.request.identifier))
            }
        }
    }

    func application(_ application: NSApplication, willEncodeRestorableState coder: NSCoder) {}

    func application(_ application: NSApplication, didDecodeRestorableState coder: NSCoder) {}

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "cancel":
            if let id = userInfo["id"] as? String, let download = Downloader.shared.downloads.first(where: { $0.id == id }) {
                download.cancel()
            }
        case "open":
            if let url = userInfo["url"] as? String, let fileUrl = URL(string: url), fileUrl.isFileURL {
                NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
            }
        case "retry":
            if let retryData = userInfo["data"] as? Data, let data = try? JSONDecoder().decode(DownloadData.self, from: retryData) {
                Downloader.shared.download(data)
            }
        case "need_premium":
            NSWorkspace.shared.open((Defaults[.mirror] != Defaults.Keys.mirror.defaultValue ? Defaults[.mirror] : Const.redirectMirror).appending(path: "payments", directoryHint: .notDirectory))
        default:
            break
        }

        completionHandler()
    }
}

@main
struct HDrezkaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState: AppState = .shared
    @StateObject private var downloader: Downloader = .shared
    @StateObject private var persistenceController: PersistenceController = .shared
    @Environment(\.openWindow) private var openWindow

    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(downloader)
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .background(WindowAccessor { window in
                    appState.window = window
                })
                .onOpenURL { url in
                    guard let scheme = Const.details.scheme,
                          url.scheme == scheme
                    else {
                        return
                    }

                    if let host = Const.details.host(), url.host() == host, let movieId = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "id" })?.value, movieId.id != nil {
                        appState.path.append(.details(.init(movieId: movieId)))
                    } else if url.absoluteString.removeMirror(scheme).id != nil {
                        appState.path.append(.details(.init(movieId: url.absoluteString.removeMirror(scheme))))
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .commands(content: customCommands)
        .commands(content: removed)

        WindowGroup("key.player", id: "player", for: PlayerData.self) { $data in
            if let data {
                PlayerView(data: data)
                    .environmentObject(appState)
                    .environment(\.managedObjectContext, persistenceController.viewContext)
            }
        }
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .applyRestorationBehavior()
        .commands(content: customCommands)
        .commands(content: removed)

        WindowGroup("key.imageViewer", id: "imageViewer", for: URL.self) { $url in
            if let url {
                ImageView(url: url)
            }
        }
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .applyRestorationBehavior()
        .commands(content: customCommands)
        .commands(content: removed)

        WindowGroup("key.licenses", id: "licenses") {
            LicensesView()
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
        .applyRestorationBehavior()
        .commands(content: customCommands)
        .commands(content: removed)

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands(content: customCommands)
        .commands(content: removed)

        MenuBarExtra(isInserted: Binding {
            !downloader.downloads.isEmpty
        } set: { _ in }) {
            DownloadsView()
                .environmentObject(downloader)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
        .commands(content: customCommands)
        .commands(content: removed)
    }

    @CommandsBuilder
    func customCommands() -> some Commands {
        CommandGroup(replacing: .appSettings) {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("key.settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            } else {
                Button {
                    if #available(macOS 13.0, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                } label: {
                    Text("key.settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            UpdateButton(updater: updaterController.updater)

            Button {
                openWindow(id: "licenses")
            } label: {
                Text("key.licenses")
            }
        }

        CommandGroup(replacing: .appInfo) {
            Button {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = NSTextAlignment.center

                if let image = NSImage(named: "GS") {
                    let imageAttachment = NSTextAttachment()
                    imageAttachment.image = image.resized(to: CGSize(width: 76, height: 100)).tint(.accent)

                    let credits = NSMutableAttributedString(attachment: imageAttachment)
                    credits.addAttribute(.link, value: Const.helpUkraine, range: NSRange(location: 0, length: credits.length))
                    credits.append(NSAttributedString(string: "\n\n© 2025 "))
                    credits.append(NSAttributedString(string: "HDrezka macOS", attributes: [.link: Const.github]))
                    credits.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: credits.length))

                    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
                } else {
                    let credits = NSMutableAttributedString(string: "© 2025 ")
                    credits.append(NSAttributedString(string: "HDrezka macOS", attributes: [.link: Const.github]))
                    credits.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: credits.length))

                    NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey.credits: credits])
                }
            } label: {
                Text("key.about-\(Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "HDrezka")")
            }
        }

        CommandGroup(replacing: .appTermination) {
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("key.close-\(Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "HDrezka")")
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Link(destination: Const.github) {
                Text("key.github")
            }
        }
    }

    @CommandsBuilder
    func removed() -> some Commands {
        CommandGroup(replacing: .importExport) {}
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .printItem) {}
        CommandGroup(replacing: .saveItem) {}
        CommandGroup(replacing: .sidebar) {}
        CommandGroup(replacing: .singleWindowList) {}
        CommandGroup(replacing: .systemServices) {}
        CommandGroup(replacing: .toolbar) {}
        CommandGroup(replacing: .windowList) {}
    }
}

struct MenuBarIcon: View {
    var body: some View {
        if let image = NSImage(named: "BarIcon") {
            Image(nsImage: image.resized(to: CGSize(width: 18, height: 18)))
        } else {
            Image(systemName: "list.and.film")
        }
    }
}

extension NSImage {
    func resized(to size: CGSize) -> NSImage {
        let image = self
        image.size = size
        return image
    }
}

extension Scene {
    func applyRestorationBehavior() -> some Scene {
        if #available(macOS 15.0, *) {
            return self.restorationBehavior(.disabled)
        } else {
            return self
        }
    }
}

extension NSImage {
    func tint(_ tint: NSColor) -> NSImage {
        guard isTemplate,
              let tinted = copy() as? NSImage
        else {
            return self
        }

        tinted.lockFocus()
        tint.set()
        CGRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
        tinted.unlockFocus()

        return tinted
    }
}

struct WindowAccessor: NSViewRepresentable {
    private let callback: (NSWindow) -> Void

    init(callback: @escaping (NSWindow) -> Void) {
        self.callback = callback
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
