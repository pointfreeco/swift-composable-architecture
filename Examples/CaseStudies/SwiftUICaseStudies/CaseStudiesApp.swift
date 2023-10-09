import ComposableArchitecture
import SwiftUI

import SwiftData

@main
struct CaseStudiesApp: App {
  var body: some Scene {
    WindowGroup {
      if !_XCTIsTesting {
        NavigationStack {
          LibraryView(
            store: Store(initialState: LibraryFeature.State()) {
              LibraryFeature()
            } withDependencies: {
              $0.modelContainer = try! ModelContainer(for: Book.self, configurations: .init())
            }
          )
        }
        //      RootView(
        //        store: Store(initialState: Root.State()) {
        //          Root()
        //            .signpost()
        //            ._printChanges()
        //        }
        //      )
      }
    }
  }
}
