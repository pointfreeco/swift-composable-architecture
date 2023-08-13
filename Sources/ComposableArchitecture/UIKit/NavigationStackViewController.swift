import UIKit
import OrderedCollections
import Combine

open class NavigationStackViewController<
	State,
	Action
>: UINavigationController, UINavigationControllerDelegate, ViewControllerPresentable {
	typealias Destinations = OrderedDictionary<StackElementID, UIViewController>
	
	private let store: Store<StackState<State>, StackAction<State, Action>>
	private let rootDestination: UIViewController
	private var destinations: Destinations = .init()
	private var destinationSubscription: AnyCancellable?

	public var onDismiss: (() -> Void)? = nil
	
	@MainActor
	public init(
		_ store: Store<StackState<State>, StackAction<State, Action>>,
		rootViewController: UIViewController,
		destination: @MainActor @escaping (_ initialState: State, _ destinationStore: Store<State, Action>) -> UIViewController
	) {
		self.store = store
		self.rootDestination = rootViewController
		self.destinationSubscription = nil
		super.init(rootViewController: rootViewController)
		self.delegate = self
		self.destinationSubscription = store.publisher
			.removeDuplicates(by: { areOrderedSetsDuplicates($0.ids, $1.ids) })
			.receive(on: RunLoop.main)
			.sink { [weak self] stackState in
				guard let self else { return }
				let newDestinations = stackState.ids
					.reduce(into: Destinations(), { partialResult, id in
						if let originalViewController = self.destinations[id] {
							partialResult[id] = originalViewController
						} else if let state = store.state.value[id: id] {
							partialResult[id] = destination(state, store.scope(
								state: returningLastNonNilValue({ _ in store.state.value[id: id] }, defaultValue: state),
								action: { .element(id: id, action: $0) }
							))
						}
					})
				self.destinations = newDestinations
				self.setViewControllers(
					Array([self.rootDestination] + self.destinations.values),
					animated: self.viewIfLoaded?.window != nil
				)
			}
	}
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if isBeingDismissed { self.onDismiss?() }
	}
	
	public func navigationController(
		_ navigationController: UINavigationController,
		willShow viewController: UIViewController,
		animated: Bool
	) {
		// if current pop/push isn't intractively, just check directively
		guard self.transitionCoordinator?.isInteractive ?? false else {
			self.checkPath()
			return
		}

		// NOTE: monitor transition status or the path will change if user cancelled the pop back intraction
		self.transitionCoordinator?.notifyWhenInteractionChanges({ [weak self] context in
			guard !context.isCancelled else { return }
			self?.checkPath()
		})
	}
	
	fileprivate func checkPath() {
		// only handle pop, push always triggerred programatically
		// which means the number always same
		let viewControllersFromNavigation = self.viewControllers
		let viewControllersFromState = [self.rootDestination] + self.destinations.values
		
		// calculate the real viewControllers
		// the order will change when pop multiple view controllers by long press back button
		// like: [1, 2, 3, 4] when pop to 2, the order will be [4, 1, 2]
		guard viewControllersFromNavigation.count < viewControllersFromState.count,
					viewControllersFromNavigation != viewControllersFromState,
					let rootIndex = viewControllersFromNavigation.firstIndex(of: self.rootDestination)
		else { return }
		
		let realViewControllers = viewControllersFromNavigation.suffix(from: rootIndex)
		let poppedCount = viewControllersFromState.count - realViewControllers.count
		let popped = viewControllersFromState.suffix(poppedCount)
		
		// pop from the first id
		guard let id = self.destinations.filter({ popped.contains($0.value) }).keys.first
		else { return }
		
		self.store.send(.popFrom(id: id))
	}
}

fileprivate func returningLastNonNilValue<A, B>(_ f: @escaping (A) -> B?, defaultValue: B) -> (A) -> B {
	var lastWrapped: B = defaultValue
	return { wrapped in
		lastWrapped = f(wrapped) ?? lastWrapped
		return lastWrapped
	}
}
