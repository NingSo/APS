import SwiftUI

@main
@MainActor
struct SignalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: AppStore
    init() {
        #if DEBUG && targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--ui-fixture"), index + 1 < args.count {
            let defaults = UserDefaults(suiteName: "aps-ui-tests")!
            defaults.removePersistentDomain(forName: "aps-ui-tests")
            let model = AppStore(defaults: defaults, monitorNetwork: false)
            model.useFixture(args[index + 1]); _store = StateObject(wrappedValue: model)
        } else { _store = StateObject(wrappedValue: AppStore()) }
        #else
        _store = StateObject(wrappedValue: AppStore())
        #endif
    }
    var body: some Scene {
        WindowGroup {
            SignalRoot(store: store)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { phase in store.setForeground(phase == .active, background: phase == .background) }
        }
    }
}
