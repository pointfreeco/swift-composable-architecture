import ComposableArchitecture
import SwiftUI

struct BindingsAnimations: ReducerProtocol {
  func reduce(into state: inout Bool, action: Void) -> EffectTask<Void> {
    state.toggle()
    return .none
  }
}

final class VanillaModel: ObservableObject {
  @Published var flag = false
}

let mediumAnimation = Animation.linear(duration: 0.7)
let fastAnimation = Animation.linear(duration: 0.2)

struct BindingsAnimationsTestBench: View {
  let viewStore: ViewStoreOf<BindingsAnimations>
  let vanillaModel = VanillaModel()

  init(store: StoreOf<BindingsAnimations>) {
    self.viewStore = ViewStore(store, observe: { $0 })
  }

  var body: some View {
    List {
      Section {
        SideBySide {
          AnimatedWithObservation.ObservedObjectBinding()
        } viewStoreView: {
          AnimatedWithObservation.ViewStoreBinding()
        }
      } header: {
        Text("Animated with observation.")
      } footer: {
        Text("Should animate with the \"medium\" animation.")
      }

      Section {
        SideBySide {
          AnimatedFromBinding.ObservedObjectBinding()
        } viewStoreView: {
          AnimatedFromBinding.ViewStoreBinding()
        }
      } header: {
        Text("Animated from binding.")
      } footer: {
        Text("Should animate with the \"fast\" animation.")
      }

      Section {
        SideBySide {
          AnimatedFromBindingWithObservation.ObservedObjectBinding()
        } viewStoreView: {
          AnimatedFromBindingWithObservation.ViewStoreBinding()
        }
      } header: {
        Text("Animated from binding with observation.")
      } footer: {
        Text("Should animate with the \"medium\" animation.")
      }
    }
    .headerProminence(.increased)
    .environmentObject(viewStore)
    .environmentObject(vanillaModel)
  }
}

struct SideBySide<ObservedObjectView: View, ViewStoreView: View>: View {
  let observedObjectView: ObservedObjectView
  let viewStoreView: ViewStoreView
  init(
    @ViewBuilder observedObjectView: () -> ObservedObjectView,
    @ViewBuilder viewStoreView: () -> ViewStoreView
  ) {
    self.observedObjectView = observedObjectView()
    self.viewStoreView = viewStoreView()
  }
  var body: some View {
    Grid {
      GridRow {
        observedObjectView
          .frame(width: 100, height: 100)
        viewStoreView
          .frame(width: 100, height: 100)
      }
      .labelsHidden()
      GridRow {
        Text("@ObservedObject")
          .fixedSize()
        Text("ViewStore")
      }
      .font(.footnote.bold())
      .monospaced()
    }
    .frame(maxWidth: .infinity)
  }
}

struct ContentView: View {
  @Binding var flag: Bool

  var body: some View {
    ZStack {
      Circle()
        .fill(.red.opacity(0.25))
      Circle()
        .strokeBorder(.red.opacity(0.5), lineWidth: 2)
    }
    .frame(width: flag ? 100 : 75)
  }
}

struct AnimatedWithObservation {
  struct ObservedObjectBinding: View {
    @EnvironmentObject var vanillaModel: VanillaModel
    var body: some View {
      ZStack {
        ContentView(flag: $vanillaModel.flag)
          .animation(mediumAnimation, value: vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag)
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        ContentView(flag: viewStore.binding(send: ()))
          .animation(mediumAnimation, value: viewStore.state)
        Toggle("", isOn: viewStore.binding(send: ()))
      }
    }
  }
}

struct AnimatedFromBinding {
  struct ObservedObjectBinding: View {
    @EnvironmentObject var vanillaModel: VanillaModel
    var body: some View {
      ZStack {
        ContentView(flag: $vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag.animation(fastAnimation))
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        ContentView(flag: viewStore.binding(send: ()))
        Toggle("", isOn: viewStore.binding(send: ()).animation(fastAnimation))
      }
    }
  }
}

struct AnimatedFromBindingWithObservation {
  struct ObservedObjectBinding: View {
    @EnvironmentObject var vanillaModel: VanillaModel
    var body: some View {
      ZStack {
        ContentView(flag: $vanillaModel.flag)
          .animation(mediumAnimation, value: vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag.animation(fastAnimation))
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        ContentView(flag: viewStore.binding(send: ()))
          .animation(mediumAnimation, value: viewStore.state)
        Toggle("", isOn: viewStore.binding(send: ()).animation(fastAnimation))
      }
    }
  }
}

struct BindingsAnimationsTestBench_Previews: PreviewProvider {
  static var previews: some View {
    BindingsAnimationsTestBench(
      store: .init(
        initialState: false,
        reducer: BindingsAnimations()
      )
    )
  }
}
