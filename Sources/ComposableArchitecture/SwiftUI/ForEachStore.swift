import SwiftUI

/// A structure that computes views on demand from a store on a collection of data.
public struct ForEachStore<EachState, EachAction, Data, ID, Content>: DynamicViewContent
where Data: Collection, ID: Hashable, Content: View {
  public let data: Data
  private let content: () -> Content

  /// Initializes a structure that computes views on demand from a store on an array of data and an
  /// indexed action.
  ///
  /// - Parameters:
  ///   - store: A store on an array of data and an indexed action.
  ///   - id: A key path identifying an element.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    id: KeyPath<EachState, ID>,
    content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    EachContent: View,
    Content == WithViewStore<
      Data, (Data.Index, EachAction),
      ForEach<ContiguousArray<(Data.Index, EachState)>, ID, EachContent>
    >
  {
    self.data = ViewStore(store, removeDuplicates: { _, _ in false }).state
    self.content = {
      WithViewStore(
        store,
        removeDuplicates: { lhs, rhs in
          guard lhs.count == rhs.count else { return false }
          return zip(lhs, rhs).allSatisfy { $0[keyPath: id] == $1[keyPath: id] }
        }
      ) { viewStore in
        ForEach(
          ContiguousArray(zip(viewStore.indices, viewStore.state)),
          id: (\(Data.Index, EachState).1).appending(path: id)
        ) { index, element in
          content(
            store.scope(
              state: { index < $0.endIndex ? $0[index] : element },
              action: { (index, $0) }
            )
          )
        }
      }
    }
  }

  /// Initializes a structure that computes views on demand from a store on an array of data and an
  /// indexed action.
  ///
  /// - Parameters:
  ///   - store: A store on an array of data and an indexed action.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent>(
    _ store: Store<Data, (Data.Index, EachAction)>,
    content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    Data == [EachState],
    EachContent: View,
    Content == WithViewStore<
      Data, (Data.Index, EachAction),
      ForEach<ContiguousArray<(Data.Index, EachState)>, ID, EachContent>
    >,
    EachState: Identifiable,
    EachState.ID == ID
  {
    self.init(store, id: \.id, content: content)
  }

  /// Initializes a structure that computes views on demand from a store on a collection of data and
  /// an identified action.
  ///
  /// - Parameters:
  ///   - store: A store on an identified array of data and an identified action.
  ///   - content: A function that can generate content given a store of an element.
  public init<EachContent: View>(
    _ store: Store<IdentifiedArray<ID, EachState>, (ID, EachAction)>,
    content: @escaping (Store<EachState, EachAction>) -> EachContent
  )
  where
    EachContent: View,
    Data == IdentifiedArray<ID, EachState>,
    Content == WithViewStore<
      IdentifiedArray<ID, EachState>, (ID, EachAction),
      ForEach<IdentifiedArray<ID, EachState>, ID, EachContent>
    >
  {

    self.data = ViewStore(store, removeDuplicates: { _, _ in false }).state
    self.content = {
      WithViewStore(
        store,
        removeDuplicates: { lhs, rhs in
          guard lhs.id == rhs.id else { return false }
          guard lhs.count == rhs.count else { return false }
          return zip(lhs, rhs).allSatisfy { $0[keyPath: lhs.id] == $1[keyPath: rhs.id] }
        }
      ) { viewStore in
        ForEach(viewStore.state, id: viewStore.id) { element in
          content(
            store.scope(
              state: { $0[id: element[keyPath: viewStore.id]] ?? element },
              action: { (element[keyPath: viewStore.id], $0) }
            )
          )
        }
      }
    }
  }

  public var body: some View {
    self.content()
  }
}
