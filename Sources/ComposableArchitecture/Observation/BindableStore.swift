import SwiftUI

/// A property wrapper type that supports creating bindings to the mutable properties of a
/// ``Store``.
///
/// Use this property wrapper in iOS 16, macOS 13, tvOS 16, watchOS 9, and earlier, for deriving
/// bindings to properties of your features. For example, if your feature has state for the
/// selected tab of a `TabView`, as well as an action to change the tab, then you can derive
/// a binding like so:
///
/// ```swift
/// struct AppView: View {
///   @BindableStore var store: StoreOf<AppFeature>
///
///   var body: some View {
///     TabView(selection: $store.selectedTab.sending(\.setTab)) {
///       // ...
///     }
///   }
/// }
/// ```
///
/// Or, if your feature is integrated with ``BindableAction`` and ``BindingReducer`` (see
/// <doc:Bindings> for more information), then you can derive a binding more directly:
///
/// ```swift
/// struct AppView: View {
///   @BindableStore var store: StoreOf<AppFeature>
///
///   var body: some View {
///     TabView(selection: $store.selectedTab) {
///       // ...
///     }
///   }
/// }
/// ```
///
/// If you are targeting iOS 17, macOS 14, tvOS 17, watchOS 9, or later, then you can replace
/// ``BindableStore`` with SwiftUI's `@Bindable`.
@available(iOS, deprecated: 17, renamed: "Bindable")
@available(macOS, deprecated: 14, renamed: "Bindable")
@available(tvOS, deprecated: 17, renamed: "Bindable")
@available(watchOS, deprecated: 10, renamed: "Bindable")
@propertyWrapper
@dynamicMemberLookup
public struct BindableStore<State: ObservableState, Action> {
  public var wrappedValue: Store<State, Action>
  public init(wrappedValue: Store<State, Action>) {
    self.wrappedValue = wrappedValue
  }
  public var projectedValue: BindableStore<State, Action> {
    self 
  }
  public subscript<Subject>(
    dynamicMember keyPath: ReferenceWritableKeyPath<Store<State, Action>, Subject>
  ) -> Binding<Subject> {
    Binding(
      get: { self.wrappedValue[keyPath: keyPath] },
      set: { self.wrappedValue[keyPath: keyPath] = $0 }
    )
  }
}
