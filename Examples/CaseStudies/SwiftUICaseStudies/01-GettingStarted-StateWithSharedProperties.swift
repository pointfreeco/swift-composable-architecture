import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how multiple independent screens can share state in the Composable \
  Architecture. Each tab manages its own state, and could be in separate modules, but changes in \
  one tab are immediately reflected in the other.
  
  This tab has its own state, consisting of a count value that can be incremented and decremented, \
  as well as an alert value that is set when asking if the current count is prime.
  
  Internally, it is also keeping track of various stats, such as min and max counts and total \
  number of count events that occurred. Those states are viewable in the other tab, and the stats \
  can be reset from the other tab.
  """

struct StateWithSharedProperties: Equatable {
    var counter = CounterState()
    var currentTab = Tab.counter
    
    enum Tab { case counter, profile, optionalProfile }
    
    struct CounterState: Equatable {
        var count = 0
        var maxCount = 0
        var minCount = 0
        var numberOfCounts = 0
        var isOptionalProfileDisplayed = true
    }
    
    // The ProfileState can be derived from the CounterState by getting and setting the parts it cares
    // about. This allows the profile feature to operate on a subset of app state instead of the whole
    // thing.
    
    @StateToDerivedStatePropertyMapping(
        (\StateWithSharedProperties.currentTab, \ProfileState.currentTab),
        (\.counter.count, \.count),
        (\.counter.maxCount, \.maxCount),
        (\.counter.minCount, \.minCount),
        (\.counter.numberOfCounts, \.numberOfCounts),
        (\.profileTitle, \.profileTitle)
    ) var profileStateMapping
    var profile: ProfileState {
        get { profileStateMapping.derivedState(self) }
        set { profileStateMapping.mutate(&self, newValue) }
    }
    var profileTitle: String = ""

    @StateToDerivedStatePropertyMapping(
        (\StateWithSharedProperties.counter.count, \OptionalProfileState.count),
        (\.counter.numberOfCounts, \.numberOfCounts),
        (\.profileTitle, \.profileTitle)
    ) var optionalProfileStateMapping
    var optionalProfile: OptionalProfileState? {
        get {
            guard counter.isOptionalProfileDisplayed else { return nil }
            return optionalProfileStateMapping.derivedState(self)
        }
        set {
            guard let newValue = newValue else {
                counter.isOptionalProfileDisplayed = false
                return
            }
            optionalProfileStateMapping.mutate(&self, newValue)
        }
    }
}

enum StateWithSharedPropertiesAction: Equatable {
    case counter(CounterAction)
    case profile(ProfileAction)
    case optionalProfile(OptionalProfileAction)
    case selectTab(StateWithSharedProperties.Tab)
    
    enum CounterAction: Equatable {
        case decrementButtonTapped
        case incrementButtonTapped
        case toggleOptionalProfile
    }
}

struct ProfileState: Equatable, DerivedState {
    // properties of DerivedState should have no default values
    // DerivedState is always created by the state from which it is derived
    private(set) var currentTab: StateWithSharedProperties.Tab
    private(set) var count: Int
    private(set) var maxCount: Int
    private(set) var minCount: Int
    private(set) var numberOfCounts: Int
    
    var profileTitle: String
    
    init(by valueForKeyPath: [PartialKeyPath<Self> : Any]) {
        currentTab = valueForKeyPath[\.currentTab] as! StateWithSharedProperties.Tab
        count = valueForKeyPath[\.count] as! Int
        maxCount = valueForKeyPath[\.maxCount] as! Int
        minCount = valueForKeyPath[\.minCount] as! Int
        numberOfCounts = valueForKeyPath[\.numberOfCounts] as! Int
        profileTitle = valueForKeyPath[\.profileTitle] as! String
    }
    
    fileprivate mutating func resetCount() {
        self.currentTab = .counter
        self.count = 0
        self.maxCount = 0
        self.minCount = 0
        self.numberOfCounts = 0
    }
}

enum ProfileAction: Equatable {
    case resetCounterButtonTapped
    case profileTitleChanged(String)
}

struct OptionalProfileState: Equatable, DerivedState {
    private(set) var count: Int
    private(set) var numberOfCounts: Int
    
    var profileTitle: String
    
    init(by valueForKeyPath: [PartialKeyPath<Self> : Any]) {
        count = valueForKeyPath[\.count] as! Int
        numberOfCounts = valueForKeyPath[\.numberOfCounts] as! Int
        profileTitle = valueForKeyPath[\.profileTitle] as! String
    }
}

enum OptionalProfileAction: Equatable {
    case profileTitleChanged(String)
}

let stateWithSharedPropertiesCounterReducer = Reducer<
    StateWithSharedProperties.CounterState, StateWithSharedPropertiesAction.CounterAction, Void
> { state, action, _ in
    switch action {
    case .decrementButtonTapped:
        state.count -= 1
        state.numberOfCounts += 1
        state.minCount = min(state.minCount, state.count)
        return .none
        
    case .incrementButtonTapped:
        state.count += 1
        state.numberOfCounts += 1
        state.maxCount = max(state.maxCount, state.count)
        return .none
    case .toggleOptionalProfile:
        state.isOptionalProfileDisplayed.toggle()
        return .none
    }
}

let stateWithSharedPropertiesProfileReducer = Reducer<
    ProfileState, ProfileAction, Void
> { state, action, _ in
    switch action {
    case .resetCounterButtonTapped:
        state.resetCount()
        return .none
        
    case let .profileTitleChanged(text):
        state.profileTitle = text
        return .none
    }
}

let stateWithSharedPropertiesOptionalProfileReducer = Reducer<
    OptionalProfileState, OptionalProfileAction, Void
> { state, action, _ in
    switch action {
    case let .profileTitleChanged(text):
        state.profileTitle = text
        return .none
    }
}

let stateWithSharedPropertiesReducer = Reducer<StateWithSharedProperties, StateWithSharedPropertiesAction, Void>.combine(
    stateWithSharedPropertiesCounterReducer.pullback(
        state: \StateWithSharedProperties.counter,
        action: /StateWithSharedPropertiesAction.counter,
        environment: { _ in () }
    ),
    stateWithSharedPropertiesProfileReducer.pullback(
        state: \StateWithSharedProperties.profile,
        action: /StateWithSharedPropertiesAction.profile,
        environment: { _ in () }
    ),
    
    stateWithSharedPropertiesOptionalProfileReducer.optional().pullback(
        state: \StateWithSharedProperties.optionalProfile,
        action: /StateWithSharedPropertiesAction.optionalProfile,
        environment: { _ in () }
    ),
    Reducer { state, action, _ in
        switch action {
        case .counter, .profile, .optionalProfile:
            return .none
        case let .selectTab(tab):
            state.currentTab = tab
            return .none
        }
    }
)

struct StateWithSharedPropertiesView: View {
    let store: Store<StateWithSharedProperties, StateWithSharedPropertiesAction>
    
    var body: some View {
        WithViewStore(self.store.scope(state: \.currentTab)) { viewStore in
            VStack {
                Picker(
                    "Tab",
                    selection: viewStore.binding(send: StateWithSharedPropertiesAction.selectTab)
                ) {
                    Text("Counter").tag(StateWithSharedProperties.Tab.counter)
                    Text("Profile").tag(StateWithSharedProperties.Tab.profile)
                    Text("Optional profile").tag(StateWithSharedProperties.Tab.optionalProfile)
                }
                .pickerStyle(.segmented)
                
                if viewStore.state == .counter {
                    StateWithSharedPropertiesCounterView(
                        store: self.store.scope(state: \.counter, action: StateWithSharedPropertiesAction.counter))
                }
                
                if viewStore.state == .profile {
                    StateWithSharedPropertiesProfileView(
                        store: self.store.scope(state: \.profile, action: StateWithSharedPropertiesAction.profile))
                }
                
                if viewStore.state == .optionalProfile {
                    IfLetStore(
                        self.store.scope(
                            state: \.optionalProfile,
                            action: StateWithSharedPropertiesAction.optionalProfile
                        ),
                        then: { store in
                            StateWithSharedPropertiesOptionalProfileView(store: store)
                        },
                        else: {
                            Text(template: "`OptionalProfile` is `nil`", .body)
                        }
                    )
                }
                
                Spacer()
            }
        }
        .padding()
    }
}

struct StateWithSharedPropertiesCounterView: View {
    let store: Store<StateWithSharedProperties.CounterState, StateWithSharedPropertiesAction.CounterAction>
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack(spacing: 64) {
                Text(template: readMe, .caption)
                
                VStack(spacing: 16) {
                    HStack {
                        Button("−") { viewStore.send(.decrementButtonTapped) }
                        
                        Text("\(viewStore.count)")
                            .font(.body.monospacedDigit())
                        
                        Button("+") { viewStore.send(.incrementButtonTapped) }
                    }
                    
                    Button("Toggle optional profile") { viewStore.send(.toggleOptionalProfile) }
                }
            }
            .padding(16)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            .navigationBarTitle("Shared State Demo")
        }
    }
}

struct StateWithSharedPropertiesProfileView: View {
    let store: Store<ProfileState, ProfileAction>
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack(spacing: 64) {
                Text(
                    template: """
            This tab shows state from the previous tab, and it is capable of reseting all of the \
            state back to 0.
            
            This shows that it is possible for each screen to model its state in the way that makes \
            the most sense for it, while still allowing the state and mutations to be shared \
            across independent screens.
            """,
                    .caption
                )
                
                TextField(
                    "Profile title",
                    text: viewStore.binding(get: \.profileTitle, send: ProfileAction.profileTitleChanged)
                )
                
                VStack(spacing: 16) {
                    Text("Current count: \(viewStore.count)")
                    Text("Max count: \(viewStore.maxCount)")
                    Text("Min count: \(viewStore.minCount)")
                    Text("Total number of count events: \(viewStore.numberOfCounts)")
                    Button("Reset") { viewStore.send(.resetCounterButtonTapped) }
                }
            }
            .padding(16)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            .navigationBarTitle("Profile")
        }
    }
}

struct StateWithSharedPropertiesOptionalProfileView: View {
    let store: Store<OptionalProfileState, OptionalProfileAction>
    
    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack(spacing: 64) {
                Text(
                    template: """
            This tab shows state from the previous tab, and it is capable of reseting all of the \
            state back to 0.
            
            This shows that it is possible for each screen to model its state in the way that makes \
            the most sense for it, while still allowing the state and mutations to be shared \
            across independent screens.
            """,
                    .caption
                )
                
                TextField(
                    "Profile title",
                    text: viewStore.binding(get: \.profileTitle, send: OptionalProfileAction.profileTitleChanged)
                )
                
                VStack(spacing: 16) {
                    Text("Current count: \(viewStore.count)")
                    Text("Total number of count events: \(viewStore.numberOfCounts)")
                }
            }
            .padding(16)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
            .navigationBarTitle("Optional Profile")
        }
    }
}

// MARK: - SwiftUI previews

struct StateWithSharedProperties_Previews: PreviewProvider {
    static var previews: some View {
        StateWithSharedPropertiesView(
            store: Store(
                initialState: StateWithSharedProperties(),
                reducer: stateWithSharedPropertiesReducer,
                environment: ()
            )
        )
    }
}
