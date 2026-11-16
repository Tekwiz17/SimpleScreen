import SwiftUI
import AppKit

@main struct SimpleScreenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    private var desktop: DesktopController!
    private var settingsWindow: NSWindow?
    private var status: NSStatusItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
        desktop = DesktopController(store: store)
        store.onChange = { [weak self] in self?.apply() }
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: .openSimpleScreenSettings, object: nil)
        apply()
        if !store.preferences.onboardingComplete { openSettings() }
    }
    func apply() {
        store.services.configure(store.preferences)
        desktop.sync()
        let presence = store.preferences.presence
        NSApp.setActivationPolicy(presence == .dock || presence == .both ? .regular : .accessory)
        if presence == .menu || presence == .both {
            if status == nil {
                status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                status?.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "SimpleScreen")
            }
            let menu = NSMenu()
            add("Open SimpleScreen…", action: #selector(openSettings), to: menu)
            menu.addItem(.separator())
            add(store.preferences.enabled ? "Pause desktop" : "Resume desktop", action: #selector(toggleDesktop), to: menu)
            add(store.editing ? "Finish arranging widgets" : "Arrange widgets", action: #selector(toggleEditing), to: menu)
            menu.addItem(.separator())
            add("Quit SimpleScreen", action: #selector(quit), to: menu)
            status?.menu = menu
        } else if let item = status { NSStatusBar.system.removeStatusItem(item); status = nil }
        installMainMenu()
    }
    private func add(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    private func installMainMenu() {
        guard NSApp.mainMenu == nil || (NSApp.mainMenu?.items.count ?? 0) < 2 else { return }
        let main = NSMenu()
        let app = NSMenuItem()
        let appMenu = NSMenu()
        add("SimpleScreen Settings…", action: #selector(openSettings), to: appMenu)
        add("Quit SimpleScreen", action: #selector(quit), to: appMenu)
        app.submenu = appMenu; main.addItem(app)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        edit.submenu = editMenu; main.addItem(edit)
        NSApp.mainMenu = main
    }
    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "SimpleScreen"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 900, height: 620)
            window.contentView = NSHostingView(rootView: StudioView(store: store, services: store.services))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func toggleDesktop() { store.preferences.enabled.toggle() }
    @objc func toggleEditing() { store.editing.toggle(); desktop.sync() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { store.save() }
}
