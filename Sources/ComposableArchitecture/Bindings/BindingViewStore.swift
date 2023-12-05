@_spi(Internals) import ComposableArchitectureCore
import SwiftUI

/// A property wrapper type that can derive ``BindingViewState`` values for a ``ViewStore``.
///
/// Read <doc:Bindings> for more information.
@dynamicMemberLookup
@propertyWrapper
public struct BindingViewStore<State> {
  let store: Store<State, BindingAction<State>>
  #if DEBUG
    let bindableActionType: Any.Type
    let fileID: StaticString
    let line: UInt
  #endif

  init<Action: BindableAction>(
    store: Store<State, Action>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Action.State == State {
    self.store = store.scope(state: { $0 }, action: Action.binding)
    #if DEBUG
      self.bindableActionType = type(of: Action.self)
      self.fileID = fileID
      self.line = line
    #endif
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public var wrappedValue: State {
    self.store.withState { $0 }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.wrappedValue[keyPath: keyPath]
  }

  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, BindingState<Value>>
  ) -> BindingViewState<Value> {
    BindingViewState(
      binding: ViewStore(self.store, observe: { $0[keyPath: keyPath].wrappedValue })
        .binding(
          send: { value in
            #if DEBUG
              let debugger = BindableActionViewStoreDebugger(
                value: value,
                bindableActionType: self.bindableActionType,
                context: .bindingStore,
                isInvalidated: self.store._isInvalidated,
                fileID: self.fileID,
                line: self.line
              )
              let set: @Sendable (inout State) -> Void = {
                $0[keyPath: keyPath].wrappedValue = value
                debugger.wasCalled = true
              }
            #else
              let set: @Sendable (inout State) -> Void = {
                $0[keyPath: keyPath].wrappedValue = value
              }
            #endif
            return .init(keyPath: keyPath, set: set, value: value)
          }
        )
    )
  }
}

extension ViewStore where ViewAction: BindableAction, ViewAction.State == ViewState {
  @MainActor
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<ViewState, BindingState<Value>>
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let bindingState = self.state[keyPath: keyPath]
          let debugger = BindableActionViewStoreDebugger(
            value: value,
            bindableActionType: ViewAction.self,
            context: .bindingState,
            isInvalidated: self._isInvalidated,
            fileID: bindingState.fileID,
            line: bindingState.line
          )
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
          }
        #endif
        return .binding(.init(keyPath: keyPath, set: set, value: value))
      }
    )
  }
}

extension TestStore {
  /// Returns a binding view store for this store.
  ///
  /// Useful for testing view state of a store.
  ///
  /// ```swift
  /// let store = TestStore(LoginFeature.State()) {
  ///   Login.Feature()
  /// }
  /// await store.send(.view(.set(\.$email, "blob@pointfree.co"))) {
  ///   $0.email = "blob@pointfree.co"
  /// }
  /// XCTAssertTrue(
  ///   LoginView.ViewState(store.bindings(action: \.view))
  ///     .isLoginButtonDisabled
  /// )
  ///
  /// await store.send(.view(.set(\.$password, "whats-the-point?"))) {
  ///   $0.password = "blob@pointfree.co"
  ///   $0.isFormValid = true
  /// }
  /// XCTAssertFalse(
  ///   LoginView.ViewState(store.bindings(action: \.view))
  ///     .isLoginButtonDisabled
  /// )
  /// ```
  ///
  /// - Parameter toViewAction: A case path from action to a bindable view action.
  /// - Returns: A binding view store.
  public func bindings<ViewAction: BindableAction>(
    action toViewAction: CaseKeyPath<Action, ViewAction>
  ) -> BindingViewStore<State> where State == ViewAction.State, Action: CasePathable {
    BindingViewStore(
      store: Store(initialState: self.state) {
        BindingReducer(action: toViewAction)
      }
      .scope(state: \.self, action: toViewAction)
    )
  }

  @available(
    iOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    macOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    tvOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @available(
    watchOS,
    deprecated: 9999,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information:\n\nhttps://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public func bindings<ViewAction: BindableAction>(
    action toViewAction: AnyCasePath<Action, ViewAction>
  ) -> BindingViewStore<State> where State == ViewAction.State {
    BindingViewStore(
      store: Store(initialState: self.state) {
        BindingReducer(action: toViewAction.extract(from:))
      }
      .scope(state: { $0 }, action: toViewAction.embed)
    )
  }
}

extension TestStore where Action: BindableAction, State == Action.State {
  /// Returns a binding view store for this store.
  ///
  /// Useful for testing view state of a store.
  ///
  /// ```swift
  /// let store = TestStore(LoginFeature.State()) {
  ///   Login.Feature()
  /// }
  /// await store.send(.set(\.$email, "blob@pointfree.co")) {
  ///   $0.email = "blob@pointfree.co"
  /// }
  /// XCTAssertTrue(LoginView.ViewState(store.bindings).isLoginButtonDisabled)
  ///
  /// await store.send(.set(\.$password, "whats-the-point?")) {
  ///   $0.password = "blob@pointfree.co"
  ///   $0.isFormValid = true
  /// }
  /// XCTAssertFalse(LoginView.ViewState(store.bindings).isLoginButtonDisabled)
  /// ```
  ///
  /// - Returns: A binding view store.
  public var bindings: BindingViewStore<State> {
    self.bindings(action: AnyCasePath())
  }
}

#if DEBUG
  private final class BindableActionViewStoreDebugger<Value> {
    enum Context {
      case bindingState
      case bindingStore
      case viewStore
    }

    let value: Value
    let bindableActionType: Any.Type
    let context: Context
    let isInvalidated: () -> Bool
    let fileID: StaticString
    let line: UInt
    var wasCalled = false

    init(
      value: Value,
      bindableActionType: Any.Type,
      context: Context,
      isInvalidated: @escaping () -> Bool,
      fileID: StaticString,
      line: UInt
    ) {
      self.value = value
      self.bindableActionType = bindableActionType
      self.context = context
      self.isInvalidated = isInvalidated
      self.fileID = fileID
      self.line = line
    }

    deinit {
      guard !self.isInvalidated() else { return }
      guard self.wasCalled else {
        var value = ""
        customDump(self.value, to: &value, maxDepth: 0)
        _runtimeWarn(
          """
          A binding action sent from a view store \
          \(self.context == .bindingState ? "for binding state defined " : "")at \
          "\(self.fileID):\(self.line)" was not handled. …

            Action:
              \(_typeName(self.bindableActionType)).binding(.set(_, \(value)))

          To fix this, invoke "BindingReducer()" from your feature reducer's "body".
          """
        )
        return
      }
    }
  }
#endif
