// NB: This file gathers coverage of various `WithViewStore` conformances.

import ComposableArchitecture
import SwiftUI

@available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
struct TestApp: App {
  @Namespace var namespace

  let store = Store(
    initialState: 0,
    reducer: Reduce<Int, Void> { state, _ in
      state += 1
      return .none
    }
  )

  @available(*, deprecated)
  var body: some Scene {
    WithViewStore(self.store) { viewStore in
      WindowGroup {
        checkAccessibilityRotor()
        checkToolbar()
      }
    }
  }

  #if os(iOS) || os(macOS)
    @available(*, deprecated)
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

  @available(*, deprecated)
  @ViewBuilder
  func checkToolbar() -> some View {
    Color.clear
      .toolbar {
        WithViewStore(self.store) { viewStore in
          ToolbarItem {
            Button(action: { viewStore.send(()) }, label: { Text("Increment") })
          }
        }
      }
  }

  @available(*, deprecated)
  @ViewBuilder
  func checkAccessibilityRotor() -> some View {
    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
      Color.clear
        .accessibilityRotor("Rotor") {
          WithViewStore(self.store) { viewStore in
            AccessibilityRotorEntry("Value: \(viewStore.state)", 0, in: namespace)
          }
        }
    }
  }
}
