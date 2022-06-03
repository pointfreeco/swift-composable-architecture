// NB: This file gathers coverage of various `WithViewStore` conformances.

import ComposableArchitecture
import SwiftUI

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
struct TestApp: App {
  @Namespace var namespace

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
        checkAccessibilityRotor()
        checkToolbar()
      }
    }
  }

  #if os(iOS) || os(macOS)
    var commands: some Scene {
      self.body.commands {
        WithViewStore(self.store) { viewStore in
          CommandMenu("Commands") {
            Button("Increment") {
              viewStore.send(())
            }
          }
        }
      }
    }
  #endif

  @ViewBuilder
  func checkToolbar() -> some View {
    Color.clear
      .toolbar {
        WithViewStore(store) { viewStore in
          ToolbarItem {
            Button(action: { viewStore.send(()) }, label: { Text("Increment") })
          }
        }
      }
  }

  @ViewBuilder
  func checkAccessibilityRotor() -> some View {
    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
      Color.clear
        .accessibilityRotor("Rotor") {
          WithViewStore(store) { viewStore in
            AccessibilityRotorEntry("Value: \(viewStore.state)", 0, in: namespace)
          }
        }
    }
  }
}
