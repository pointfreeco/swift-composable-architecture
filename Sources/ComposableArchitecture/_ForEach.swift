extension Reducer {
  public func _forEach<GlobalState, GlobalAction, GlobalEnvironment, ID>(
    state toLocalState: WritableKeyPath<GlobalState, [State]>,
    action toLocalAction: CasePath<GlobalAction, (ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    id keyPath: KeyPath<State, ID>,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where ID: Hashable {
    var lookup: [ID: Int] = [:]
    return .init { globalState, globalAction, globalEnvironment in
      guard let (id, localAction) = toLocalAction.extract(from: globalAction) else {
        return .none
      }
      let collection = globalState[keyPath: toLocalState]

      let isLookupInvalid = lookup[id] == nil
        || lookup[id]! >= collection.endIndex
        || collection[lookup[id]!][keyPath: keyPath] != id

      if isLookupInvalid {
        for (index, element) in zip(collection.indices, collection) {
          lookup[element[keyPath: keyPath]] = index
        }
      }

      let index = lookup[id]!
      return self.run(
        &globalState[keyPath: toLocalState][index],
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((id, $0)) }
    }
  }

  public func _forEach<GlobalState, GlobalAction, GlobalEnvironment>(
    state toLocalState: WritableKeyPath<GlobalState, [State]>,
    action toLocalAction: CasePath<GlobalAction, (State.ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where State: Identifiable {
    self._forEach(
      state: toLocalState,
      action: toLocalAction,
      environment: toLocalEnvironment,
      id: \.id
    )
  }
}

import SwiftUI

public struct _ForEachStore<Data, Content>: DynamicViewContent
where Data: Collection, Content: View {
  private let _data: () -> Data
  public var data: Data { _data() }
  private let content: () -> Content

  public init<ID, EachAction, EachContent>(
    _ store: Store<Data, (ID, EachAction)>,
    id: KeyPath<Data.Element, ID>,
    content: @escaping (Store<Data.Element, EachAction>) -> EachContent
  )
  where
    Data: RandomAccessCollection,
    EachContent: View,
    Content == WithViewStore<Data, (ID, EachAction), ForEach<Data, ID, EachContent>>
  {
    self._data = { store.state.value }
    self.content = {
      WithViewStore(
        store,
        removeDuplicates: {
          _, _ in false
//          $0.endIndex == $1.endIndex
//            && zip($0, $1).allSatisfy { $0[keyPath: id] == $1[keyPath: id] }
        }
      ) { viewStore in
        ForEach(viewStore.state, id: id) { element in
          content(
            store.scope(
              state: { _ in element },
              action: { (element[keyPath: id], $0) }
            )
          )
        }
      }
    }
  }

  public init<EachAction, EachContent>(
    _ store: Store<Data, (Data.Element.ID, EachAction)>,
    content: @escaping (Store<Data.Element, EachAction>) -> EachContent
  )
  where
    Data: RandomAccessCollection,
    Data.Element: Identifiable,
    EachContent: View,
    Content == WithViewStore<
      Data, (Data.Element.ID, EachAction), ForEach<Data, Data.Element.ID, EachContent>
    >
  {
    self.init(store, id: \.id, content: content)
  }

  public var body: some View {
    self.content()
  }
}
