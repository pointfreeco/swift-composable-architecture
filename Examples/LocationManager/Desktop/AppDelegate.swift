import Cocoa
import ComposableArchitecture
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    let contentView = LocationManagerView(
      store: Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
          localSearch: .live,
          locationManager: .live
        )
      )
    )

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
      styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
      backing: .buffered, defer: false
    )
    window.center()
    window.setFrameAutosaveName("Main Window")
    window.contentView = NSHostingView(rootView: contentView)
    window.makeKeyAndOrderFront(nil)
  }

  func applicationWillTerminate(_ aNotification: Notification) {
  }
}
