import Foundation
import Testing
// not @testable: checks what an app sees, with and without the `FloconEnabled` trait
import Flocon

#if FloconEnabled
@Suite struct FloconEnabledTraitTests {
    @Test func reportsTheSDKAsCompiledIn() {
        #expect(Flocon.isEnabled)
    }
}
#else
@Suite struct FloconDisabledTraitTests {
    @Test func reportsTheSDKAsLeftOut() {
        #expect(!Flocon.isEnabled)
    }

    @Test func startDoesNothing() async {
        startFlocon { flocon in
            flocon.install(.network)
            flocon.install(.crashReporter)
        }

        #expect(!Flocon.shared.isInitialized)
        #expect(Flocon.shared.networkPlugin == nil)
        #expect(await Flocon.connect(address: "192.168.1.20") == .notStarted)
    }

    @Test func pluginsAcceptCalls() {
        Flocon.analyticsPlugin.sender("app").logEvents(AnalyticsEvent(eventName: "app_opened"))
        Flocon.timelinePlugin.logNavigation("Home", params: [:])
    }

    @Test func sessionsAreNotIntercepted() {
        Flocon.interceptSharedSession()
        let configuration = URLSessionConfiguration.ephemeral
        let classes = configuration.protocolClasses?.count

        #expect(configuration.withFlocon().protocolClasses?.count == classes)
    }
}
#endif
