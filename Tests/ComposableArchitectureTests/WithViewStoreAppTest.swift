// NB: This file gathers coverage of `WithViewStore` use as a `Scene`.

import ComposableArchitecture
import SwiftUI

#if compiler(>=5.3) && os(iOS) || os(macOS)
  @available(iOS 14, macOS 11, *)
  struct TestApp: App {
    let store = Store(
      initialState: 0,
      reducer: Reducer<Int, Void, Void> { state, _, _ in
        state += 1
        return .none
      },
      environment: ()
    )

    var body: some Scene {
      WithViewStore(self.store) { viewStore in
        WindowGroup {
          EmptyView()
        }
        .commands {
          CommandMenu("Commands") {
            Button("Increment") {
              viewStore.send(())
            }
            .keyboardShortcut("+")
          }
        }
      }
    }
  }
#endif
