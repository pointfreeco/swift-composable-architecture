//
//  ContentView.swift
//  DemoApp
//
//  Created by Klajd Deda on 9/15/21.
//

import SwiftUI
import ComposableArchitecture
import SheetView

struct TestState: Equatable {
    var alert: AlertState<TestAction>?
    var sheet: Bool { alert != nil }
    var status: String = ""
}

enum TestAction: Equatable {
    case popAlert
    case confirmAlert
    case dismissAlert
    case deleteNow
}

extension TestState {
    static let reducer = Reducer<TestState, TestAction, Void>.combine(
        Reducer { state, action, environment in
            
            switch action {
            case .popAlert:
                state.alert = .init(
                    title: .init("Warning"),
                    message: .init(
                    """
                    This action will delete the selected files immediately from the file system.
                    Once the files are deleted we can't undo this operation.
                    Please make sure you have a back up of these files and continue.
                    """),
                    primaryButton: .default(.init("Cancel"), action: .send(.dismissAlert)),
                    secondaryButton: .default(.init("Delete Now"), action: .send(.deleteNow))
                )
                return .none
                
            case .confirmAlert:
                state.alert = nil
                return .none
                
            case .dismissAlert:
                state.alert = nil
                return .none
                
            case .deleteNow:
                state.alert = .init(
                    title: .init("Info"),
                    message: .init(
                    """
                    The selected files were deleted immediately.
                    """),
                    dismissButton: .default(.init("OK"), action: .send(.dismissAlert))
                )
                return .none
            }
        }
    )
}

extension Store where State == TestState, Action == TestAction {
    static let defaultStore = Store(
        initialState: TestState(),
        reducer: TestState.reducer,
        environment: ()
    )
}

struct ContentView: View {
    let store: Store<TestState, TestAction>
    
    var body: some View {
        // Log4swift[Self].info("")
        
        return WithViewStore(store) { viewStore in
            VStack(spacing: 0) {
                Text(
                    """
                    This is just a simple demo of using a modal sheet on the mac.
                    It uses the current TCA AlertState type as well as our custom SheetView type
                    The SheetView is still work in progress
                    When you click on the 'Present a SheetView' button a generic sheet modal will appear
                    """
                )
                .padding(.bottom, 20)
                Link("Click here to jump to the supporting PR", destination: URL(string: "https://github.com/pointfreeco/swift-composable-architecture/pull/787")!)
                Divider()
                Spacer()
                Button(viewStore.sheet ? "Pop Alert" : "Present a SheetView", action: { viewStore.send(.popAlert) })
            }
            .padding(.all, 20)
            .frame(width: 480, height: 320)
            .background(Color("AccentColor"))
            .sheet(store.scope(state: \.alert), dismiss: .dismissAlert)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ContentView(store: .defaultStore)
        }
    }
}
