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
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
    >
  {
    let data = store.state.value
    self.data = data
    self.content = {
      WithViewStore(store.scope(state: { $0.map { $0[keyPath: id] } })) { viewStore in
        ForEach(Array(viewStore.state.enumerated()), id: \.element) { index, _ in
          content(
            store.scope(
              state: { index < $0.endIndex ? $0[index] : data[index] },
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
      [ID], (Data.Index, EachAction), ForEach<[(offset: Int, element: ID)], ID, EachContent>
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
    Content == WithViewStore<[ID], (ID, EachAction), ForEach<[ID], ID, EachContent>>
  {
    let data = store.state.value
    self.data = data
    self.content = {
      WithViewStore(store.scope(state: { $0.ids })) { viewStore in
        ForEach(viewStore.state, id: \.self) { id in
          content(
            store.scope(
              state: { $0[id: id] ?? data[id: id]! },
              action: { (id, $0) }
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
