@_spi(Reflection) import CasePaths

#if canImport(Combine)
  @preconcurrency import Combine
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif
#if canImport(UIKit)
  import UIKit
#endif

// NB: Deprecated with 1.25.0:

extension Scope {
  @available(
    *,
    deprecated,
    message: """
      Use a '@Reducer enum' or 'ifCaseLet(_:action:)' on a base reducer, instead.
      """
  )
  @inlinable
  public init<ChildState, ChildAction>(
    state toChildState: CaseKeyPath<ParentState, ChildState>,
    action toChildAction: CaseKeyPath<ParentAction, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) where ChildState == Child.State, ChildAction == Child.Action {
    self.init(
      toChildState: .casePath(
        AnyCasePath(toChildState),
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      ),
      toChildAction: AnyCasePath(toChildAction),
      child: child()
    )
  }
}

// NB: Deprecated with 1.24.0:

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
@dynamicMemberLookup
@preconcurrency @MainActor
public final class ViewStore<ViewState, ViewAction>: ObservableObject {
  public nonisolated let objectWillChange = ObservableObjectPublisher()
  private let _state: CurrentValueRelay<ViewState>

  private var viewCancellable: AnyCancellable?
  #if DEBUG
    private let storeTypeName: String
  #endif
  let store: Store<ViewState, ViewAction>

  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate
    )
  }

  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) {
    #if DEBUG
      self.storeTypeName = ComposableArchitecture.storeTypeName(of: store)
      Logger.shared.log("View\(self.storeTypeName).init")
    #endif
    self.store = store._scope(state: toViewState, action: fromViewAction)
    self._state = CurrentValueRelay(self.store.withState { $0 })
    self.viewCancellable = self.store.core.didSet
      .compactMap { [weak self] in self?.store.withState { $0 } }
      .removeDuplicates(by: isDuplicate)
      .dropFirst()
      .sink { [weak self] in
        self?.objectWillChange.send()
        self?._state.value = $0
      }
  }

  init(_ viewStore: ViewStore<ViewState, ViewAction>) {
    #if DEBUG
      self.storeTypeName = viewStore.storeTypeName
      Logger.shared.log("View\(self.storeTypeName).init")
    #endif
    self.store = viewStore.store
    self._state = viewStore._state
    self.viewCancellable = viewStore.objectWillChange.sink { [weak self] in
      self?.objectWillChange.send()
      self?._state.value = viewStore.state
    }
  }

  #if DEBUG
    deinit {
      guard Thread.isMainThread else { return }
      MainActor.assumeIsolated {
        Logger.shared.log("View\(self.storeTypeName).deinit")
      }
    }
  #endif

  public var publisher: StorePublisher<ViewState> {
    StorePublisher(store: self, upstream: self._state)
  }

  public var state: ViewState {
    self._state.value
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<ViewState, Value>) -> Value {
    self.state[keyPath: keyPath]
  }

  @discardableResult
  public func send(_ action: ViewAction) -> StoreTask {
    self.store.send(action)
  }

  @discardableResult
  public func send(_ action: ViewAction, animation: Animation?) -> StoreTask {
    self.send(action, transaction: Transaction(animation: animation))
  }

  @discardableResult
  public func send(_ action: ViewAction, transaction: Transaction) -> StoreTask {
    withTransaction(transaction) {
      self.send(action)
    }
  }

  public func send(
    _ action: ViewAction,
    while predicate: @escaping (_ state: ViewState) -> Bool
  ) async {
    let task = self.send(action)
    await withTaskCancellationHandler {
      await self.yield(while: predicate)
    } onCancel: {
      task.cancel()
    }
  }

  public func send(
    _ action: ViewAction,
    animation: Animation?,
    while predicate: @escaping (_ state: ViewState) -> Bool
  ) async {
    let task = withAnimation(animation) { self.send(action) }
    await withTaskCancellationHandler {
      await self.yield(while: predicate)
    } onCancel: {
      task.cancel()
    }
  }

  public func yield(while predicate: @escaping (_ state: ViewState) -> Bool) async {
    let isolatedCancellable = LockIsolated<AnyCancellable?>(nil)
    try? await withTaskCancellationHandler {
      try Task.checkCancellation()
      try await withUnsafeThrowingContinuation {
        (continuation: UnsafeContinuation<Void, any Error>) in
        guard !Task.isCancelled else {
          continuation.resume(throwing: CancellationError())
          return
        }
        let cancellable = self.publisher
          .filter { !predicate($0) }
          .prefix(1)
          .sink { _ in
            continuation.resume()
            _ = isolatedCancellable
          }
        isolatedCancellable.setValue(cancellable)
      }
    } onCancel: {
      isolatedCancellable.value?.cancel()
    }
  }

  public func binding<Value>(
    get: @escaping (_ state: ViewState) -> Value,
    send valueToAction: @escaping (_ value: Value) -> ViewAction
  ) -> Binding<Value> {
    ObservedObject(wrappedValue: self)
      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
  }

  @_disfavoredOverload
  func binding<Value>(
    get: @escaping (_ state: ViewState) -> Value,
    compactSend valueToAction: @escaping (_ value: Value) -> ViewAction?
  ) -> Binding<Value> {
    ObservedObject(wrappedValue: self)
      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: valueToAction)]
  }

  public func binding<Value>(
    get: @escaping (_ state: ViewState) -> Value,
    send action: ViewAction
  ) -> Binding<Value> {
    self.binding(get: get, send: { _ in action })
  }

  public func binding(
    send valueToAction: @escaping (_ state: ViewState) -> ViewAction
  ) -> Binding<ViewState> {
    self.binding(get: { $0 }, send: valueToAction)
  }

  public func binding(send action: ViewAction) -> Binding<ViewState> {
    self.binding(send: { _ in action })
  }

  private subscript<Value>(
    get fromState: HashableWrapper<(ViewState) -> Value>,
    send toAction: HashableWrapper<(Value) -> ViewAction?>
  ) -> Value {
    get { fromState.rawValue(self.state) }
    set {
      BindingLocal.$isActive.withValue(true) {
        if let action = toAction.rawValue(newValue) {
          self.send(action)
        }
      }
    }
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
public typealias ViewStoreOf<R: Reducer> = ViewStore<R.State, R.Action>

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension ViewStore where ViewState: Equatable {
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState
  ) {
    self.init(store, observe: toViewState, removeDuplicates: { $0 == $1 })
  }

  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action
  ) {
    self.init(store, observe: toViewState, send: fromViewAction, removeDuplicates: { $0 == $1 })
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension ViewStore {
  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: { (_: State) in
        toViewState(
          BindingViewStore(
            store: store._scope(state: { $0 }, action: fromViewAction)
          )
        )
      },
      send: fromViewAction,
      removeDuplicates: isDuplicate
    )
  }

  @_disfavoredOverload
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension ViewStore where ViewState: Equatable {
  @_disfavoredOverload
  public convenience init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: toViewState,
      send: fromViewAction,
      removeDuplicates: { $0 == $1 }
    )
  }

  @_disfavoredOverload
  public convenience init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: toViewState,
      removeDuplicates: { $0 == $1 }
    )
  }
}

private struct HashableWrapper<Value>: Hashable {
  let rawValue: Value
  static func == (lhs: Self, rhs: Self) -> Bool { false }
  func hash(into hasher: inout Hasher) {}
}

enum BindingLocal {
  @TaskLocal static var isActive = false
}

@available(
  *,
  deprecated,
  message:
    "Pass 'ForEach' a store scoped to an identified array and identified action, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-ForEachStore-with-ForEach]"
)
public struct ForEachStore<
  EachState,
  EachAction,
  Data: Collection,
  ID: Hashable & Sendable,
  Content: View
>: View {
  public let data: Data
  let content: Content

  @preconcurrency @MainActor
  public init<EachContent>(
    _ store: Store<IdentifiedArray<ID, EachState>, IdentifiedAction<ID, EachAction>>,
    @ViewBuilder content: @escaping (_ store: Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      IdentifiedArray<ID, EachState>, IdentifiedAction<ID, EachAction>,
      ForEach<IdentifiedArray<ID, EachState>, ID, EachContent>
    >
  {
    self.data = store.withState { $0 }

    func open(
      _ core: some Core<IdentifiedArray<ID, EachState>, IdentifiedAction<ID, EachAction>>,
      element: EachState,
      id: ID
    ) -> any Core<EachState, EachAction> {
      IfLetCore(
        base: core,
        cachedState: element,
        stateKeyPath: \.[id: id],
        actionKeyPath: \.[id: id]
      )
    }

    self.content = WithViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
    ) { viewStore in
      ForEach(viewStore.state, id: viewStore.state.id) { element in
        let id = element[keyPath: viewStore.state.id]
        content(
          store.scope(
            id: store.id(state: \.[id: id]!, action: \.[id: id]),
            childCore: open(store.core, element: element, id: id)
          )
        )
      }
    }
  }

  @available(
    *,
    deprecated,
    message:
      "Use an 'IdentifiedAction', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Identified-actions"
  )
  @preconcurrency @MainActor
  public init<EachContent>(
    _ store: Store<IdentifiedArray<ID, EachState>, (id: ID, action: EachAction)>,
    @ViewBuilder content: @escaping (_ store: Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      IdentifiedArray<ID, EachState>, (id: ID, action: EachAction),
      ForEach<IdentifiedArray<ID, EachState>, ID, EachContent>
    >
  {
    self.data = store.withState { $0 }

    func open(
      _ core: some Core<IdentifiedArray<ID, EachState>, (id: ID, action: EachAction)>,
      element: EachState,
      id: ID
    ) -> any Core<EachState, EachAction> {
      IfLetCore(
        base: core,
        cachedState: element,
        stateKeyPath: \.[id: id],
        actionKeyPath: \.[id: id]
      )
    }

    self.content = WithViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
    ) { viewStore in
      ForEach(viewStore.state, id: viewStore.state.id) { element in
        let id = element[keyPath: viewStore.state.id]
        content(
          store.scope(
            id: store.id(state: \.[id: id]!, action: \.[id: id]),
            childCore: open(store.core, element: element, id: id)
          )
        )
      }
    }
  }

  public var body: some View {
    self.content
  }
}

@available(*, deprecated)
extension ForEachStore: @preconcurrency DynamicViewContent {}

extension Case {
  fileprivate subscript<ID: Hashable & Sendable, Action>(id id: ID) -> Case<Action>
  where Value == (id: ID, action: Action) {
    Case<Action>(
      embed: { (id: id, action: $0) },
      extract: { $0.id == id ? $0.action : nil }
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Use 'if let' with a store of observable state, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-IfLetStore-with-if-let]"
)
public struct IfLetStore<State, Action, Content: View>: View {
  private let content: (ViewStore<State?, Action>) -> Content
  private let store: Store<State?, Action>

  @preconcurrency @MainActor
  public init<IfContent, ElseContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent,
    @ViewBuilder else elseContent: () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    func open(_ core: some Core<State?, Action>) -> any Core<State?, Action> {
      _IfLetCore(base: core)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    self.store = store
    let elseContent = elseContent()
    self.content = { viewStore in
      if let state = viewStore.state {
        @MainActor
        func open(_ core: some Core<State?, Action>) -> any Core<State, Action> {
          IfLetCore(base: core, cachedState: state, stateKeyPath: \.self, actionKeyPath: \.self)
        }
        return ViewBuilder.buildEither(
          first: ifContent(
            store.scope(
              id: store.id(state: \.!, action: \.self),
              childCore: open(store.core)
            )
          )
        )
      } else {
        return ViewBuilder.buildEither(second: elseContent)
      }
    }
  }

  @preconcurrency @MainActor
  public init<IfContent>(
    _ store: Store<State?, Action>,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent
  ) where Content == IfContent? {
    func open(_ core: some Core<State?, Action>) -> any Core<State?, Action> {
      _IfLetCore(base: core)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    self.store = store
    self.content = { viewStore in
      if let state = viewStore.state {
        @MainActor
        func open(_ core: some Core<State?, Action>) -> any Core<State, Action> {
          IfLetCore(base: core, cachedState: state, stateKeyPath: \.self, actionKeyPath: \.self)
        }
        return ifContent(
          store.scope(
            id: store.id(state: \.!, action: \.self),
            childCore: open(store.core)
          )
        )
      } else {
        return nil
      }
    }
  }

  public var body: some View {
    WithViewStore(
      self.store,
      observe: { $0 },
      removeDuplicates: { ($0 != nil) == ($1 != nil) },
      content: self.content
    )
  }
}

private final class _IfLetCore<Base: Core<Wrapped?, Action>, Wrapped, Action>: Core {
  let base: Base
  init(base: Base) {
    self.base = base
  }
  var state: Base.State { base.state }
  func send(_ action: Action, origin: Origin) -> Task<Void, Never>? {
    base.send(action, origin: origin)
  }
  var canStoreCacheChildren: Bool { base.canStoreCacheChildren }
  var didSet: CurrentValueRelay<Void> { base.didSet }
  var isInvalid: Bool { state == nil || base.isInvalid }
  var effectCancellables: [UUID: AnyCancellable] { base.effectCancellables }
}

@available(
  *,
  deprecated,
  message:
    "Use 'NavigationStack.init(path:)' with a store scoped from observable state, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-NavigationStackStore-with-NavigationStack]"
)

public struct NavigationStackStore<State, Action, Root: View, Destination: View>: View {
  private let root: Root
  private let destination: (StackState<State>.Component) -> Destination
  @ObservedObject private var viewStore: ViewStore<StackState<State>, StackAction<State, Action>>

  public init(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder root: () -> Root,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    func navigationDestination(
      component: StackState<State>.Component
    ) -> Destination {
      let id = store.id(
        state:
          \.[
            id: component.id,
            fileID: _HashableStaticString(rawValue: fileID),
            filePath: _HashableStaticString(rawValue: filePath),
            line: line,
            column: column
          ],
        action: \.[id: component.id]
      )
      @MainActor
      func open(
        _ core: some Core<StackState<State>, StackAction<State, Action>>
      ) -> any Core<State, Action> {
        IfLetCore(
          base: core,
          cachedState: component.element,
          stateKeyPath:
            \.[
              id: component.id,
              fileID: _HashableStaticString(rawValue: fileID),
              filePath: _HashableStaticString(rawValue: filePath),
              line: line,
              column: column
            ],
          actionKeyPath: \.[id: component.id]
        )
      }
      return destination(store.scope(id: id, childCore: open(store.core)))
    }
    self.root = root()
    self.destination = navigationDestination(component:)
    self._viewStore = ObservedObject(
      wrappedValue: ViewStore(
        store,
        observe: { $0 },
        removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
      )
    )
  }

  @_disfavoredOverload
  public init<D: View>(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder root: () -> Root,
    @ViewBuilder destination: @escaping (_ initialState: State) -> D,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) where Destination == SwitchStore<State, Action, D> {
    func navigationDestination(
      component: StackState<State>.Component
    ) -> Destination {
      let id = store.id(
        state:
          \.[
            id: component.id,
            fileID: _HashableStaticString(rawValue: fileID),
            filePath: _HashableStaticString(rawValue: filePath),
            line: line,
            column: column
          ],
        action: \.[id: component.id]
      )
      if let child = store.children[id] as? Store<State, Action> {
        return SwitchStore(child, content: destination)
      } else {
        @MainActor
        func open(
          _ core: some Core<StackState<State>, StackAction<State, Action>>
        ) -> any Core<State, Action> {
          IfLetCore(
            base: core,
            cachedState: component.element,
            stateKeyPath:
              \.[
                id: component.id,
                fileID: _HashableStaticString(rawValue: fileID),
                filePath: _HashableStaticString(rawValue: filePath),
                line: line,
                column: column
              ],
            actionKeyPath: \.[id: component.id]
          )
        }
        return SwitchStore(store.scope(id: id, childCore: open(store.core)), content: destination)
      }
    }

    self.root = root()
    self.destination = navigationDestination(component:)
    self._viewStore = ObservedObject(
      wrappedValue: ViewStore(
        store,
        observe: { $0 },
        removeDuplicates: { areOrderedSetsDuplicates($0.ids, $1.ids) }
      )
    )
  }

  public var body: some View {
    NavigationStack(
      path: self.viewStore.binding(
        get: { $0.path },
        compactSend: { newPath in
          if newPath.count > self.viewStore.path.count, let component = newPath.last {
            return .push(id: component.id, state: component.element)
          } else if newPath.count < self.viewStore.path.count {
            return .popFrom(id: self.viewStore.path[newPath.count].id)
          } else {
            return nil
          }
        }
      )
    ) {
      self.root
        .environment(\.navigationDestinationType, State.self)
        .navigationDestination(for: StackState<State>.Component.self) { component in
          NavigationDestinationView(component: component, destination: self.destination)
        }
    }
  }
}

private struct NavigationDestinationView<State, Destination: View>: View {
  let component: StackState<State>.Component
  let destination: (StackState<State>.Component) -> Destination
  var body: some View {
    self.destination(self.component)
      .environment(\.navigationDestinationType, State.self)
      .id(self.component.id)
  }
}

@available(
  *,
  deprecated,
  message:
    "Use 'switch' with a store of observable state, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-SwitchStore-and-CaseLet-with-switch-and-case]"
)
public struct SwitchStore<State, Action, Content: View>: View {
  public let store: Store<State, Action>
  public let content: (State) -> Content

  public init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping (_ initialState: State) -> Content
  ) {
    self.store = store
    self.content = content
  }

  public var body: some View {
    WithViewStore(
      self.store,
      observe: { $0 },
      removeDuplicates: { enumTag($0) == enumTag($1) }
    ) { viewStore in
      self.content(viewStore.state)
        .environmentObject(StoreObservableObject(store: self.store))
    }
  }
}

@available(
  *,
  deprecated,
  message:
    "Use 'switch' with a store of observable state, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-SwitchStore-and-CaseLet-with-switch-and-case]"
)
public struct CaseLet<EnumState, EnumAction, CaseState, CaseAction, Content: View>: View {
  public let toCaseState: (EnumState) -> CaseState?
  public let fromCaseAction: (CaseAction) -> EnumAction
  public let content: (Store<CaseState, CaseAction>) -> Content

  private let fileID: StaticString
  private let filePath: StaticString
  private let line: UInt
  private let column: UInt

  @EnvironmentObject private var store: StoreObservableObject<EnumState, EnumAction>

  public init(
    _ toCaseState: @escaping (EnumState) -> CaseState?,
    action fromCaseAction: @escaping (CaseAction) -> EnumAction,
    @ViewBuilder then content: @escaping (_ store: Store<CaseState, CaseAction>) -> Content,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.toCaseState = toCaseState
    self.fromCaseAction = fromCaseAction
    self.content = content
    self.fileID = fileID
    self.filePath = filePath
    self.line = line
    self.column = column
  }

  public var body: some View {
    IfLetStore(
      self.store.wrappedValue._scope(state: self.toCaseState, action: self.fromCaseAction),
      then: self.content,
      else: {
        _CaseLetMismatchView<EnumState, EnumAction>(
          fileID: self.fileID,
          filePath: self.filePath,
          line: self.line,
          column: self.column
        )
      }
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Use 'switch' with a store of observable state, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-SwitchStore-and-CaseLet-with-switch-and-case]"
)
extension CaseLet where EnumAction == CaseAction {
  public init(
    state toCaseState: @escaping (EnumState) -> CaseState?,
    @ViewBuilder then content: @escaping (_ store: Store<CaseState, CaseAction>) -> Content
  ) {
    self.init(
      toCaseState,
      action: { $0 },
      then: content
    )
  }
}

public struct _CaseLetMismatchView<State, Action>: View {
  @EnvironmentObject private var store: StoreObservableObject<State, Action>
  let fileID: StaticString
  let filePath: StaticString
  let line: UInt
  let column: UInt

  public var body: some View {
    #if DEBUG
      let message = """
        Warning: A "CaseLet" at "\(self.fileID):\(self.line)" was encountered when state was set \
        to another case:

            \(debugCaseOutput(self.store.wrappedValue.withState { $0 }))

        This usually happens when there is a mismatch between the case being switched on and the \
        "CaseLet" view being rendered.

        For example, if ".screenA" is being switched on, but the "CaseLet" view is pointed to \
        ".screenB":

            case .screenA:
              CaseLet(
                /State.screenB, action: Action.screenB
              ) { /* ... */ }

        Look out for typos to ensure that these two cases align.
        """
      return VStack(spacing: 17) {
        #if os(macOS)
          Text("⚠️")
        #else
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.largeTitle)
        #endif

        Text(message)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundColor(.white)
      .padding()
      .background(Color.red.edgesIgnoringSafeArea(.all))
      .onAppear {
        reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
      }
    #else
      return EmptyView()
    #endif
  }
}

private final class StoreObservableObject<State, Action>: ObservableObject {
  let wrappedValue: Store<State, Action>

  init(store: Store<State, Action>) {
    self.wrappedValue = store
  }
}

private func enumTag<Case>(_ `case`: Case) -> UInt32? {
  EnumMetadata(Case.self)?.tag(of: `case`)
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
public struct WithViewStore<ViewState, ViewAction, Content: View>: View {
  private let content: (ViewStore<ViewState, ViewAction>) -> Content
  #if DEBUG
    private let file: StaticString
    private let line: UInt
    private var prefix: String?
    private var previousState: (ViewState) -> ViewState?
    private var storeTypeName: String
  #endif
  @ObservedObject private var viewStore: ViewStore<ViewState, ViewAction>

  init(
    store: Store<ViewState, ViewAction>,
    removeDuplicates isDuplicate: @escaping (ViewState, ViewState) -> Bool,
    content: @escaping (ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.content = content
    #if DEBUG
      self.file = file
      self.line = line
      var previousState: ViewState? = nil
      self.previousState = { currentState in
        defer { previousState = currentState }
        return previousState
      }
      self.storeTypeName = ComposableArchitecture.storeTypeName(of: store)
    #endif
    self.viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: isDuplicate)
  }

  @_documentation(visibility: public)
  public func _printChanges(_ prefix: String = "") -> Self {
    var view = self
    #if DEBUG
      view.prefix = prefix
    #endif
    return view
  }

  public var body: Content {
    #if DEBUG
      Logger.shared.log("WithView\(storeTypeName).body")
      if let prefix = self.prefix {
        var stateDump = ""
        customDump(self.viewStore.state, to: &stateDump, indent: 2)
        let difference =
          self.previousState(self.viewStore.state)
          .map {
            diff($0, self.viewStore.state).map { "(Changed state)\n\($0)" }
              ?? "(No difference in state detected)"
          }
          ?? "(Initial state)\n\(stateDump)"
        print(
          """
          \(prefix.isEmpty ? "" : "\(prefix): ")\
          WithViewStore<\(typeName(ViewState.self)), \(typeName(ViewAction.self)), _>\
          @\(self.file):\(self.line) \(difference)
          """
        )
      }
    #endif
    return self.content(ViewStore(self.viewStore))
  }

  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store._scope(state: toViewState, action: fromViewAction),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store._scope(state: toViewState, action: { $0 }),
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension WithViewStore where ViewState: Equatable, Content: View {
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store._scope(state: toViewState, action: fromViewAction),
      removeDuplicates: { $0 == $1 },
      content: content,
      file: file,
      line: line
    )
  }

  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: State) -> ViewState,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.init(
      store: store._scope(state: toViewState, action: { $0 }),
      removeDuplicates: { $0 == $1 },
      content: content,
      file: file,
      line: line
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension WithViewStore: @preconcurrency DynamicViewContent
where
  ViewState: Collection,
  Content: DynamicViewContent
{
  public typealias Data = ViewState
  public var data: ViewState {
    self.viewStore.state
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension WithViewStore where Content: View {
  @_disfavoredOverload
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: { (_: State) in
        toViewState(BindingViewStore(store: store._scope(state: { $0 }, action: fromViewAction)))
      },
      send: fromViewAction,
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }

  @_disfavoredOverload
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    removeDuplicates isDuplicate: @escaping (_ lhs: ViewState, _ rhs: ViewState) -> Bool,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: toViewState,
      send: { $0 },
      removeDuplicates: isDuplicate,
      content: content,
      file: file,
      line: line
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Use '@ObservableState', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Using-ObservableState"
)
extension WithViewStore where ViewState: Equatable, Content: View {
  @_disfavoredOverload
  public init<State, Action>(
    _ store: Store<State, Action>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    send fromViewAction: @escaping (_ viewAction: ViewAction) -> Action,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: toViewState,
      send: fromViewAction,
      removeDuplicates: { $0 == $1 },
      content: content,
      file: file,
      line: line
    )
  }

  @_disfavoredOverload
  public init<State>(
    _ store: Store<State, ViewAction>,
    observe toViewState: @escaping (_ state: BindingViewStore<State>) -> ViewState,
    @ViewBuilder content: @escaping (_ viewStore: ViewStore<ViewState, ViewAction>) -> Content,
    file: StaticString = #fileID,
    line: UInt = #line
  ) where ViewAction: BindableAction<State> {
    self.init(
      store,
      observe: toViewState,
      removeDuplicates: { $0 == $1 },
      content: content,
      file: file,
      line: line
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Pass a binding of a store to a SwiftUI presentation modifier instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
)
extension View {
  @_spi(Presentation)
  @preconcurrency @MainActor
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body:
      @escaping (
        _ content: Self,
        _ isPresented: Binding<Bool>,
        _ destination: DestinationContent<State, Action>
      ) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      body(self, Binding($item), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  @preconcurrency @MainActor
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder body:
      @escaping (
        _ content: Self,
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<State, Action>
      ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      id: { $0.wrappedValue.map { _ in ObjectIdentifier(State.self) } }
    ) { `self`, $item, destination in
      body(self, $item, destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  @preconcurrency @MainActor
  public func presentation<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    id toID: @escaping (PresentationState<State>) -> AnyHashable?,
    @ViewBuilder body:
      @escaping (
        _ content: Self,
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<State, Action>
      ) -> Content
  ) -> some View {
    PresentationStore(store, id: toID) { $item, destination in
      body(self, $item, destination)
    }
  }

  @_spi(Presentation)
  @preconcurrency @MainActor
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder body:
      @escaping (
        _ content: Self,
        _ isPresented: Binding<Bool>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $item, destination in
      body(self, Binding($item), destination)
    }
  }

  @_disfavoredOverload
  @_spi(Presentation)
  @preconcurrency @MainActor
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder body:
      @escaping (
        _ content: Self,
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      id: { $0.id },
      action: fromDestinationAction,
      body: body
    )
  }

  @_spi(Presentation)
  @ViewBuilder
  @preconcurrency @MainActor
  public func presentation<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Content: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> AnyHashable?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    @ViewBuilder body:
      @escaping (
        Self,
        Binding<AnyIdentifiable?>,
        DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) -> some View {
    PresentationStore(
      store,
      state: toDestinationState,
      id: toID,
      action: fromDestinationAction
    ) { $item, destination in
      body(self, $item, destination)
    }
  }
}

@available(
  *,
  deprecated,
  message:
    "Pass a binding of a store to a SwiftUI presentation modifier instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
)
@_spi(Presentation)
public struct PresentationStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Content: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let toID: (PresentationState<State>) -> AnyHashable?
  let fromDestinationAction: (DestinationAction) -> Action
  let destinationStore: Store<DestinationState?, DestinationAction>
  let content:
    (
      Binding<AnyIdentifiable?>,
      DestinationContent<DestinationState, DestinationAction>
    ) -> Content

  @ObservedObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content:
      @escaping (
        _ isPresented: Binding<Bool>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) where State == DestinationState, Action == DestinationAction {
    self.init(store) { $item, destination in
      content(Binding($item), destination)
    }
  }

  @_disfavoredOverload
  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder content:
      @escaping (
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) where State == DestinationState, Action == DestinationAction {
    self.init(
      store,
      id: { $0.id },
      content: content
    )
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder content:
      @escaping (
        _ isPresented: Binding<Bool>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) {
    self.init(
      store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { $item, destination in
      content(Binding($item), destination)
    }
  }

  @_disfavoredOverload
  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder content:
      @escaping (
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) {
    self.init(
      store,
      state: toDestinationState,
      id: { $0.id },
      action: fromDestinationAction,
      content: content
    )
  }

  fileprivate init<ID: Hashable>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    id toID: @escaping (PresentationState<State>) -> ID?,
    content:
      @escaping (
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) where State == DestinationState, Action == DestinationAction {
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      PresentationCore(base: core, toDestinationState: { $0 })
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    let viewStore = ViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { toID($0) == toID($1) }
    )

    self.store = store
    self.toDestinationState = { $0 }
    self.toID = toID
    self.fromDestinationAction = { $0 }
    self.destinationStore = store.scope(state: \.wrappedValue, action: \.presented)
    self.content = content
    self.viewStore = viewStore
  }

  fileprivate init<ID: Hashable>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> DestinationState?,
    id toID: @escaping (PresentationState<State>) -> ID?,
    action fromDestinationAction: @escaping (DestinationAction) -> Action,
    content:
      @escaping (
        _ item: Binding<AnyIdentifiable?>,
        _ destination: DestinationContent<DestinationState, DestinationAction>
      ) -> Content
  ) {
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      PresentationCore(base: core, toDestinationState: toDestinationState)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    let viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: { toID($0) == toID($1) })

    self.store = store
    self.toDestinationState = toDestinationState
    self.toID = toID
    self.fromDestinationAction = fromDestinationAction
    self.destinationStore = store._scope(
      state: { $0.wrappedValue.flatMap(toDestinationState) },
      action: { .presented(fromDestinationAction($0)) }
    )
    self.content = content
    self.viewStore = viewStore
  }

  public var body: some View {
    let id = self.toID(self.viewStore.state)
    self.content(
      self.viewStore.binding(
        get: {
          $0.wrappedValue.flatMap(toDestinationState) != nil
            ? toID($0).map { AnyIdentifiable(Identified($0) { $0 }) }
            : nil
        },
        compactSend: { [weak viewStore = self.viewStore] in
          guard
            let viewStore = viewStore,
            $0 == nil,
            viewStore.wrappedValue != nil,
            id == nil || self.toID(viewStore.state) == id
          else { return nil }
          return .dismiss
        }
      ),
      DestinationContent(store: self.destinationStore)
    )
  }
}

final class PresentationCore<
  Base: Core<PresentationState<State>, PresentationAction<Action>>,
  State,
  Action,
  DestinationState
>: Core {
  let base: Base
  let toDestinationState: (State) -> DestinationState?
  init(
    base: Base,
    toDestinationState: @escaping (State) -> DestinationState?
  ) {
    self.base = base
    self.toDestinationState = toDestinationState
  }
  var state: Base.State {
    base.state
  }
  func send(_ action: Base.Action, origin: Origin) -> Task<Void, Never>? {
    base.send(action, origin: origin)
  }
  var canStoreCacheChildren: Bool { base.canStoreCacheChildren }
  var didSet: CurrentValueRelay<Void> { base.didSet }
  var isInvalid: Bool { state.wrappedValue.flatMap(toDestinationState) == nil || base.isInvalid }
  var effectCancellables: [UUID: AnyCancellable] { base.effectCancellables }
}

@_spi(Presentation)
public struct AnyIdentifiable: Identifiable {
  public let id: AnyHashable

  public init<Base: Identifiable>(_ base: Base) {
    self.id = base.id
  }
}

@available(
  *,
  deprecated,
  message:
    "Use 'if let' with a store of observable state, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-IfLetStore-with-if-let]"
)
@preconcurrency @MainActor
@_spi(Presentation)
public struct DestinationContent<State, Action> {
  let store: Store<State?, Action>

  public func callAsFunction<Content: View>(
    @ViewBuilder _ body: @escaping (_ store: Store<State, Action>) -> Content
  ) -> some View {
    IfLetStore(self.store, then: body)
  }
}

@available(
  *,
  deprecated,
  message:
    "Pass a binding of a store to the modifier instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Updating-alert-and-confirmationDialog]"
)
extension View {
  @preconcurrency @MainActor
  public func alert<ButtonAction>(
    store: Store<PresentationState<AlertState<ButtonAction>>, PresentationAction<ButtonAction>>
  ) -> some View {
    self._alert(store: store, state: { $0 }, action: { $0 })
  }

  @preconcurrency @MainActor
  func _alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $isPresented, destination in
      let alertState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.alert(
        (alertState?.title).map(Text.init) ?? Text(verbatim: ""),
        isPresented: $isPresented,
        presenting: alertState,
        actions: { alertState in
          ForEach(alertState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action.type {
              case .send(let action):
                if let action {
                  store.send(.presented(fromDestinationAction(action)))
                }
              case .animatedSend(let action, let animation):
                if let action {
                  store.send(.presented(fromDestinationAction(action)), animation: animation)
                }
              }
            } label: {
              Text(button.label)
            }
          }
        },
        message: {
          $0.message.map(Text.init)
        }
      )
    }
  }

  @preconcurrency @MainActor
  public func confirmationDialog<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>,
      PresentationAction<ButtonAction>
    >
  ) -> some View {
    self._confirmationDialog(store: store, state: { $0 }, action: { $0 })
  }

  @preconcurrency @MainActor
  func _confirmationDialog<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ confirmationDialogAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $isPresented, destination in
      let confirmationDialogState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.confirmationDialog(
        (confirmationDialogState?.title).map(Text.init) ?? Text(verbatim: ""),
        isPresented: $isPresented,
        titleVisibility: (confirmationDialogState?.titleVisibility).map(Visibility.init)
          ?? .automatic,
        presenting: confirmationDialogState,
        actions: { confirmationDialogState in
          ForEach(confirmationDialogState.buttons) { button in
            Button(role: button.role.map(ButtonRole.init)) {
              switch button.action.type {
              case .send(let action):
                if let action {
                  store.send(.presented(fromDestinationAction(action)))
                }
              case .animatedSend(let action, let animation):
                if let action {
                  store.send(.presented(fromDestinationAction(action)), animation: animation)
                }
              }
            } label: {
              Text(button.label)
            }
          }
        },
        message: {
          $0.message.map(Text.init)
        }
      )
    }
  }

  @preconcurrency @MainActor
  public func navigationDestination<State, Action, Destination: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination
  ) -> some View {
    self.presentation(
      store: store,
      id: { $0.wrappedValue.map(NavigationDestinationID.init) }
    ) { `self`, $item, destinationContent in
      self.navigationDestination(isPresented: Binding($item)) {
        destinationContent(destination)
      }
    }
  }

  @preconcurrency @MainActor
  public func sheet<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (_ store: Store<State, Action>) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      self.sheet(item: $item, onDismiss: onDismiss) { _ in
        destination(content)
      }
    }
  }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension View {
  @available(
    *,
    deprecated,
    message:
      "Pass a binding of a store to the modifier instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Updating-alert-and-confirmationDialog]"
  )
  @preconcurrency @MainActor
  public func popover<State, Action, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (_ store: Store<State, Action>) -> Content
  ) -> some View {
    self.presentation(store: store) { `self`, $item, destination in
      self.popover(item: $item, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) { _ in
        destination(content)
      }
    }
  }
}

struct NavigationDestinationID: Hashable {
  let objectIdentifier: ObjectIdentifier
  let enumTag: UInt32?

  init<Value>(_ value: Value) {
    self.objectIdentifier = ObjectIdentifier(Value.self)
    self.enumTag = EnumMetadata(Value.self)?.tag(of: value)
  }
}

@available(iOS, introduced: 13)
@available(macOS, introduced: 10.15)
@available(tvOS, introduced: 13)
@available(watchOS, introduced: 6)
extension View {
  @available(*, deprecated, message: "use 'View.alert' instead.")
  @preconcurrency @MainActor
  public func legacyAlert<ButtonAction>(
    store: Store<PresentationState<AlertState<ButtonAction>>, PresentationAction<ButtonAction>>
  ) -> some View {
    self.legacyAlert(store: store, state: { $0 }, action: { $0 })
  }

  @available(*, deprecated, message: "use 'View.alert' instead.")
  @preconcurrency @MainActor
  public func legacyAlert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $item, _ in
      let alertState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.alert(item: $item) { _ in
        Alert(alertState!) { action in
          if let action {
            store.send(.presented(fromDestinationAction(action)))
          } else {
            store.send(.dismiss)
          }
        }
      }
    }
  }
}

@available(iOS, introduced: 13)
@available(macOS, unavailable)
@available(tvOS, introduced: 13)
@available(watchOS, introduced: 6)
extension View {
  @available(*, deprecated, message: "use 'View.confirmationDialog' instead.")
  @preconcurrency @MainActor
  public func actionSheet<ButtonAction>(
    store: Store<
      PresentationState<ConfirmationDialogState<ButtonAction>>, PresentationAction<ButtonAction>
    >
  ) -> some View {
    self.actionSheet(store: store, state: { $0 }, action: { $0 })
  }

  @available(*, deprecated, message: "use 'View.confirmationDialog' instead.")
  @preconcurrency @MainActor
  public func actionSheet<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $item, _ in
      let actionSheetState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.actionSheet(item: $item) { _ in
        ActionSheet(actionSheetState!) { action in
          if let action {
            store.send(.presented(fromDestinationAction(action)))
          } else {
            store.send(.dismiss)
          }
        }
      }
    }
  }
}

@available(*, deprecated)
public struct NavigationLinkStore<
  State,
  Action,
  DestinationState,
  DestinationAction,
  Destination: View,
  Label: View
>: View {
  let store: Store<PresentationState<State>, PresentationAction<Action>>
  @ObservedObject var viewStore: ViewStore<Bool, PresentationAction<Action>>
  let toDestinationState: (State) -> DestinationState?
  let fromDestinationAction: (DestinationAction) -> Action
  let onTap: () -> Void
  let destination: (Store<DestinationState, DestinationAction>) -> Destination
  let label: Label
  var isDetailLink = true

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction {
    self.init(
      store,
      state: { $0 },
      action: { $0 },
      onTap: onTap,
      destination: destination,
      label: label
    )
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    onTap: @escaping () -> Void,
    @ViewBuilder destination:
      @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination,
    @ViewBuilder label: () -> Label
  ) {
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      PresentationCore(base: core, toDestinationState: toDestinationState)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    self.store = store
    self.viewStore = ViewStore(
      store._scope(
        state: { $0.wrappedValue.flatMap(toDestinationState) != nil },
        action: { $0 }
      ),
      observe: { $0 }
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    id: State.ID,
    onTap: @escaping () -> Void,
    @ViewBuilder destination: @escaping (_ store: Store<State, Action>) -> Destination,
    @ViewBuilder label: () -> Label
  ) where State == DestinationState, Action == DestinationAction, State: Identifiable {
    self.init(
      store,
      state: { $0 },
      action: { $0 },
      id: id,
      onTap: onTap,
      destination: destination,
      label: label
    )
  }

  public init(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    id: DestinationState.ID,
    onTap: @escaping () -> Void,
    @ViewBuilder destination:
      @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination,
    @ViewBuilder label: () -> Label
  ) where DestinationState: Identifiable {
    func open(
      _ core: some Core<PresentationState<State>, PresentationAction<Action>>
    ) -> any Core<PresentationState<State>, PresentationAction<Action>> {
      NavigationLinkCore(base: core, id: id, toDestinationState: toDestinationState)
    }
    let store = store.scope(
      id: store.id(state: \.self, action: \.self),
      childCore: open(store.core)
    )
    self.store = store
    self.viewStore = ViewStore(
      store._scope(
        state: { $0.wrappedValue.flatMap(toDestinationState)?.id == id },
        action: { $0 }
      ),
      observe: { $0 }
    )
    self.toDestinationState = toDestinationState
    self.fromDestinationAction = fromDestinationAction
    self.onTap = onTap
    self.destination = destination
    self.label = label()
  }

  public var body: some View {
    NavigationLink(
      isActive: Binding(
        get: { self.viewStore.state },
        set: {
          if $0 {
            withTransaction($1, self.onTap)
          } else if self.viewStore.state {
            self.viewStore.send(.dismiss, transaction: $1)
          }
        }
      )
    ) {
      IfLetStore(
        self.store._scope(
          state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
          action: { .presented(self.fromDestinationAction($0)) }
        ),
        then: self.destination
      )
    } label: {
      self.label
    }
    #if os(iOS)
      .isDetailLink(self.isDetailLink)
    #endif
  }

  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func isDetailLink(_ isDetailLink: Bool) -> Self {
    var link = self
    link.isDetailLink = isDetailLink
    return link
  }
}

private final class NavigationLinkCore<
  Base: Core<PresentationState<State>, PresentationAction<Action>>,
  State,
  Action,
  DestinationState: Identifiable
>: Core {
  let base: Base
  let id: DestinationState.ID
  let toDestinationState: (State) -> DestinationState?
  init(
    base: Base,
    id: DestinationState.ID,
    toDestinationState: @escaping (State) -> DestinationState?
  ) {
    self.base = base
    self.id = id
    self.toDestinationState = toDestinationState
  }
  var state: Base.State {
    base.state
  }
  func send(_ action: Base.Action, origin: Origin) -> Task<Void, Never>? {
    base.send(action, origin: origin)
  }
  var canStoreCacheChildren: Bool { base.canStoreCacheChildren }
  var didSet: CurrentValueRelay<Void> { base.didSet }
  var isInvalid: Bool { state.wrappedValue.flatMap(toDestinationState)?.id != id || base.isInvalid }
  var effectCancellables: [UUID: AnyCancellable] { base.effectCancellables }
}

extension Store {
  @available(*, deprecated, message: "Use 'observe' and 'if let store.scope', instead.")
  public func ifLet<Wrapped>(
    then unwrap: @escaping (_ store: Store<Wrapped, Action>) -> Void,
    else: @escaping () -> Void = {}
  ) -> any Cancellable where State == Wrapped? {
    return self
      .publisher
      .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
      .sink { [weak self] state in
        if let self, let state {
          @MainActor
          func open(_ core: some Core<State, Action>) -> any Core<Wrapped, Action> {
            IfLetCore(
              base: core,
              cachedState: state,
              stateKeyPath: \.self,
              actionKeyPath: \.self
            )
          }
          unwrap(self.scope(id: nil, childCore: open(self.core)))
        } else {
          `else`()
        }
      }
  }
}

@available(
  *,
  deprecated,
  message:
    "Deriving bindings directly from stores using '@ObservableState'. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#BindingState"
)
@propertyWrapper
public struct BindingState<Value> {
  public var wrappedValue: Value
  #if DEBUG
    let fileID: StaticString
    let filePath: StaticString
    let line: UInt
    let column: UInt
  #endif

  public init(
    wrappedValue: Value,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.wrappedValue = wrappedValue
    #if DEBUG
      self.fileID = fileID
      self.filePath = filePath
      self.line = line
      self.column = column
    #endif
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

@available(*, deprecated)
extension BindingState: Equatable where Value: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

@available(*, deprecated)
extension BindingState: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    self.wrappedValue.hash(into: &hasher)
  }
}

@available(*, deprecated)
extension BindingState: Decodable where Value: Decodable {
  public init(from decoder: any Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()
      self.init(wrappedValue: try container.decode(Value.self))
    } catch {
      self.init(wrappedValue: try Value(from: decoder))
    }
  }
}

@available(*, deprecated)
extension BindingState: Encodable where Value: Encodable {
  public func encode(to encoder: any Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

@available(*, deprecated)
extension BindingState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}

@available(*, deprecated)
extension BindingState: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

@available(*, deprecated)
extension BindingState: CustomDebugStringConvertible where Value: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.wrappedValue.debugDescription
  }
}

@available(*, deprecated)
extension BindingState: Sendable where Value: Sendable {}

@available(
  *,
  deprecated,
  message:
    "Deriving bindings directly from stores using '@ObservableState'. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#BindingState"
)
extension BindableAction {
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: _SendableWritableKeyPath<State, BindingState<Value>>,
    _ value: Value
  ) -> Self {
    self.binding(.set(keyPath, value))
  }
}

@available(
  *,
  deprecated,
  message:
    "Deriving bindings directly from stores using '@ObservableState'. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#BindingState"
)
extension BindingAction {
  public static func set<Value: Equatable & Sendable>(
    _ keyPath: _SendableWritableKeyPath<Root, BindingState<Value>>,
    _ value: Value
  ) -> Self {
    return .init(
      keyPath: keyPath,
      set: { $0[keyPath: keyPath].wrappedValue = value },
      value: value
    )
  }

  init<Value: Equatable & Sendable>(
    keyPath: _SendableWritableKeyPath<Root, BindingState<Value>>,
    set: @escaping @Sendable (_ state: inout Root) -> Void,
    value: Value
  ) {
    self.init(
      keyPath: keyPath,
      set: set,
      value: value,
      valueIsEqualTo: { $0 as? Value == value }
    )
  }
}

@available(
  *,
  deprecated,
  message:
    "Deriving bindings directly from stores using '@ObservableState'. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#BindingState"
)
extension BindingAction.AllCasePaths {
  public subscript<Value: Equatable & Sendable>(
    dynamicMember keyPath: WritableKeyPath<Root, BindingState<Value>>
  ) -> AnyCasePath<BindingAction, Value> {
    let keyPath = keyPath.unsafeSendable()
    return AnyCasePath(
      embed: { .set(keyPath, $0) },
      extract: { $0.keyPath == keyPath ? $0.value as? Value : nil }
    )
  }
}

extension BindingReducer {
  @inlinable
  @available(
    *,
    deprecated,
    message:
      "Use the version of this API that takes a case key path, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public init(action toViewAction: @escaping (_ action: Action) -> ViewAction?) {
    self.init(internal: toViewAction)
  }
}

@available(
  *,
  deprecated,
  message:
    "Deriving bindings directly from stores using '@ObservableState'. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#BindingState"
)
extension BindingViewStore {
  public subscript<Value: Equatable & Sendable>(
    dynamicMember keyPath: WritableKeyPath<State, BindingState<Value>>
  ) -> BindingViewState<Value> {
    let keyPath = keyPath.unsafeSendable()
    return BindingViewState(
      binding: ViewStore(self.store, observe: { $0[keyPath: keyPath].wrappedValue })
        .binding(
          send: { value in
            #if DEBUG
              let debugger = BindableActionViewStoreDebugger(
                value: value,
                bindableActionType: self.bindableActionType,
                context: .bindingStore,
                isInvalidated: { [weak store] in store?.core.isInvalid ?? true },
                fileID: self.fileID,
                filePath: self.filePath,
                line: self.line,
                column: self.column
              )
              let set: @Sendable (inout State) -> Void = {
                $0[keyPath: keyPath].wrappedValue = value
                debugger.wasCalled.setValue(true)
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

@available(
  *,
  deprecated,
  message:
    "Deriving bindings directly from stores using '@ObservableState'. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#BindingState"
)
extension ViewStore where ViewAction: BindableAction, ViewAction.State == ViewState {
  public subscript<Value: Equatable & Sendable>(
    dynamicMember keyPath: WritableKeyPath<ViewState, BindingState<Value>>
  ) -> Binding<Value> {
    let keyPath = keyPath.unsafeSendable()
    return self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let bindingState = self.state[keyPath: keyPath]
          let debugger = BindableActionViewStoreDebugger(
            value: value,
            bindableActionType: ViewAction.self,
            context: .bindingState,
            isInvalidated: { [weak self] in self?.store.core.isInvalid ?? true },
            fileID: bindingState.fileID,
            filePath: bindingState.filePath,
            line: bindingState.line,
            column: bindingState.column
          )
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled.setValue(true)
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

@available(
  *,
  deprecated,
  message:
    "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
)
extension IfLetStore {
  @preconcurrency @MainActor
  public init<IfContent, ElseContent>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    self.init(
      store.scope(state: \.wrappedValue, action: \.presented),
      then: ifContent,
      else: elseContent
    )
  }

  @available(
    *,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public init<IfContent>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent
  ) where Content == IfContent? {
    self.init(
      store.scope(state: \.wrappedValue, action: \.presented),
      then: ifContent
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public init<DestinationState, DestinationAction, IfContent, ElseContent>(
    _ store: Store<PresentationState<DestinationState>, PresentationAction<DestinationAction>>,
    state toState: @escaping (_ destinationState: DestinationState) -> State?,
    action fromAction: @escaping (_ action: Action) -> DestinationAction,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    self.init(
      store.scope(
        state: { $0.wrappedValue.flatMap(toState) },
        action: { .presented(fromAction($0)) }
      ),
      then: ifContent,
      else: elseContent
    )
  }

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of
  /// ``PresentationState`` and ``PresentationAction`` is `nil` or non-`nil` and state can further
  /// be extracted from the destination state, _e.g._ it matches a particular case of an enum.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - toState: A closure that attempts to extract state for the "if" branch from the destination
  ///     state.
  ///   - fromAction: A closure that embeds actions for the "if" branch in destination actions.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil` and state can be extracted from the
  ///     destination state.
  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public init<DestinationState, DestinationAction, IfContent>(
    _ store: Store<PresentationState<DestinationState>, PresentationAction<DestinationAction>>,
    state toState: @escaping (_ destinationState: DestinationState) -> State?,
    action fromAction: @escaping (_ action: Action) -> DestinationAction,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent
  ) where Content == IfContent? {
    self.init(
      store.scope(
        state: { $0.wrappedValue.flatMap(toState) },
        action: { .presented(fromAction($0)) }
      ),
      then: ifContent
    )
  }
}

extension Store {
  @available(
    *,
    deprecated,
    message:
      "Pass 'state' a key path to child state and 'action' a case key path to child action, instead. For more information see the following migration guide: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Store-scoping-with-key-paths"
  )
  public func scope<ChildState, ChildAction>(
    state toChildState: @escaping (_ state: State) -> ChildState,
    action fromChildAction: @escaping (_ childAction: ChildAction) -> Action
  ) -> Store<ChildState, ChildAction> {
    _scope(state: toChildState, action: fromChildAction)
  }
}

extension View {
  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public func alert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self._alert(store: store, state: toDestinationState, action: fromDestinationAction)
  }

  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public func confirmationDialog<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> ConfirmationDialogState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ confirmationDialogAction: ButtonAction) -> Action
  ) -> some View {
    self._confirmationDialog(store: store, state: toDestinationState, action: fromDestinationAction)
  }

  #if !os(macOS)
    @available(
      *,
      deprecated,
      message:
        "Pass a binding of a store to 'fullScreenCover(item:)' instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers]"
    )
    public func fullScreenCover<State, Action, Content: View>(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      onDismiss: (() -> Void)? = nil,
      @ViewBuilder content: @escaping (_ store: Store<State, Action>) -> Content
    ) -> some View {
      self.presentation(store: store) { `self`, $item, destination in
        self.fullScreenCover(item: $item, onDismiss: onDismiss) { _ in
          destination(content)
        }
      }
    }

    @available(
      *,
      deprecated,
      message:
        "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
    )
    public func fullScreenCover<State, Action, DestinationState, DestinationAction, Content: View>(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      state toDestinationState: @escaping (_ state: State) -> DestinationState?,
      action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
      onDismiss: (() -> Void)? = nil,
      @ViewBuilder content:
        @escaping (_ store: Store<DestinationState, DestinationAction>) ->
        Content
    ) -> some View {
      self.presentation(
        store: store,
        state: toDestinationState,
        action: fromDestinationAction
      ) { `self`, $item, destination in
        self.fullScreenCover(item: $item, onDismiss: onDismiss) { _ in
          destination(content)
        }
      }
    }
  #endif

  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public func navigationDestination<
    State,
    Action,
    DestinationState,
    DestinationAction,
    Destination: View
  >(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    @ViewBuilder destination:
      @escaping (_ store: Store<DestinationState, DestinationAction>) ->
      Destination
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      id: { $0.wrappedValue.map(NavigationDestinationID.init) },
      action: fromDestinationAction
    ) { `self`, $item, destinationContent in
      self.navigationDestination(isPresented: Binding($item)) {
        destinationContent(destination)
      }
    }
  }

  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public func popover<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (_ store: Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $item, destination in
      self.popover(item: $item, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) { _ in
        destination(content)
      }
    }
  }

  @available(
    *,
    deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @preconcurrency @MainActor
  public func sheet<State, Action, DestinationState, DestinationAction, Content: View>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> DestinationState?,
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping (_ store: Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.presentation(
      store: store,
      state: toDestinationState,
      action: fromDestinationAction
    ) { `self`, $item, destination in
      self.sheet(item: $item, onDismiss: onDismiss) { _ in
        destination(content)
      }
    }
  }
}

extension PresentationState {
  @available(
    *,
    deprecated,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public subscript<Case>(
    case path: AnyCasePath<State, Case>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Case? {
    _read { yield self[_case: path] }
    _modify { yield &self[_case: path] }
  }
}

extension Reducer {
  @available(
    *,
    deprecated,
    message:
      "Use a case key path to an 'IdentifiedAction', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4"
  )
  @inlinable
  @warn_unqualified_access
  public func forEach<
    ElementState,
    ElementAction,
    ID: Hashable & Sendable,
    Element: Reducer<ElementState, ElementAction>
  >(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: AnyCasePath<Action, (ID, ElementAction)>,
    @ReducerBuilder<ElementState, ElementAction> element: () -> Element,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _ForEachReducer(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: .init(
        embed: { toElementAction.embed($0) },
        extract: { toElementAction.extract(from: $0) }
      ),
      element: element(),
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  @warn_unqualified_access
  public func forEach<
    DestinationState,
    DestinationAction,
    Destination: Reducer<DestinationState, DestinationAction>
  >(
    _ toStackState: WritableKeyPath<State, StackState<DestinationState>>,
    action toStackAction: AnyCasePath<Action, StackAction<DestinationState, DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _StackReducer(
      base: self,
      toStackState: toStackState,
      toStackAction: toStackAction,
      destination: destination(),
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  @warn_unqualified_access
  public func ifCaseLet<CaseState, CaseAction, Case: Reducer<CaseState, CaseAction>>(
    _ toCaseState: AnyCasePath<State, CaseState>,
    action toCaseAction: AnyCasePath<Action, CaseAction>,
    @ReducerBuilder<CaseState, CaseAction> then case: () -> Case,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _IfCaseLetReducer(
      parent: self,
      child: `case`(),
      toChildState: toCaseState,
      toChildAction: toCaseAction,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  @warn_unqualified_access
  public func ifLet<WrappedState, WrappedAction, Wrapped: Reducer<WrappedState, WrappedAction>>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: AnyCasePath<Action, WrappedAction>,
    @ReducerBuilder<WrappedState, WrappedAction> then wrapped: () -> Wrapped,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _IfLetReducer(
      parent: self,
      child: wrapped(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  @warn_unqualified_access
  public func ifLet<WrappedState: _EphemeralState, WrappedAction>(
    _ toWrappedState: WritableKeyPath<State, WrappedState?>,
    action toWrappedAction: AnyCasePath<Action, WrappedAction>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> _IfLetReducer<Self, EmptyReducer<WrappedState, WrappedAction>> {
    .init(
      parent: self,
      child: EmptyReducer(),
      toChildState: toWrappedState,
      toChildAction: toWrappedAction,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @warn_unqualified_access
  @inlinable
  public func ifLet<
    DestinationState,
    DestinationAction,
    Destination: Reducer<DestinationState, DestinationAction>
  >(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: AnyCasePath<Action, PresentationAction<DestinationAction>>,
    @ReducerBuilder<DestinationState, DestinationAction> destination: () -> Destination,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    _PresentationReducer(
      base: self,
      toPresentationState: toPresentationState,
      toPresentationAction: toPresentationAction,
      destination: destination(),
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @warn_unqualified_access
  @inlinable
  public func ifLet<DestinationState: _EphemeralState, DestinationAction>(
    _ toPresentationState: WritableKeyPath<State, PresentationState<DestinationState>>,
    action toPresentationAction: AnyCasePath<Action, PresentationAction<DestinationAction>>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> some Reducer<State, Action> {
    self.ifLet(
      toPresentationState,
      action: toPresentationAction,
      destination: {},
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }
}

extension Scope {
  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  public init<ChildState, ChildAction>(
    state toChildState: WritableKeyPath<ParentState, ChildState>,
    action toChildAction: AnyCasePath<ParentAction, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child
  ) where ChildState == Child.State, ChildAction == Child.Action {
    self.init(
      toChildState: .keyPath(toChildState),
      toChildAction: toChildAction,
      child: child()
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  @inlinable
  public init<ChildState, ChildAction>(
    state toChildState: AnyCasePath<ParentState, ChildState>,
    action toChildAction: AnyCasePath<ParentAction, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) where ChildState == Child.State, ChildAction == Child.Action {
    self.init(
      toChildState: .casePath(
        toChildState,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      ),
      toChildAction: toChildAction,
      child: child()
    )
  }
}

extension StackState {
  @available(
    *,
    deprecated,
    message:
      "Use the version of this subscript with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public subscript<Case>(
    id id: StackElementID,
    case path: AnyCasePath<Element, Case>,
    fileID fileID: _HashableStaticString = #fileID,
    filePath filePath: _HashableStaticString = #filePath,
    line line: UInt = #line,
    column column: UInt = #column
  ) -> Case? {
    _read {
      yield self[
        id: id,
        _case: path,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      ]
    }
    _modify {
      yield &self[
        id: id,
        _case: path,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      ]
    }
  }
}

extension TestStore {
  @_disfavoredOverload
  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public func receive<Value>(
    _ actionCase: AnyCasePath<Action, Value>,
    timeout duration: Duration? = nil,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async {
    await self._receive(
      actionCase,
      timeout: duration,
      assert: updateStateToExpectedResult,
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message:
      "Use the version of this operator with case key paths, instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Using-case-key-paths"
  )
  public func bindings<ViewAction: BindableAction>(
    action toViewAction: AnyCasePath<Action, ViewAction>
  ) -> BindingViewStore<State> where State == ViewAction.State {
    self._bindings(action: toViewAction)
  }
}

@available(
  *,
  message:
    "Use 'Result', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Moving-off-of-TaskResult"
)
public enum TaskResult<Success: Sendable>: Sendable {
  case success(Success)
  case failure(any Error)

  @_transparent
  public init(catching body: @Sendable () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }

  @inlinable
  public init<Failure>(_ result: Result<Success, Failure>) {
    switch result {
    case .success(let value):
      self = .success(value)
    case .failure(let error):
      self = .failure(error)
    }
  }

  @inlinable
  public var value: Success {
    get throws {
      switch self {
      case .success(let value):
        return value
      case .failure(let error):
        throw error
      }
    }
  }

  @inlinable
  public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> TaskResult<NewSuccess> {
    switch self {
    case .success(let value):
      return .success(transform(value))
    case .failure(let error):
      return .failure(error)
    }
  }

  @inlinable
  public func flatMap<NewSuccess>(
    _ transform: (Success) -> TaskResult<NewSuccess>
  ) -> TaskResult<NewSuccess> {
    switch self {
    case .success(let value):
      return transform(value)
    case .failure(let error):
      return .failure(error)
    }
  }
}

extension TaskResult: CasePathable {
  public static var allCasePaths: AllCasePaths {
    AllCasePaths()
  }

  public struct AllCasePaths {
    public var success: AnyCasePath<TaskResult, Success> {
      AnyCasePath(
        embed: { .success($0) },
        extract: {
          guard case .success(let value) = $0 else { return nil }
          return value
        }
      )
    }

    public var failure: AnyCasePath<TaskResult, any Error> {
      AnyCasePath(
        embed: { .failure($0) },
        extract: {
          guard case .failure(let value) = $0 else { return nil }
          return value
        }
      )
    }
  }
}

extension Result where Success: Sendable, Failure == any Error {
  @available(
    *,
    message:
      "Use 'Result', instead. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.4#Moving-off-of-TaskResult"
  )
  @inlinable
  public init(_ result: TaskResult<Success>) {
    switch result {
    case .success(let value):
      self = .success(value)
    case .failure(let error):
      self = .failure(error)
    }
  }
}

enum TaskResultDebugging {
  @TaskLocal static var emitRuntimeWarnings = true
}

extension TaskResult: Equatable where Success: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.success(let lhs), .success(let rhs)):
      return lhs == rhs
    case (.failure(let lhs), .failure(let rhs)):
      return _isEqual(lhs, rhs)
        ?? {
          #if DEBUG
            let lhsType = type(of: lhs)
            if TaskResultDebugging.emitRuntimeWarnings, lhsType == type(of: rhs) {
              let lhsTypeName = typeName(lhsType)
              reportIssue(
                """
                "\(lhsTypeName)" is not equatable.

                To test two values of this type, it must conform to the "Equatable" protocol. For \
                example:

                    extension \(lhsTypeName): Equatable {}

                See the documentation of "TaskResult" for more information.
                """
              )
            }
          #endif
          return false
        }()
    default:
      return false
    }
  }
}

extension TaskResult: Hashable where Success: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .success(let value):
      hasher.combine(value)
      hasher.combine(0)
    case .failure(let error):
      if let error = (error as Any) as? AnyHashable {
        hasher.combine(error)
        hasher.combine(1)
      } else {
        #if DEBUG
          if TaskResultDebugging.emitRuntimeWarnings {
            let errorType = typeName(type(of: error))
            reportIssue(
              """
              "\(errorType)" is not hashable.

              To hash a value of this type, it must conform to the "Hashable" protocol. For example:

                  extension \(errorType): Hashable {}

              See the documentation of "TaskResult" for more information.
              """
            )
          }
        #endif
      }
    }
  }
}

extension TaskResult {
  // NB: For those that try to interface with `TaskResult` using `Result`'s old API.
  @available(*, unavailable, renamed: "value")
  public func get() throws -> Success {
    try self.value
  }
}

extension TestStore {
  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func finish(
    timeout nanoseconds: UInt64,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async {
    await self.finish(
      timeout: Duration(nanoseconds: nanoseconds),
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func receive(
    _ expectedAction: Action,
    timeout nanoseconds: UInt64,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async
  where Action: Equatable {
    await self.receive(
      expectedAction,
      timeout: Duration(nanoseconds: nanoseconds),
      assert: updateStateToExpectedResult,
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func receive(
    _ isMatching: (_ action: Action) -> Bool,
    timeout nanoseconds: UInt64,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async {
    await self.receive(
      isMatching,
      timeout: Duration(nanoseconds: nanoseconds),
      assert: updateStateToExpectedResult,
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func receive<Value>(
    _ actionCase: CaseKeyPath<Action, Value>,
    timeout nanoseconds: UInt64,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async {
    await self._receive(
      AnyCasePath(actionCase),
      timeout: Duration(nanoseconds: nanoseconds),
      assert: updateStateToExpectedResult,
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func receive<Value: Equatable>(
    _ actionCase: CaseKeyPath<Action, Value>,
    _ value: Value,
    timeout nanoseconds: UInt64,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async
  where Action: CasePathable {
    await self.receive(
      actionCase,
      value,
      timeout: Duration(nanoseconds: nanoseconds),
      assert: updateStateToExpectedResult,
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }

  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func receive<Value>(
    _ actionCase: AnyCasePath<Action, Value>,
    timeout nanoseconds: UInt64,
    assert updateStateToExpectedResult: ((_ state: inout State) throws -> Void)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async {
    await self._receive(
      actionCase,
      timeout: Duration(nanoseconds: nanoseconds),
      assert: updateStateToExpectedResult,
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }
}

extension TestStoreTask {
  @available(
    *,
    deprecated,
    message: "Use the overload that takes a 'Duration' timeout, instead."
  )
  @_disfavoredOverload
  public func finish(
    timeout nanoseconds: UInt64,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) async {
    await self.finish(
      timeout: Duration(nanoseconds: nanoseconds),
      fileID: fileID,
      file: filePath,
      line: line,
      column: column
    )
  }
}

extension Duration {
  fileprivate init(nanoseconds: UInt64) {
    self =
      .seconds(Int64(nanoseconds / NSEC_PER_SEC))
      + .nanoseconds(Int64(nanoseconds % NSEC_PER_SEC))
  }
}

// NB: Deprecated with 1.13.0:

#if canImport(UIKit) && !os(watchOS)
  extension UIAlertController {
    @_disfavoredOverload
    @available(*, unavailable, renamed: "init(state:handler:)")
    public convenience init<Action>(
      state: AlertState<Action>,
      send: @escaping (_ action: Action?) -> Void
    ) {
      fatalError()
    }

    @_disfavoredOverload
    @available(*, unavailable, renamed: "init(state:handler:)")
    public convenience init<Action>(
      state: ConfirmationDialogState<Action>,
      send: @escaping (_ action: Action?) -> Void
    ) {
      fatalError()
    }

    @available(
      *,
      deprecated,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    public convenience init<Action>(
      store: Store<AlertState<Action>, PresentationAction<Action>>
    ) {
      let state = store.currentState
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .alert
      )
      for button in state.buttons {
        self.addAction(.init(button, action: { store.send($0.map { .presented($0) } ?? .dismiss) }))
      }
      if state.buttons.isEmpty {
        self.addAction(
          .init(
            title: "OK",
            style: .cancel,
            handler: { _ in store.send(.dismiss) }
          )
        )
      }
    }

    @available(
      *,
      deprecated,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    public convenience init<Action>(
      store: Store<ConfirmationDialogState<Action>, PresentationAction<Action>>
    ) {
      let state = store.currentState
      self.init(
        title: String(state: state.title),
        message: state.message.map { String(state: $0) },
        preferredStyle: .actionSheet
      )
      for button in state.buttons {
        self.addAction(.init(button, action: { store.send($0.map { .presented($0) } ?? .dismiss) }))
      }
      if state.buttons.isEmpty {
        self.addAction(
          .init(
            title: "OK",
            style: .cancel,
            handler: { _ in store.send(.dismiss) }
          )
        )
      }
    }
  }
#endif

#if canImport(SwiftUI)
  extension Binding {
    @available(
      *,
      deprecated,
      message: "Use 'Binding.init(_:)' to project an optional binding to a Boolean, instead."
    )
    public func isPresent<Wrapped>() -> Binding<Bool>
    where Value == Wrapped? {
      Binding<Bool>(self)
    }
  }
#endif

// NB: Deprecated with 1.10.0:

@available(*, deprecated, message: "Use '.fileSystem' ('FileStorage.fileSystem') instead")
public func LiveFileStorage() -> FileStorage { .fileSystem }

@available(*, deprecated, message: "Use '.inMemory' ('FileStorage.inMemory') instead")
public func InMemoryFileStorage() -> FileStorage { .inMemory }

// NB: Deprecated with 1.7.0:

extension Reducer {
  @available(*, deprecated, message: "Use 'onChange(of:)' with an equatable value, instead.")
  @inlinable
  public func onChange<V, R: Reducer>(
    of toValue: @escaping (State) -> V,
    removeDuplicates isDuplicate: @escaping (V, V) -> Bool,
    @ReducerBuilder<State, Action> _ reducer: @escaping (_ oldValue: V, _ newValue: V) -> R
  ) -> _OnChangeReducer<Self, V, R> {
    _OnChangeReducer(base: self, toValue: toValue, isDuplicate: isDuplicate, reducer: reducer)
  }
}

// NB: Deprecated with 1.0.0:

@available(*, unavailable, renamed: "Effect")
public typealias EffectTask = Effect

@available(*, unavailable, renamed: "Reducer")
public typealias ReducerProtocol = Reducer

@available(*, unavailable, renamed: "ReducerOf")
public typealias ReducerProtocolOf<R: Reducer> = Reducer<R.State, R.Action>
