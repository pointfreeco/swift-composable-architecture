//
//  DemoViewController.swift
//  Example
//
//  Created by Andy Wen on 2023/7/30.
//

import Combine
import ComposableArchitecture
import SwiftUI
import UIKit

struct PresentationCounter: Reducer {
	struct Presentation: Reducer {
		enum State: Equatable {
			case sheetCounter(PresentationCounter.State)
			case fullScreenCounter(PresentationCounter.State)
		}
		
		enum Action: Equatable {
			case sheetCounter(PresentationCounter.Action)
			case fullScreenCounter(PresentationCounter.Action)
		}
		
		var body: some ReducerOf<Self> {
			Scope(state: /State.sheetCounter, action: /Action.sheetCounter) { PresentationCounter() }
			Scope(state: /State.fullScreenCounter, action: /Action.fullScreenCounter) { PresentationCounter() }
		}
	}
	
	struct State: Equatable {
		@PresentationState var presentation: Presentation.State?
		var count: Int = 0
	}
	
	enum Action: Equatable {
		enum ViewAction: Equatable {
			case dismissButtonDidTapped
			case incrementButtonDidTapped
			case decrementButtonDidTapped
			case presentAnotherDidTapped
			case selfPresentButtonDidTapped
			case pushButtonDidTapped
			case popButtonDidTapped
			case pushMultipleButtonDidTapped
			case popMultipleButtonDidTapped
			case popToRootButtonDidTapped
		}
		
		enum InternalAction: Equatable {}
		enum DelegateAction: Equatable {
			case shouldPop
			case shouldPopMultiple
			case shouldPush
			case shouldPushMultiple
			case shouldPresentAnother
			case shouldDismiss
			case shouldPopToRoot
		}
		
		case view(ViewAction)
		case `internal`(InternalAction)
		case delegate(DelegateAction)
		case presentation(PresentationAction<Presentation.Action>)
	}
	
	var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .view(.dismissButtonDidTapped):
				return .send(.delegate(.shouldDismiss))

			case .view(.incrementButtonDidTapped):
				state.count += 1
				return .none

			case .view(.decrementButtonDidTapped):
				state.count -= 1
				return .none

			case .view(.presentAnotherDidTapped):
				return .send(.delegate(.shouldPresentAnother))

			case .view(.selfPresentButtonDidTapped):
				state.presentation = .sheetCounter(.init(count: state.count + 1))
				return .none

			case .view(.pushButtonDidTapped):
				return .send(.delegate(.shouldPush))

			case .view(.popButtonDidTapped):
				return .send(.delegate(.shouldPop))

			case .view(.pushMultipleButtonDidTapped):
				return .send(.delegate(.shouldPushMultiple))

			case .view(.popMultipleButtonDidTapped):
				return .send(.delegate(.shouldPopMultiple))

			case .view(.popToRootButtonDidTapped):
				return .send(.delegate(.shouldPopToRoot))
				
			case .view:
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldDismiss)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldDismiss)))):
				state.presentation = nil
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldPresentAnother)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldPresentAnother)))):
				guard let currPresent = state.presentation else {
					state.presentation = .sheetCounter(.init(count: 0))
					return .none
				}
				
				switch currPresent {
				case let .sheetCounter(counterState):
					state.presentation = .fullScreenCounter(counterState)
				case let .fullScreenCounter(counterState):
					state.presentation = .sheetCounter(counterState)
				}
				return .none
				
			case .presentation:
				return .none
				
			case .internal:
				return .none
				
			case .delegate:
				return .none
			}
		}
		.ifLet(\.$presentation, action: /Action.presentation) { Presentation() }
	}
}

final class PresentationCounterViewController: HostingPresentationViewController<CounterView> {
	private let store: StoreOf<PresentationCounter>
	private var subscriptions: Set<AnyCancellable> = .init()
	
	init(store: StoreOf<PresentationCounter>) {
		self.store = store
		super.init(rootView: CounterView(store: store))
		self.title = "\(ViewStore(store, observe: { $0 }).count)"
	}
	
	@MainActor required dynamic init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			systemItem: .close,
			primaryAction: .init(handler: { [weak self] _ in
				self?.dismiss(animated: self?.viewIfLoaded?.window != nil)
			})
		)
		
		store.publisher
			.map({ "\($0.count)" })
			.sink { [weak self] in self?.title = $0 }
			.store(in: &subscriptions)
		
		self.presentation(store.scope(
			state: \.$presentation,
			action: PresentationCounter.Action.presentation
		)) { state, childStore in
			switch state {
			case .sheetCounter:
				guard let viewController = childStore.scope(
					state: /PresentationCounter.Presentation.State.sheetCounter,
					action: PresentationCounter.Presentation.Action.sheetCounter
				).map(PresentationCounterViewController.init(store:)) else {
					return PresentationViewController(nibName: nil, bundle: nil)
				}
				let _viewController = NavigationPresentationViewController(
					rootViewController: viewController
				)
				_viewController.modalPresentationStyle = .pageSheet
				return _viewController
			case .fullScreenCounter:
				guard let viewController = childStore.scope(
					state: /PresentationCounter.Presentation.State.fullScreenCounter,
					action: PresentationCounter.Presentation.Action.fullScreenCounter
				).map(PresentationCounterViewController.init(store:)) else {
					return PresentationViewController(nibName: nil, bundle: nil)
				}
				let _viewController = NavigationPresentationViewController(
					rootViewController: viewController
				)
				_viewController.modalPresentationStyle = .overFullScreen
				return _viewController
			}
		}
		.store(in: &subscriptions)
	}
}

struct CounterView: View {
	@Environment(\.dismiss) var dismiss
	let store: StoreOf<PresentationCounter>
	@ObservedObject var viewStore: ViewStoreOf<PresentationCounter>
	
	init(store: StoreOf<PresentationCounter>) {
		self.store = store
		self.viewStore = ViewStore(store, observe: { $0 })
	}
	
	var body: some View {
		VStack {
			HStack {
				Button(action: { viewStore.send(.view(.incrementButtonDidTapped)) }) {
					Text("+")
				}
				
				Text("\(viewStore.count)")
				
				
				Button(action: { viewStore.send(.view(.decrementButtonDidTapped)) }) {
					Text("-")
				}
			}
			
			Button(action: { viewStore.send(.view(.pushButtonDidTapped)) }) { Text("Push") }
			Button(action: { viewStore.send(.view(.popButtonDidTapped)) }) { Text("Pop") }
			Button(action: { viewStore.send(.view(.pushMultipleButtonDidTapped)) }) { Text("Push Multiple") }
			Button(action: { viewStore.send(.view(.popMultipleButtonDidTapped)) }) { Text("Pop Multiple") }
			Button(action: { viewStore.send(.view(.popToRootButtonDidTapped)) }) { Text("Pop to Root") }

			Button(action: { viewStore.send(.view(.presentAnotherDidTapped)) }) { Text("Present Another") }
			Button(action: { viewStore.send(.view(.selfPresentButtonDidTapped)) }) { Text("Present By Self") }
			Button(action: { self.dismiss() }) { Text("native dismiss") }
			Button(action: { viewStore.send(.view(.dismissButtonDidTapped)) }) { Text("action dismiss") }
		}
		.buttonStyle(.borderedProminent)
	}
}

struct PresentationStack: Reducer {
	public struct StackDestination: Reducer {
		public enum State: Equatable {
			case counter(PresentationCounter.State)
		}
		
		public enum Action: Equatable {
			case counter(PresentationCounter.Action)
		}
		
		public var body: some ReducerOf<Self> {
			Scope(state: /State.counter, action: /Action.counter) { PresentationCounter() }
		}
	}
	
	struct Presentation: Reducer {
		enum State: Equatable {
			case sheetCounter(PresentationCounter.State)
			case fullScreenCounter(PresentationCounter.State)
		}
		
		enum Action: Equatable {
			case sheetCounter(PresentationCounter.Action)
			case fullScreenCounter(PresentationCounter.Action)
		}
		
		var body: some ReducerOf<Self> {
			Scope(state: /State.sheetCounter, action: /Action.sheetCounter) { PresentationCounter() }
			Scope(state: /State.fullScreenCounter, action: /Action.fullScreenCounter) { PresentationCounter() }
		}
	}
	
	struct State: Equatable {
		@PresentationState var presentation: Presentation.State?
		var stackPath: StackState<StackDestination.State> = .init()
		var rootPath: PresentationCounter.State = .init()
	}
	
	enum Action: Equatable {
		case presentation(PresentationAction<Presentation.Action>)
		case stackPath(StackAction<StackDestination.State, StackDestination.Action>)
		case rootPath(PresentationCounter.Action)
	}
	
	var body: some ReducerOf<Self> {
		Scope(state: \.rootPath, action: /Action.rootPath) { PresentationCounter() }
		
		Reduce({ state, action in
			switch action {
			case .rootPath(.delegate(.shouldPush)),
					.stackPath(.element(id: _, action: .counter(.delegate(.shouldPush)))):
				state.stackPath.append(.counter(.init()))
				return .none
				
			case .rootPath(.delegate(.shouldPop)),
					.stackPath(.element(id: _, action: .counter(.delegate(.shouldPop)))):
				state.stackPath.removeLast()
				return .none
				
			case .rootPath(.delegate(.shouldPushMultiple)),
					.stackPath(.element(id: _, action: .counter(.delegate(.shouldPushMultiple)))):
				let newPaths = Array(repeating: StackDestination.State.counter(.init()), count: Int.random(in: 1...10))
				state.stackPath.append(contentsOf: newPaths)
				return .none
				
			case .rootPath(.delegate(.shouldPopMultiple)),
					.stackPath(.element(id: _, action: .counter(.delegate(.shouldPopMultiple)))):
				state.stackPath.removeLast(min(state.stackPath.count, Int.random(in: 1...10)))
				return .none
				
			case .rootPath(.delegate(.shouldPopToRoot)),
					.stackPath(.element(id: _, action: .counter(.delegate(.shouldPopToRoot)))):
				state.stackPath.removeAll()
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldDismiss)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldDismiss)))):
				state.presentation = nil
				return .none
				
			case .presentation(.presented(.sheetCounter(.delegate(.shouldPresentAnother)))),
					.presentation(.presented(.fullScreenCounter(.delegate(.shouldPresentAnother)))):
				guard let currPresent = state.presentation else {
					state.presentation = .sheetCounter(.init(count: 0))
					return .none
				}
				
				switch currPresent {
				case let .sheetCounter(counterState):
					state.presentation = .fullScreenCounter(counterState)
				case let .fullScreenCounter(counterState):
					state.presentation = .sheetCounter(counterState)
				}
				return .none
				
			case .stackPath:
				return .none
				
			case .presentation:
				return .none
				
			case .rootPath:
				return .none
			}
		})
		.forEach(\.stackPath, action: /Action.stackPath) { StackDestination() }
		.ifLet(\.$presentation, action: /Action.presentation) { Presentation() }
	}
}

final class PresentationStackViewController: NavigationStackViewController<
	PresentationStack.StackDestination.State,
	PresentationStack.StackDestination.Action
> {
	let store: StoreOf<PresentationStack>
	var subscriptions: Set<AnyCancellable> = .init()
	
	init(store: StoreOf<PresentationStack>) {
		self.store = store
		super.init(
			store.scope(state: \.stackPath, action: PresentationStack.Action.stackPath),
			rootViewController: PresentationCounterViewController(
				store: store.scope(
					state: \.rootPath,
					action: PresentationStack.Action.rootPath
				)
			)
		) { @MainActor initialState, childStore in
			switch initialState {
			case .counter:
				return childStore.scope(
					state: /PresentationStack.StackDestination.State.counter,
					action: PresentationStack.StackDestination.Action.counter
				).map(PresentationCounterViewController.init(store:)) ?? UIViewController(nibName: nil, bundle: nil)
			}
		}
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.presentation(store.scope(
			state: \.$presentation,
			action: PresentationStack.Action.presentation
		)) { state, childStore in
			switch state {
			case .sheetCounter:
				guard let viewController = childStore.scope(
					state: /PresentationStack.Presentation.State.sheetCounter,
					action: PresentationStack.Presentation.Action.sheetCounter
				).map(PresentationCounterViewController.init(store:)) else {
					return PresentationViewController(nibName: nil, bundle: nil)
				}
				let _viewController = NavigationPresentationViewController(
					rootViewController: viewController
				)
				_viewController.modalPresentationStyle = .pageSheet
				return _viewController
			case .fullScreenCounter:
				guard let viewController = childStore.scope(
					state: /PresentationStack.Presentation.State.fullScreenCounter,
					action: PresentationStack.Presentation.Action.fullScreenCounter
				).map(PresentationCounterViewController.init(store:)) else {
					return PresentationViewController(nibName: nil, bundle: nil)
				}
				let _viewController = NavigationPresentationViewController(
					rootViewController: viewController
				)
				_viewController.modalPresentationStyle = .overFullScreen
				return _viewController
			}
		}
		.store(in: &subscriptions)
		
//		self.presentSheet(
//			store.scope(state: \.$presentation, action: PresentationStack.Action.presentation),
//			state: /PresentationStack.Presentation.State.sheetCounter,
//			action: PresentationStack.Presentation.Action.sheetCounter,
//			PresentationCounterViewController.init(store:)
//		).store(in: &subscriptions)
//		
//		self.presentSheet(
//			store.scope(state: \.$presentation, action: PresentationStack.Action.presentation),
//			state: /PresentationStack.Presentation.State.fullScreenCounter,
//			action: PresentationStack.Presentation.Action.fullScreenCounter,
//			PresentationCounterViewController.init(store:)
//		).store(in: &subscriptions)
	}
}

struct DemoViewController_Previews: PreviewProvider {
	static var previews: some View {
		let vc = PresentationStackViewController(
			store: .init(initialState: .init()) {
				PresentationStack()._printChanges()
			}
		)
		return UIViewRepresented(makeUIView: { _ in vc.view })
	}
}
