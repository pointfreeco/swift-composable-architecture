import ComposableArchitecture
import SwiftUI

struct User: Equatable {
  var name = ""
  var isAdmin = false
}

struct FormState: Equatable {
  var user: User
}

struct AnyEquatable: Equatable {
  let isEqualTo: (Any) -> Bool
  let rawValue: Any

  init<Value: Equatable>(_ value: Value) {
    self.isEqualTo = { value == $0 as? Value }
    self.rawValue = value
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.isEqualTo(rhs.rawValue)
  }
}

enum FormAction: Equatable {
  case _update(
        keyPath: PartialKeyPath<FormState>,
        value: AnyEquatable,
        setter: (_ root: inout Any, _ value: AnyEquatable) -> Void
       )

  static func update<Value>(
    keyPath: WritableKeyPath<FormState, Value>,
    value: Value
  ) -> Self
  where Value: Equatable
  {
    ._update(
      keyPath: keyPath,
      value: AnyEquatable(value),
      setter: { root, value in
        var copy = root as! FormState
        copy[keyPath: keyPath] = value.rawValue as! Value
        root = copy
      }
    )
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (._update(lhsKeyPath, lhsValue, _), ._update(rhsKeyPath, rhsValue, _)):
      return lhsKeyPath == rhsKeyPath && lhsValue == rhsValue
    }
  }
}

typealias FormEnvironment = Void

let formReducer = Reducer<FormState, FormAction, FormEnvironment> { state, action, environment in
  switch action {
  case let ._update(keyPath: keyPath, value: value, setter):
    var s: Any = state
    setter(&s, value)
    state = s as! FormState
    return .none
  }
}

extension ViewStore where State == FormState, Action == FormAction {
  func binding<Value>(
    _ keyPath: WritableKeyPath<State, Value>
  ) -> Binding<Value>
  where Value: Equatable {
    return self.binding(
      get: { $0[keyPath: keyPath] },
      send: { .update(keyPath: keyPath, value: $0) }
    )
  }
}

struct FormView: View {
  let store: Store<FormState, FormAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text("Name")) {
          TextField("Blob", text: viewStore.binding(\.user.name))
          Text("(Backwards:) ")
            + Text(String(viewStore.user.name.reversed()))
            .foregroundColor(viewStore.user.isAdmin ? .red : .black)
        }

        Section(header: Text("Permissions")) {
          Toggle("Is Admin", isOn: viewStore.binding(\.user.isAdmin))
        }
      }
    }
  }
}

struct FormView_Previews: PreviewProvider {
  static var previews: some View {
    FormView(
      store: Store(
        initialState: .init(user: .init()),
        reducer: formReducer,
        environment: ()
      )
    )
  }
}
