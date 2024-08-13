#if canImport(SwiftUI)
  import SwiftUI
#endif
#if canImport(UIKit)
  import UIKit
#endif

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
      state: ConfirmationDialogState<Action>, send: @escaping (_ action: Action?) -> Void
    ) {
      fatalError()
    }

    @available(
      iOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      macOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      tvOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      watchOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
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
            handler: { _ in store.send(.dismiss) })
        )
      }
    }

    @available(
      iOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      macOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      tvOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      watchOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
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
            handler: { _ in store.send(.dismiss) })
        )
      }
    }
  }
#endif

#if canImport(SwiftUI)
  extension Binding {
    @available(
      *, deprecated,
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

// NB: Deprecated with 1.0.0:

@available(*, unavailable, renamed: "Effect")
public typealias EffectTask = Effect

@available(*, unavailable, renamed: "Reducer")
public typealias ReducerProtocol = Reducer

@available(*, unavailable, renamed: "ReducerOf")
public typealias ReducerProtocolOf<R: Reducer> = Reducer<R.State, R.Action>
