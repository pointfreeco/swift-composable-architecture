import UIKit

//func foo() {
//  StackNavigationController(store: store.scope(…)) { store in
//    switch store.case {
//    case let .detail(store):
//      return DetailViewController(store: store)
//    }
//  }
//}

public typealias StackNavigationControllerOf<R: Reducer> = StackNavigationController<R.State, R.Action>

open class StackNavigationController<State, Action>: UINavigationController, UINavigationControllerDelegate {
  let store: Store<StackState<State>, StackAction<State, Action>>
  let destination: (Store<State, Action>) -> UIViewController

  public init(
    store: Store<StackState<State>, StackAction<State, Action>>,
    // TODO: root: () -> UIViewController,
    destination: @escaping (Store<State, Action>) -> UIViewController
  ) {
    self.store = store
    self.destination = destination
    super.init(nibName: nil, bundle: nil)
    self.delegate = self
    //self.viewControllers = [root()]
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override open func viewDidLoad() {
    super.viewDidLoad()

    observe { [weak self] in
      guard let self else { return }

      guard viewControllers.map(\.stackElementID) != Array(store.currentState.ids)
      else {
        return
      }

      setViewControllers(
        zip(store.currentState.ids, store.currentState).map { id, element in
          var element = element
          let controller = self.destination(
            self.store.scope(
              id: self.store.id(state: \.[id:id], action: \.[id:id]),
              state: ToState {
                element = $0[id: id] ?? element
                return element
              },
              action: { .element(id: id, action: $0) },
              isInvalid: { !$0.ids.contains(id) }
            )
          )
          controller.stackElementID = id
          return controller
        },
        animated: true
      )
    }
  }

  public func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool
  ) {
  }

  public func navigationController(
    _ navigationController: UINavigationController,
    didShow viewController: UIViewController,
    animated: Bool
  ) {
    // TODO: navigationController.push(state: AppFeature.Path.State.detail(…))
    if store.currentState.count > viewControllers.count {
      // feature    [id2, id1, id]
      // controller [id1, id2, detached, id]
      store.send(.popFrom(id: store.currentState.ids[viewControllers/*filter*/.count]))
    }
  }
}

import ObjectiveC

extension UIViewController {
  // fileprivate var detached
  fileprivate var stackElementID: StackElementID? {
    get {
      return objc_getAssociatedObject(self, &stackElementIDKey) as? StackElementID
    }
    set {
      objc_setAssociatedObject(
        self,
        &stackElementIDKey,
        newValue,
        objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }
}
private var stackElementIDKey: UInt8 = 0
