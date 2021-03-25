import ComposableArchitecture
import SwiftUI

private let readMe = """
This screen demonstrates how to use StateBindings and PropertyBindings to ensure that sub-states are
up-to-date with their parent state. They also provide a convenient way to specify fine-grained or coarse
deduplication if needed.

It demonstrates several use cases, like sub-states with internal properties, optional sub-states or
deduplicated sub-state setters, or operating on collections of sub-states.
"""

struct SharedStateWithBinding: Equatable, StateContainer {
  struct FeatureState: Equatable {
    var name: String = "" // Used for this case study presentation
    var isCountInternal: Bool = true // Used for this case study presentation
    var isSelected: Bool? = nil // Used for this case study presentation

    var text: String = ""
    var count: Int = 0
  }

  // This value is shared across all features.
  var content: String = "Shared Content"

  // This value is not used for cases with internal storage.
  var count: Int = 0

  // This flag is used to trigger the existence of the computed and optional `feature5`
  var shouldShowFeature5: Bool = false

  // MARK: Classical approach -
  // We create a FeatureState on the fly each time it is requested.
  // The global state needs to explicitly handle all FeatureState stored properties.
  // The setter needs to by synchronized with the getter for all readwrite properties.
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
  // A private value of FeatureState is stored.
  // This value will participate to state comparisons if any. In the binding, we only declare
  // the relevant property `text`, bound with `self.content`. The private value stores all the
  // other internal properties.
  var _feature2: FeatureState = .init()
  static let feature2 = StateBinding(\Self._feature2)
    .ro(\.feature2Name, \.name) // self.feature2Name -> feature2.name
    .rw(\.content, \.text) // self.content and feature2.text are bound in both directions.

  // Public accessor, proxying calls to the binding. The shape is always the same: One retrieves the
  // binding and call `get` with `self` to return an up-to-date value of FeatureState. In the setter,
  // we also retrieve the binding, but we call this time `set` with a pointer to `self` and `newValue`.
  // This function updates `self` accordingly.
  //
  // The following is optional, but would allow to access `self.feature2` like any property, and handle
  // its `KeyPath`. You can expose any StateBinding in a similar fashion. If you don't implement these
  // accessors, you can use dedicated store scoping and reducer pullback using the `StateBinding` directly.
  //
  //  var feature2: FeatureState {
  //    get { Self._feature2.get(self) }
  //    set { Self._feature2.set(&self, newValue) }
  //  }

  // MARK: "Optional State Binding with internal storage" -
  // A optional private value of FeatureState is stored.
  // This value will participate to state comparisons if any. In the binding, we only declare
  // the relevant property `text`, bound with `self.content`. The private value stores all
  // other internal properties. The optionality of this value conditions the optionality of the
  // publicly accessed property if one implement the accessors. Please note that we use directly
  // `PropertyBindings` of the unwrapped value.
  var _feature3: FeatureState?
  static let feature3 = StateBinding(\Self._feature3)
    .ro(\.feature3Name, \.name)
    .rw(\.content, \.text)

  // MARK: "Computed State Binding" -
  // This value doesn't have internal properties (or they stay to their default value otherwise).
  // All the properties of `FeatureStates` are bound to some properties of `self`. A new value is created
  // using the provided argument, and then configured according the bindings.
  static let feature4 = StateBinding<Self, FeatureState> { .init() }
    .ro(\.feature4Name, \.name)
    .ro(\.isCountInternal, \.isCountInternal)
    .rw(\.content, \.text)
    .rw(\.count, \.count)

  // MARK: "Optional Computed State Binding" -
  // Similar to the previous construction, but the value returned is now optional and the `FeatureState`
  // value is created from a function of `Self`. We use the `shouldShowFeature5` flag to decide if the
  // property is nil or not.
  static let feature5 = StateBinding<SharedStateWithBinding, FeatureState?> {
      $0.shouldShowFeature5
      ? .init()
      : nil
    }
    .ro(\.feature5Name, \.name)
    .ro(\.isCountInternal, \.isCountInternal)
    .rw(\.count, \.count)
    // Explicit declaration, equivalent to .rw(\.content, \.text)
    .with(
      get: { src, dest in dest.text = src.content },
      set: { src, dest in src.content = dest.text }
    )

  // MARK: "Computed State with deduplication" -
  // In this example similar to feature2, we avoid writing the private storage if the value is unchanged.
  // We also avoid to write `self.content` if it hasn't changed.
  fileprivate var _feature6: FeatureState = .init()
  // Will not update _feature6 storage if equal
  static let feature6 = StateBinding(\Self._feature6, removeDuplicateStorage: ==)
    .ro(\.feature6Name, \.name)
    .rw(\.content, \.text, removeDuplicates: ==) // Will not set `content` if equal to `text`

  // MARK: "Collection of features" -
  // In this example, we have an `IdentifiedArray` of `FeatureState` and we use `map` to transform
  // `FeatureState` bindings into `IdentifiedArrays<_,FeatureState>` bindings. This allows to
  // update each feature of the collection from `self`'s properties on the fly. Because the way
  // back is undecided (how to update `self` from the collection newValue), we specify to
  // update `self` using the element with `selectedID` as a base. This is purely optional and we
  // can return `nil` if we don't want to update `self`, rendering the binding read-only.
  let selectedID = "Id:1"
  fileprivate var _features7: IdentifiedArray<String, FeatureState> = IdentifiedArray<String, FeatureState>( [
      .init(name: "Id:1", isSelected: true),
      .init(name: "Id:2", isSelected: false),
      .init(name: "Id:3", isSelected: false)
    ], id: \.name)
  
  // Since we work on an IdentifiedArray, we need to map the binding so we can directly
  // use `FeatureState` keyPaths. We update only `Feature.text` from `self.content`. The
  // `count` in `FeatureState` states are thus internal, stored by the `_feature7` array.
  static let feature7 = StateBinding(\Self._features7)
    .map(
      .rw(\.content, \.text),
      // The feature with `SelectedID` will be used to update values in `SharedStateWithBinding`.
      // We need to return a `FeatureState` value or nil that will flow up when setting the value.
      // In other words, we will use this `FeatureState` value to extract its `\.text` value and set
      // the `\.content`. If we return `nil`, the binding would be read-only for its mapped properties.
      reduce: { $1[id: $0.selectedID] }
    )
}

// MARK: Internal
extension SharedStateWithBinding {
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
enum SharedStateWithBindingAction: Equatable {
  enum FeatureAction: Equatable {
    case binding(BindingAction<SharedStateWithBinding.FeatureState>)
  }

  case feature1(FeatureAction)
  case feature2(FeatureAction)
  case feature3(FeatureAction)
  case feature4(FeatureAction)
  case feature5(FeatureAction)
  case feature6(FeatureAction)
  case feature7(String, FeatureAction)

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

      boundFeatureReducer.pullback(binding: SharedStateWithBinding.feature2,
                                   action: /SharedStateWithBindingAction.feature2,
                                   environment: { _ in () }),

      boundFeatureReducer.optional().pullback(binding: SharedStateWithBinding.feature3,
                                              action: /SharedStateWithBindingAction.feature3,
                                              environment: { _ in () }),

      boundFeatureReducer.pullback(binding: SharedStateWithBinding.feature4,
                                   action: /SharedStateWithBindingAction.feature4,
                                   environment: { _ in () }),

      boundFeatureReducer.optional().pullback(binding: SharedStateWithBinding.feature5,
                                              action: /SharedStateWithBindingAction.feature5,
                                              environment: { _ in () }),

      boundFeatureReducer.pullback(binding: SharedStateWithBinding.feature6,
                                   action: /SharedStateWithBindingAction.feature6,
                                   environment: { _ in () }),
      
      boundFeatureReducer.forEach(binding: SharedStateWithBinding.feature7,
                                  action: /SharedStateWithBindingAction.feature7,
                                  environment: { _ in () }),

      Reducer<SharedStateWithBinding, SharedStateWithBindingAction, Void> {
        state, action, _ in
        switch action {
        case .toggleFeature3: // feature3 is an optional state with internal storage.
          if state._feature3 == nil {
            // We set up a new value of FeatureState() so its internal properties
            // can be stored by the feature itself.
            state._feature3 = .init()
          } else {
            state._feature3 = nil
          }
          return .none
        case .toggleFeature5: // feature5 is an optional computed state.
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
          FeatureView(store: self.store.scope(state: SharedStateWithBinding.feature2.get,
                                              action: SharedStateWithBindingAction.feature2))
        }

        Section(header: Text(viewStore.feature3Name),
                footer:
                Button(action: { viewStore.send(.toggleFeature3, animation: .default) }) {
                  Text(viewStore._feature3 == nil
                    ? "Install Optional Feature"
                    : "Remove Feature"
                  )
                }) {
          IfLetStore(self.store.scope(state: SharedStateWithBinding.feature3.get,
                                      action: SharedStateWithBindingAction.feature3),
                     then: FeatureView.init(store:))
        }

        Section(header: Text(viewStore.feature4Name)) {
          FeatureView(store: self.store.scope(state: SharedStateWithBinding.feature4.get,
                                              action: SharedStateWithBindingAction.feature4))
        }

        Section(header: Text(viewStore.feature5Name),
                footer:
                Button(action: { viewStore.send(.toggleFeature5, animation: .default) }) {
                  Text(!viewStore.shouldShowFeature5
                    ? "Install Optional Feature"
                    : "Remove Feature"
                  )
                }) {
          IfLetStore(self.store.scope(state: SharedStateWithBinding.feature5.get,
                                      action: SharedStateWithBindingAction.feature5),
                     then: FeatureView.init(store:))
        }

        Section(header: Text(viewStore.feature6Name)) {
          FeatureView(store: self.store.scope(state: SharedStateWithBinding.feature6.get,
                                              action: SharedStateWithBindingAction.feature6)
          )
        }

        Section(header: Text("Features array, selected: \(viewStore.selectedID)"),
                footer: Text("These three feature are stored as an array in State. Only the first one is fully responsive, with its values updating the whole app. The two other ones have an internal \"count\" value, but their textField is read-only from the state.")) {
          ForEachStore(self.store.scope(state: SharedStateWithBinding.feature7.get,
                                       action: SharedStateWithBindingAction.feature7),
                       content: FeatureView.init(store:))
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
          if viewStore.isSelected == false {
            Text("The text field is updated by the global state but it can't update it back")
              .font(.footnote)
              .foregroundColor(.orange)
              .lineLimit(nil)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .listRowBackground(
          (viewStore.isSelected == false)
            ? Color.yellow.opacity(0.1)
            : (viewStore.isSelected == true )
            ? Color.green.opacity(0.1)
            : Color.clear
        )
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
