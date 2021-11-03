import Combine
import ComposableArchitecture
import XCTest

class ARCTestStoreTests: XCTestCase {
    struct State: Equatable {
        var name: String = "Krzysztof"
        var surname: String = "Zabłocki"
        var age: Int = 33
        var mood: Int = 0
    }
    
    enum Action: Equatable {
        case changeIdentity(name: String, surname: String)
        case changeAge(Int)
        case changeMood(Int)
        case advanceAgeAfterDelay
    }
    
    let reducer = Reducer<State, Action, AnySchedulerOf<DispatchQueue>> { state, action, scheduler in
        switch action {
        case let .changeIdentity(name, surname):
            state.name = name
            state.surname = surname
            return .none
            
        case .advanceAgeAfterDelay:
            return .merge(
                .init(value: .changeAge(state.age + 1)),
                .init(value: .changeMood(state.mood + 1))
            )
                .delay(for: 1, scheduler: scheduler)
                .eraseToEffect()
            
        case let .changeAge(age):
            state.age = age
            return .none
        case let .changeMood(mood):
            state.mood = mood
            return .none
        }
    }
    
    func test_verify_state_changes_without_exhaustivity() {
        let testScheduler = DispatchQueue.test
        let store = ARCTestStore(
            initialState: State(),
            reducer: reducer,
            environment: testScheduler.eraseToAnyScheduler()
        )
        
        // When changing multiple properties, can choose to assert only the ones one is interested in
        store.send(.changeIdentity(name: "Marek", surname: "Ignored")) {
            $0.name = "Marek"
        }
    }
    
    func test_verify_state_changes_once_after_many_actions_were_processed() {
        let testScheduler = DispatchQueue.test
        let store = ARCTestStore(
            initialState: State(),
            reducer: reducer,
            environment: testScheduler.eraseToAnyScheduler()
        )
        
        // When sending multiple actions
        store.send(.changeIdentity(name: "Adam", surname: "Stern"))
        store.send(.changeIdentity(name: "Piotr", surname: "Galiszewski"))
        
        // You can wait to verify the state at the last action point
        store.send(.changeIdentity(name: "Merowing", surname: "Info")) {
            $0.name = "Merowing"
            $0.surname = "Info"
        }
    }
    
    func test_verify_received_actions() {
        let testScheduler = DispatchQueue.test
        let store = ARCTestStore(
            initialState: State(),
            reducer: reducer,
            environment: testScheduler.eraseToAnyScheduler()
        )
        
        // Given a delayed update
        store.send(.advanceAgeAfterDelay)
        
        // When moving scheduler forward in time
        testScheduler.advance(by: 1)
        
        // Verify that it received delayed action and updated state (note that we choose ignore checking `mood`)
        store.receive(.changeAge(34)) {
            $0.age = 34
        }
        
        // optional: you can verify if all effects completed or cancelled
        store.assertEffectCompleted()
    }
}
