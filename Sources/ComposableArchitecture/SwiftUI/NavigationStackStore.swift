import OrderedCollections
import SwiftUI

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
public struct NavigationStackStore<State, Action, Content: View, Destination: View>: View {
  private let content: Content
  private let destination: (Component<State>) -> Destination
  @StateObject private var viewStore: ViewStore<StackState<State>, StackAction<State, Action>>

  public init(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder content: () -> Content,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
  ) {
    self.content = content()
    self.destination = { component in
      var state = component.element
      return destination(
        store.scope(
          state: {
            state = $0[id: component.id] ?? state
            return state
          },
          action: { .element(id: component.id, action: $0) }
        )
      )
    }
    self._viewStore = StateObject(
      wrappedValue: ViewStore(
        store,
        removeDuplicates: { areOrderedSetsDuplicates($0._ids, $1._ids) }
      )
    )
  }

  @_disfavoredOverload
  public init<D: View>(
    _ store: Store<StackState<State>, StackAction<State, Action>>,
    @ViewBuilder content: () -> Content,
    @ViewBuilder destination: @escaping (State) -> D
  ) where Destination == SwitchStore<State, Action, D> {
    self.content = content()
    self.destination = { component in
      var state = component.element
      return SwitchStore(
        store.scope(
          state: {
            state = $0[id: component.id] ?? state
            return state
          },
          action: { .element(id: component.id, action: $0) }
        )
      ) { _ in
        destination(component.element)
      }
    }
    self._viewStore = StateObject(
      wrappedValue: ViewStore(
        store,
        removeDuplicates: { areOrderedSetsDuplicates($0._ids, $1._ids) }
      )
    )
  }

  public var body: some View {
    NavigationStack(
      path: self.viewStore.binding(
        get: { $0.path },
        send: { newPath in
          // TODO: Tweak binding logic?
          if newPath.count > self.viewStore.path.count, let component = newPath.last {
            return .push(id: component.id, state: component.element)
          } else {
            return .popFrom(id: self.viewStore.path[newPath.count].id)
          }
        }
      )
    ) {
      self.content.navigationDestination(for: Component<State>.self) { component in
        self.destination(component)
      }
    }
  }
}

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationLink where Destination == Never {
  public init<P: Hashable>(state: P?, label: () -> Label) {
    @Dependency(\.stackElementID) var stackElementID
    self.init(value: state.map { Component(id: stackElementID(), element: $0) }, label: label)
  }

  public init<P: Hashable>(_ titleKey: LocalizedStringKey, state: P?) where Label == Text {
    @Dependency(\.stackElementID) var stackElementID
    self.init(titleKey, value: state.map { Component(id: stackElementID(), element: $0) })
  }

  @_disfavoredOverload
  public init<S: StringProtocol, P: Hashable>(_ title: S, state: P?) where Label == Text {
    @Dependency(\.stackElementID) var stackElementID
    self.init(title, value: state.map { Component(id: stackElementID(), element: $0) })
  }
}

private struct Component<Element>: Hashable {
  let id: StackElementID
  var element: Element

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

fileprivate extension StackState {
  var path: PathView {
    _read { yield PathView(base: self) }
    _modify {
      var path = PathView(base: self)
      yield &path
      self = path.base
    }
    set { self = newValue.base }
  }

  struct PathView: MutableCollection, RandomAccessCollection, RangeReplaceableCollection {
    var base: StackState

    var startIndex: Int { self.base.startIndex }
    var endIndex: Int { self.base.endIndex }
    func index(after i: Int) -> Int { self.base.index(after: i) }
    func index(before i: Int) -> Int { self.base.index(before: i) }

    subscript(position: Int) -> Component<Element> {
      _read {
        yield Component(id: self.base.ids[position], element: self.base[position])
      }
      _modify {
        let id = self.base.ids[position]
        var component = Component(id: id, element: self.base[position])
        yield &component
        self.base[id: id] = component.element
      }
      set {
        self.base[id: newValue.id] = newValue.element
      }
    }

    init(base: StackState) {
      self.base = base
    }

    init() {
      self.init(base: StackState())
    }

    mutating func replaceSubrange<C: Collection>(
      _ subrange: Range<Int>, with newElements: C
    ) where C.Element == Component<Element> {
      for id in self.base.ids[subrange] {
        self.base[id: id] = nil
      }
      for component in newElements.reversed() {
        self.base._dictionary
          .updateValue(component.element, forKey: component.id, insertingAt: subrange.lowerBound)
      }
    }
  }
}
