import Combine
import SwiftUI

/// A view that safely unwraps a store of optional state in order to show one of two views.
///
/// When the underlying state is non-`nil`, the `then` closure will be performed with a ``Store``
/// that holds onto non-optional state, and otherwise the `else` closure will be performed.
///
/// This is useful for deciding between two views to show depending on an optional piece of state:
///
/// ```swift
/// IfLetStore(
///   store.scope(state: \.results, action: { .results($0) })
/// ) {
///   SearchResultsView(store: $0)
/// } else: {
///   Text("Loading search results...")
/// }
/// ```
///
@available(
  iOS, deprecated: 9999,
  message:
    "Use 'if let' with a store of observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-IfLetStore-with-if-let]"
)
@available(
  macOS, deprecated: 9999,
  message:
    "Use 'if let' with a store of observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-IfLetStore-with-if-let]"
)
@available(
  tvOS, deprecated: 9999,
  message:
    "Use 'if let' with a store of observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-IfLetStore-with-if-let]"
)
@available(
  watchOS, deprecated: 9999,
  message:
    "Use 'if let' with a store of observable state, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7#Replacing-IfLetStore-with-if-let]"
)
public struct IfLetStore<State, Action, Content: View>: View {
  private let content: (ViewStore<State?, Action>) -> Content
  private let store: Store<State?, Action>

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of optional
  /// state is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  ///   - elseContent: A view that is only visible when the optional state is `nil`.
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of optional
  /// state is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of
  /// ``PresentationState`` and ``PresentationAction`` is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  ///   - elseContent: A view that is only visible when the optional state is `nil`.
  @available(
    iOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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

  /// Initializes an ``IfLetStore`` view that computes content depending on if a store of
  /// ``PresentationState`` and ``PresentationAction`` is `nil` or non-`nil`.
  ///
  /// - Parameters:
  ///   - store: A store of optional state.
  ///   - ifContent: A function that is given a store of non-optional state and returns a view that
  ///     is visible only when the optional state is non-`nil`.
  @available(
    iOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    watchOS, deprecated: 9999,
    message:
      "Scope the store into the destination's wrapped 'state' and presented 'action', instead: 'store.scope(state: \\.destination, action: \\.destination.presented)'. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
  public init<IfContent>(
    _ store: Store<PresentationState<State>, PresentationAction<Action>>,
    @ViewBuilder then ifContent: @escaping (_ store: Store<State, Action>) -> IfContent
  ) where Content == IfContent? {
    self.init(
      store.scope(state: \.wrappedValue, action: \.presented),
      then: ifContent
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
  ///   - elseContent: A view that is only visible when state cannot be extracted from the
  ///     destination.
  @available(
    *, deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
    *, deprecated,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  #if swift(<5.10)
    @MainActor(unsafe)
  #else
    @preconcurrency@MainActor
  #endif
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
  func send(_ action: Action) -> Task<Void, Never>? { base.send(action) }
  var canStoreCacheChildren: Bool { base.canStoreCacheChildren }
  var didSet: CurrentValueRelay<Void> { base.didSet }
  var isInvalid: Bool { state == nil || base.isInvalid }
  var effectCancellables: [UUID: AnyCancellable] { base.effectCancellables }
}
