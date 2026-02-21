#if canImport(SwiftUI)
  import SwiftUI
#endif
#if canImport(UIKit)
  import UIKit
#endif

// NB: Deprecated with 1.23.1:

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
    await self.receive(
      actionCase,
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
    await self.receive(
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
      iOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      macOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      tvOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      watchOS,
      deprecated: 9999,
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
      iOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      macOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      tvOS,
      deprecated: 9999,
      message:
        "Use '@ObservableState' and the 'scope' operation on bindable stores. See the following migration guide for more information: https://swiftpackageindex.com/pointfreeco/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.13"
    )
    @available(
      watchOS,
      deprecated: 9999,
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

// NB: Deprecated with 1.0.0:

@available(*, unavailable, renamed: "Effect")
public typealias EffectTask = Effect

@available(*, unavailable, renamed: "Reducer")
public typealias ReducerProtocol = Reducer

@available(*, unavailable, renamed: "ReducerOf")
public typealias ReducerProtocolOf<R: Reducer> = Reducer<R.State, R.Action>
