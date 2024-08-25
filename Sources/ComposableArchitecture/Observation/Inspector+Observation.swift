import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(visionOS, unavailable)
extension View {
  /// Presents an inspector when a piece of optional state held in a store becomes non-`nil`.
  /// - Parameters:
  ///   - item: Binding to an optional Store
  ///   - content: View builder which gets passed the unrwrapped store.
  ///
  /// For example, if an application has destination which holds a reducer state to be shown in an inspector, then we can model the domain like this:
  ///
  /// ```swift
  /// @Reducer
  /// struct Feature {
  ///   struct State {
  ///     @Presents
  ///     var destination: InspectorFeature.State?
  ///   }
  ///
  ///   enum Action {
  ///     case destination(PresentationAction<InspectorFeature.Action>)
  ///   }
  ///
  ///    var body: some ReducerOf<Self> {
  ///      Reduce { state, action in
  ///        ...
  ///      }
  ///      .ifLet(\.$destination, action: \.destination) {
  ///         InspectorFeature()
  ///       }
  ///    }
  /// }
  /// ```
  ///
  /// The view uses a modifier similar to SwiftUI's sheet modifier holding an optional presentation state:
  ///
  /// ```swift
  /// struct AppView: View {
  ///   @Bindable var store: StoreOf<Feature>
  ///
  ///   var body: some View {
  ///     Text("View content")
  ///     .inspector($store.scope(state: \.destination, action: \.destination)) { inspectorStore in
  ///       InspectorFeatureView(store: inspectorStore)
  ///      }
  ///   }
  /// }
  /// ```
  public func inspector<State, Action, Content: View>(
    _ item: Binding<Store<State, Action>?>,
    @ViewBuilder content: @escaping (Store<State, Action>) -> Content) -> some View {
      return self.inspector(isPresented: Binding(item)) {
        if let store = item.wrappedValue {
          content(store)
        }
      }
    }
}
