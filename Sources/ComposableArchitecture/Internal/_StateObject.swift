import Combine
import SwiftUI

@propertyWrapper
struct _StateObject<Object: ObservableObject>: DynamicProperty {
  private final class ObjectWillChange: ObservableObject {
    // Manually defining this property allows to keep it `lazy` and improves
    // performance, as we ultimately only need this publisher once in the
    // lifetime of the view.
    lazy var objectWillChange = ObservableObjectPublisher()
    private var subscription: AnyCancellable?

    init() {}
    func relay(from storage: Storage) {
      defer { storage.objectWillSendIsRelayed = true }
      subscription = storage.object.objectWillChange.sink {
        [weak objectWillChange = self.objectWillChange] _ in
        guard let objectWillChange = objectWillChange else { return }
        objectWillChange.send()
      }
    }
  }

  private final class Storage {
    lazy var object: Object = initially()
    var objectWillSendIsRelayed: Bool = false
    var initially: (() -> Object)!
    init() {}
  }

  @ObservedObject private var objectWillChange = ObjectWillChange()
  @State private var storage = Storage()

  init(wrappedValue: @autoclosure @escaping () -> Object) {
    storage.initially = wrappedValue
  }

  func update() {
    if !storage.objectWillSendIsRelayed {
      // `View` invalidation still seems to be effective even if the `objectWillChange`
      // publisher is issued from another `@ObservedObject` instance than the current
      // one. It is likely that these publishers are bound to the `View`'s identity.
      objectWillChange.relay(from: storage)
    }
  }

  var wrappedValue: Object {
    storage.object
  }
}
