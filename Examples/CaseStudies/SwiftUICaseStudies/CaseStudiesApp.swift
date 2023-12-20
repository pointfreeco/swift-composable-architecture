@_spi(Logging) import ComposableArchitecture
import SwiftUI

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    let _ = Logger.shared.isEnabled = true
    WindowGroup {
      RootView()
    }
  }
}
