import ComposableArchitecture
import SwiftUI

private let readMe = """
This screen demonstrates how to use StateBindings and PropertyBinding to ensure that sub-states are
up-to-date with their parent state. They also provide a convenient way to specify fine-grained or coarse
deduplication if needed.

It demonstrates several use cases, like sub-states with internal properties, optional sub-states or
deduplicated sub-state setters.
"""

struct SharedStateWithBinding: Equatable {
  struct FeatureState: Equatable {
    var name: String = "" // Used for this case study presentation
    var isCountInternal: Bool = true // Used for this case study presentation

    var text: String = ""
    var count: Int = 0
  }

  // This value is shared across all features.
  var content: String = "Shared Content"

  // This value is not used for cases with internal storage
  var count: Int = 0

  // This flag is used to trigger the existence of the computed and optional `feature5`
  var shouldShowFeature5: Bool = false

  // MARK: Classical approach -
  // We create a FeatureState on the fly each time it is requested.
  // The global state needs to explicitly handle all FeatureState stored properties.
  // The setter need to by synchronized with the getter for all readwrite properties.
  var feature1: FeatureState {
    get { FeatureState(name: feature1Name, // Read only
                       isCountInternal: false, // Read only
                       text: content,
                       count: count)
    }
    set {
      self.content = newValue.text
      self.count = newValue.count
    }
  }

  // MARK: State Binding with internal storage -
  // A private instance of FeatureState is stored.
  // This instance will participate to state comparisons if any. In the binding, we only declare
  // the relevant property `name`, bound with `self.content`. The private instance stores all the
  // other internal properties.
  private var _feature2: FeatureState = .init()
  private static let _feature2 = StateBinding(\Self._feature2)
    .ro(\.feature2Name, \.name) // self.feature2Name -> feature2.name
    .rw(\.content, \.text) // self.content and feature2.text are bound in both directions.

  // Public accessor, proxying calls to the binding. The shape is always the same: One retrieves the
  // binding and call `get` with `self` to return an up-to-date value of FeatureState. In the setter,
  // we also retrieve the binding, but we call this time `set` with a pointer to `self` and `newValue`.
  // This function updates `self` accordingly.
  var feature2: FeatureState {
    get { Self._feature2.get(self) }
    set { Self._feature2.set(&self, newValue) }
  }

  // MARK: "Optional State Binding with internal storage" -
  // A optional private instance of FeatureState is stored.
  // This instance will participate to state comparisons if any. In the binding, we only declare
  // the relevant property `name`, bound with `self.content`. The private instance stores all the
  // other internal properties. The optionality of this value condition the optionality of the
  // publicly accessed property. Please note that the `PropertyBindings` a defined between unwrapped
  // values.
  fileprivate var _feature3: FeatureState?
  fileprivate static let _feature3 = StateBinding(\Self._feature3)
    .ro(\.feature2Name, \.name)
    .rw(\.content, \.text)

  /// Public accessor, same shape as `feature2`, but optional.
  var feature3: FeatureState? {
    get { Self._feature3.get(self) }
    set { Self._feature3.set(&self, newValue) }
  }

  // MARK: "Computed State Binding" -
  // This instance doesn't have internal properties (or they stay to their default value otherwise)
  // All the properties of `Feature` are bound to some property of `self`. A new instance is created
  // from the provided `with:` argument. We use `Self.self` because we need to tie the first generic
  // parameter of `StateBinding` to `Self`.
  fileprivate static let _feature4 = StateBinding(Self.self, with: FeatureState.init)
    .ro(\.feature4Name, \.name)
    .ro(\.isCountInternal, \.isCountInternal)
    .rw(\.content, \.text)
    .rw(\.count, \.count)

  var feature4: FeatureState {
    get { Self._feature4.get(self) }
    set { Self._feature4.set(&self, newValue) }
  }

  // MARK: "Optional Computed State Binding" -
  // Similar to the previous construction, but the value returned is now optional and is the `Feature`
  // instance is created from a function of `Self`. We use the `shouldShowFeature5` flag to decide if the
  // property is nil or not. Because it has no private storage, the `feature5` instance is completly set
  // when accessed and the flag is enough to condition its existence and content without ambiguity.
  fileprivate static let _feature5 = StateBinding<SharedStateWithBinding, FeatureState?>(with: { $0.shouldShowFeature5 ? .init() : nil })
    .ro(\.feature5Name, \.name)
    .ro(\.isCountInternal, \.isCountInternal)
    .rw(\.count, \.count)
    // Explicit declaration, equivalent to .rw(\.content, \.text)
    .with(
      .init(
        get: { src, dest in dest.text = src.content },
        set: { src, dest in src.content = dest.text }
      )
    )

  var feature5: FeatureState? {
    get { Self._feature5.get(self) }
    set { Self._feature5.set(&self, newValue) }
  }

  // MARK: "Computed State with deduplication" -
  // In this example similar to feature2, we avoid writing the private storage if the value is unchanged.
  // We also avoid to write `self.content` if it hasn't changed.
  fileprivate var _feature6: FeatureState = .init()
  // Will not update _feature6 if equal
  fileprivate static let _feature6 = StateBinding(\Self._feature6, removeDuplicateStorage: ==)
    .ro(\.feature6Name, \.name)
    .rw(\.content, \.text, removeDuplicates: ==) // Will not set `content` if equal to `text`

  var feature6: FeatureState {
    get { Self._feature6.get(self) }
    set { Self._feature6.set(&self, newValue) }
  }
}

// MARK: Internal

private extension SharedStateWithBinding {
  // Used for this case study presentation
  var feature1Name: String { "Manual binding" }
  var feature2Name: String { "State Binding with internal storage" }
  var feature3Name: String { "Optional State Binding with internal storage" }
  var feature4Name: String { "Computed State Binding" }
  var feature5Name: String { "Optional Computed State Binding" }
  var feature6Name: String { "Computed State with deduplication" }
  var isCountInternal: Bool { false }
}

// MARK: - Actions
enum SharedStateWithBindingAction {
  enum FeatureAction {
    case binding(BindingAction<SharedStateWithBinding.FeatureState>)
  }

  case feature1(FeatureAction)
  case feature2(FeatureAction)
  case feature3(FeatureAction)
  case feature4(FeatureAction)
  case feature5(FeatureAction)
  case feature6(FeatureAction)

  case toggleFeature3
  case toggleFeature5
}

// MARK: - Reducers
let boundFeatureReducer =
  Reducer<SharedStateWithBinding.FeatureState, SharedStateWithBindingAction.FeatureAction, Void>
    .empty
    .binding(action: /SharedStateWithBindingAction.FeatureAction.binding)

let sharedStateWithBindingReducer =
  Reducer<SharedStateWithBinding, SharedStateWithBindingAction, Void>
    .combine(
      boundFeatureReducer.pullback(state: \.feature1,
                                   action: /SharedStateWithBindingAction.feature1,
                                   environment: { _ in () }),

      boundFeatureReducer.pullback(state: \.feature2,
                                   action: /SharedStateWithBindingAction.feature2,
                                   environment: { _ in () }),

      boundFeatureReducer.optional().pullback(state: \.feature3,
                                              action: /SharedStateWithBindingAction.feature3,
                                              environment: { _ in () }),

      boundFeatureReducer.pullback(state: \.feature4,
                                   action: /SharedStateWithBindingAction.feature4,
                                   environment: { _ in () }),

      boundFeatureReducer.optional().pullback(state: \.feature5,
                                              action: /SharedStateWithBindingAction.feature5,
                                              environment: { _ in () }),

      boundFeatureReducer.pullback(state: \.feature6,
                                   action: /SharedStateWithBindingAction.feature6,
                                   environment: { _ in () }),

      Reducer<SharedStateWithBinding, SharedStateWithBindingAction, Void> {
        state, action, _ in
        switch action {
        case .toggleFeature3: // feature3 is a optional state with internal storage.
          if state._feature3 == nil {
            // We set up a new instance of FeatureState() so its internal properties
            // can be stored by the feature itself.
            state._feature3 = .init()
          } else {
            state._feature3 = nil
          }
          return .none
        case .toggleFeature5: // feature5 is a optional computed state.
          state.shouldShowFeature5.toggle()
          return .none
        default: return .none
        }
      }
    )

// MARK: - View
struct SharedStateWithBindingView: View {
  let store: Store<SharedStateWithBinding, SharedStateWithBindingAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      List {
        Section(header: Text(viewStore.feature1Name)) {
          FeatureView(store: self.store.scope(state: { $0.feature1 },
                                              action: SharedStateWithBindingAction.feature1))
        }

        Section(header: Text(viewStore.feature2Name)) {
          FeatureView(store: self.store.scope(state: { $0.feature2 },
                                              action: SharedStateWithBindingAction.feature2))
        }

        Section(header: Text(viewStore.feature3Name),
                footer:
                Button(action: { viewStore.send(.toggleFeature3, animation: .default) }) {
                  Text(viewStore.feature3 == nil
                    ? "Install Optional Feature"
                    : "Remove Feature"
                  )
                }) {
          IfLetStore(self.store.scope(state: { $0.feature3 },
                                      action: SharedStateWithBindingAction.feature3),
                     then: FeatureView.init(store:))
        }

        Section(header: Text(viewStore.feature4Name)) {
          FeatureView(store: self.store.scope(state: { $0.feature4 },
                                              action: SharedStateWithBindingAction.feature4))
        }

        Section(header: Text(viewStore.feature5Name),
                footer:
                Button(action: { viewStore.send(.toggleFeature5, animation: .default) }) {
                  Text(viewStore.feature5 == nil
                    ? "Install Optional Feature"
                    : "Remove Feature"
                  )
                }) {
          IfLetStore(self.store.scope(state: { $0.feature5 },
                                      action: SharedStateWithBindingAction.feature5),
                     then: FeatureView.init(store:))
        }

        Section(header: Text(viewStore.feature6Name)) {
          FeatureView(store: self.store.scope(state: { $0.feature6 },
                                              action: SharedStateWithBindingAction.feature6)
          )
        }
      }
    }
    .listStyle(GroupedListStyle())
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  struct FeatureView: View {
    typealias FeatureState = SharedStateWithBinding.FeatureState
    typealias FeatureAction = SharedStateWithBindingAction.FeatureAction
    let store: Store<FeatureState, FeatureAction>
    var body: some View {
      WithViewStore(store) { viewStore in
        VStack {
          HStack {
            TextField(viewStore.name,
                      text: viewStore.binding(keyPath: \.text, send: FeatureAction.binding))
              .textFieldStyle(RoundedBorderTextFieldStyle())

            Stepper("\(viewStore.count)",
                    value: viewStore.binding(keyPath: \.count, send: FeatureAction.binding),
                    in: 0 ... 9)
              .font(Font.system(.body).monospacedDigit())
              .foregroundColor(viewStore.isCountInternal ? .red : .green)
              .fixedSize()
          }
          Text("\"count\" value is \(viewStore.isCountInternal ? "internal" : "global")")
            .font(.footnote)
            .foregroundColor(viewStore.isCountInternal ? .red : .green)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .id(viewStore.name)
        .listRowInsets(EdgeInsets(top: 11, leading: 8, bottom: 8, trailing: 8))
      }
    }
  }
}

// MARK: - Preview
struct SharedStateWithBindingView_Previews: PreviewProvider {
  static var previews: some View {
    SharedStateWithBindingView(store: .init(initialState: .init(),
                                            reducer: sharedStateWithBindingReducer,
                                            environment: ()))
  }
}
