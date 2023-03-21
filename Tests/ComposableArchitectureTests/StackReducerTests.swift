import ComposableArchitecture
import XCTest

import OrderedCollections

//@propertyWrapper
//public struct _StackState<
//  Stack: Collection
//    & BidirectionalCollection
//    & MutableCollection
//    & RandomAccessCollection
//    & RangeReplaceableCollection
//>:
//  Collection,
//  BidirectionalCollection,
//  MutableCollection,
//  RandomAccessCollection,
//  RangeReplaceableCollection
//{
//  var _ids: OrderedSet<AnyHashable>
//  var _elements: Stack
//
//  public var wrappedValue: Stack {
//    _read { yield self._elements }
//    _modify { yield &self._elements}
//  }
//
//  public init(wrappedValue: Stack) {
//    self.init(wrappedValue)
//  }
//
//  public var projectedValue: Self {
//    _read { yield self }
//    _modify { yield &self }
//  }
//
//  public typealias Element = Stack.Element
//  public typealias Index = Stack.Index
//
//  public var startIndex: Index { self._elements.startIndex }
//  public var endIndex: Index { self._elements.endIndex }
//  public func index(after i: Index) -> Index { self._elements.index(after: i) }
//  public func index(before i: Index) -> Index { self._elements.index(before: i) }
//
//  public subscript(position: Index) -> Element {
//    _read { yield self._elements[position] }
//    _modify { yield &self._elements[position] }
//  }
//
//  public init() {
//    self._ids = []
//    self._elements = Stack()
//  }
//
//  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C)
//  where Stack.Element == C.Element {
//    @Dependency(\.uuid) var uuid
//    self._elements.replaceSubrange(subrange, with: newElements)
//    let idSubrange =
//      self._elements.distance(from: self._elements.startIndex, to: subrange.lowerBound)
//      ..<
//      self._elements.distance(from: self._elements.startIndex, to: subrange.upperBound)
//    self._ids.removeSubrange(idSubrange)
//    for _ in newElements {
//      self._ids.insert(uuid(), at: idSubrange.startIndex)
//    }
//  }
//}
//
//extension _StackState: Equatable where Stack: Equatable {}
//extension _StackState: Hashable where Stack: Hashable {}

@propertyWrapper
public struct _StackState<Element>:
  Collection,
  BidirectionalCollection,
  MutableCollection,
  RandomAccessCollection,
  RangeReplaceableCollection
{
  var _ids: OrderedSet<AnyHashable>
  var _elements: [AnyHashable: Element]

  public var wrappedValue: [Element] {
    _read { yield Array(self._elements.values) }
    _modify {

      yield &self._elements
    }
  }

  public init(wrappedValue: Stack) {
    self.init(wrappedValue)
  }

  public var projectedValue: Self {
    _read { yield self }
    _modify { yield &self }
  }

  public typealias Element = Stack.Element
  public typealias Index = Stack.Index

  public var startIndex: Index { self._elements.startIndex }
  public var endIndex: Index { self._elements.endIndex }
  public func index(after i: Index) -> Index { self._elements.index(after: i) }
  public func index(before i: Index) -> Index { self._elements.index(before: i) }

  public subscript(position: Index) -> Element {
    _read { yield self._elements[position] }
    _modify { yield &self._elements[position] }
  }

  public init() {
    self._ids = []
    self._elements = Stack()
  }

  public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C)
  where Stack.Element == C.Element {
    @Dependency(\.uuid) var uuid
    self._elements.replaceSubrange(subrange, with: newElements)
    let idSubrange =
      self._elements.distance(from: self._elements.startIndex, to: subrange.lowerBound)
      ..<
      self._elements.distance(from: self._elements.startIndex, to: subrange.upperBound)
    self._ids.removeSubrange(idSubrange)
    for _ in newElements {
      self._ids.insert(uuid(), at: idSubrange.startIndex)
    }
  }
}

extension _StackState: Equatable where Stack: Equatable {}
extension _StackState: Hashable where Stack: Hashable {}
final class StackReducerTests: XCTestCase {
  func testStackState() {
    withDependencies {
      $0.uuid = .incrementing
    } operation: {
      @_StackState var xs = [1, 2, 3]

      XCTAssertEqual(
        $xs._ids, [
          UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        ]
      )

      xs.swapAt(0, 2)
      XCTAssertEqual(
        $xs._ids, [
          UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        ]
      )
    }
  }

  func testPresent() {
//    struct Child: ReducerProtocol {
//      struct State: Equatable {
//        var count = 0
//      }
//      enum Action: Equatable {
//        case decrementButtonTapped
//        case incrementButtonTapped
//      }
//      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
//        switch action {
//        case .decrementButtonTapped:
//          state.count -= 1
//          return .none
//        case .incrementButtonTapped:
//          state.count += 1
//          return .none
//        }
//      }
//    }
//    struct Container: ReducerProtocol {

//    @Indirect var child: Child?

    // .ifLet(\.child, action: Child.Action) {}   Optional<State>
    // .ifLet(\.$child, action: PresentationAction<Child.Action>) {}
    // .ifLet(\.$alert)
    //
    // vs.
    //
    // .ifLet(\.child, action: Child.Action) {}   Optional<State>
    // .ifLet(\.child, action: PresentationAction<Child.Action>) {}  // @PresentationState or Optional
    // .ifLet(\.alert)

    // PresentationState (~~Optional~~Required to use) | PresentationAction (Required to use)
    // StackState (Required to use)        | StackAction (Required to use)


    // .forEach(\.children) {}   Array<State>
    // .forEach(\.$children) {}
    // .forEach(\.$toasts)
    //
    // vs.
    //
    // .forEach(\.children) {}   IdentifiedArray<State>
    // .forEach(\.children) {}   IdentifiedArray<State> // @_spi(SwiftUI) var ids: [ID] { get set }
    // .forEach(\.toasts)
    //

    // PresentationState (Optional to use) | PresentationAction (Required to use)
    // StackState (Required to use)        | StackAction (Required to use)

//      struct State: Equatable {
//        @StackState<Child> var stack
//        var stack: StackState<Child> = []
//
//        @_StackState var stack: [Child] = []
//      }
//    }


    // .ifLet(\.child, action: Child.Action) {}
    // .ifLet(\.$child, action: PresentationAction<Child.Action>) {}
    // .ifLet(\.$alert)
    // .forEach(\.children) {}   Array<State>
    // .forEach(\.children) {}
    // .forEach(\.toasts)
  }
}
