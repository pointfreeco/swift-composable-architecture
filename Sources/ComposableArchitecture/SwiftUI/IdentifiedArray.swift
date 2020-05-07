import Foundation

/// An array of elements that can be identified by a given key path.
///
/// A useful container of state that is intended to interface with `SwiftUI.ForEach`. For example,
/// your application may model a counter in an identifiable fashion:
///
///     struct CounterState: Identifiable {
///       let id: UUID
///       var count = 0
///     }
///     enum CounterAction { case incr, decr }
///     let counterReducer = Reducer<CounterState, CounterAction, Void> { ... }
///
/// This domain can be pulled back to a larger domain with the `forEach` method:
///
///     struct AppState { var counters = IdentifiedArray<Int>(id: \.self) }
///     enum AppAction { case counter(id: UUID, action: CounterAction) }
///     let appReducer = counterReducer.forEach(
///       state: \AppState.counters,
///       action: /AppAction.counter(id:action:),
///       environment: { $0 }
///     )
///
/// And then SwiftUI can work with this array of identified elements in a list view:
///
///     struct AppView: View {
///       let store: Store<AppState, AppAction>
///
///       var body: some View {
///         List {
///           ForEachStore(
///             self.store.scope(state: \.counters, action: AppAction.counter(id:action))
///             content: CounterView.init(store:)
///           )
///         }
///       }
///     }
public struct IdentifiedArray<ID, Element>: MutableCollection, RandomAccessCollection
where ID: Hashable {
  /// A key path to a value that identifies an element.
  public let id: KeyPath<Element, ID>

  /// A raw array of each element's identifier.
  public private(set) var ids: [ID]

  /// A raw array of the underlying elements.
  public var elements: [Element] { Array(self) }

  // TODO: Support multiple elements with the same identifier but different data
  private var dictionary: [ID: Element]

  /// Initializes an identified array with a sequence of elements and a key
  /// path to an element's identifier.
  ///
  /// - Parameters:
  ///   - elements: A sequence of elements.
  ///   - id: A key path to a value that identifies an element.
  public init<S>(_ elements: S, id: KeyPath<Element, ID>) where S: Sequence, S.Element == Element {
    self.id = id

    let idsAndElements = elements.map { (id: $0[keyPath: id], element: $0) }
    self.ids = idsAndElements.map { $0.id }
    self.dictionary = Dictionary(idsAndElements, uniquingKeysWith: { $1 })
  }

  /// Initializes an empty identified array with a key path to an element's
  /// identifier.
  ///
  /// - Parameter id: A key path to a value that identifies an element.
  public init(id: KeyPath<Element, ID>) {
    self.init([], id: id)
  }

  public var startIndex: Int { self.ids.startIndex }
  public var endIndex: Int { self.ids.endIndex }

  public func index(after i: Int) -> Int {
    self.ids.index(after: i)
  }

  public func index(before i: Int) -> Int {
    self.ids.index(before: i)
  }

  public subscript(position: Int) -> Element {
    get {
      self.dictionary[self.ids[position]]!
    }
    _modify {
      yield &self.dictionary[self.ids[position]]!
    }
  }

  public subscript(id id: ID) -> Element? {
    get {
      self.dictionary[id]
    }
    set {
      self.dictionary[id] = newValue
      if newValue == nil {
        self.ids.removeAll(where: { $0 == id })
      }
    }
  }

  public mutating func insert(_ newElement: Element, at i: Int) {
    let id = newElement[keyPath: self.id]
    self.dictionary[id] = newElement
    self.ids.insert(id, at: i)
  }

  public mutating func insert<C>(
    contentsOf newElements: C, at i: Int
  ) where C: Collection, Element == C.Element {
    for newElement in newElements.reversed() {
      self.insert(newElement, at: i)
    }
  }

  @discardableResult
  public mutating func remove(at position: Int) -> Element {
    let id = self.ids.remove(at: position)
    let element = self.dictionary[id]!
    if !self.ids.contains(id) {
      self.dictionary[id] = nil
    }
    return element
  }

  public mutating func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
    var ids: [ID] = []
    for (index, id) in zip(self.ids.indices, self.ids).reversed() {
      if try shouldBeRemoved(self.dictionary[id]!) {
        self.ids.remove(at: index)
        ids.append(id)
      }
    }
    for id in ids where !self.ids.contains(id) {
      self.dictionary[id] = nil
    }
  }

  public mutating func remove(atOffsets offsets: IndexSet) {
    for offset in offsets.reversed() {
      _ = self.remove(at: offset)
    }
  }

  public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    self.ids.move(fromOffsets: source, toOffset: destination)
  }
}

extension IdentifiedArray: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.elements.debugDescription
  }
}

extension IdentifiedArray: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.elements)
  }
}

extension IdentifiedArray: CustomStringConvertible {
  public var description: String {
    self.elements.description
  }
}

extension IdentifiedArray: Decodable where Element: Decodable & Identifiable, ID == Element.ID {
  public init(from decoder: Decoder) throws {
    self.init(try [Element](from: decoder))
  }
}

extension IdentifiedArray: Encodable where Element: Encodable {
  public func encode(to encoder: Encoder) throws {
    try self.elements.encode(to: encoder)
  }
}

extension IdentifiedArray: Equatable where Element: Equatable {}

extension IdentifiedArray: Hashable where Element: Hashable {}

extension IdentifiedArray: ExpressibleByArrayLiteral where Element: Identifiable, ID == Element.ID {
  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }
}

extension IdentifiedArray where Element: Identifiable, ID == Element.ID {
  public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
    self.init(elements, id: \.id)
  }
}

extension IdentifiedArray: RangeReplaceableCollection
where Element: Identifiable, ID == Element.ID {
  public init() {
    self.init([], id: \.id)
  }
}

/// A convenience type to specify an `IdentifiedArray` by an identifiable element.
public typealias IdentifiedArrayOf<Element> = IdentifiedArray<Element.ID, Element>
where Element: Identifiable
