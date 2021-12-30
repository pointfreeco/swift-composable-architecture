import ComposableArchitecture
import SwiftUI

@main
struct SearchApp: App {
  var body: some Scene {
    WindowGroup {
      SearchView(
        store: Store(
          initialState: SearchState(),
          reducer: searchReducer.debug(),
          environment: SearchEnvironment(
            weatherClient: WeatherClient.live,
            mainQueue: .main
          )
        )
      )
    }
  }
}
