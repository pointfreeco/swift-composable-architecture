import ComposableArchitecture
import SwiftUI

@Reducer
private struct BindingsAnimations {
  var body: some Reducer<Bool, Void> {
    Reduce { state, _ in
      state.toggle()
      return .none
    }
  }
}

final class VanillaModel: ObservableObject {
  @Published var flag = false
}

let mediumAnimation = Animation.linear(duration: 0.7)
let fastAnimation = Animation.linear(duration: 0.2)

struct BindingsAnimationsTestBench: View {
  private let viewStore: ViewStoreOf<BindingsAnimations>
  let vanillaModel = VanillaModel()

  init() {
    self.viewStore = ViewStore(
      Store(initialState: false) {
        BindingsAnimations()
      },
      observe: { $0 }
    )
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

private struct BindingsContentView: View {
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

private struct AnimatedWithObservation {
  struct ObservedObjectBinding: View {
    @EnvironmentObject var vanillaModel: VanillaModel
    var body: some View {
      ZStack {
        BindingsContentView(flag: $vanillaModel.flag)
          .animation(mediumAnimation, value: vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag)
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        BindingsContentView(flag: viewStore.binding(send: ()))
          .animation(mediumAnimation, value: viewStore.state)
        Toggle("", isOn: viewStore.binding(send: ()))
      }
    }
  }
}

private struct AnimatedFromBinding {
  struct ObservedObjectBinding: View {
    @EnvironmentObject var vanillaModel: VanillaModel
    var body: some View {
      ZStack {
        BindingsContentView(flag: $vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag.animation(fastAnimation))
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        BindingsContentView(flag: viewStore.binding(send: ()))
        Toggle("", isOn: viewStore.binding(send: ()).animation(fastAnimation))
      }
    }
  }
}

private struct AnimatedFromBindingWithObservation {
  struct ObservedObjectBinding: View {
    @EnvironmentObject var vanillaModel: VanillaModel
    var body: some View {
      ZStack {
        BindingsContentView(flag: $vanillaModel.flag)
          .animation(mediumAnimation, value: vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag.animation(fastAnimation))
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        BindingsContentView(flag: viewStore.binding(send: ()))
          .animation(mediumAnimation, value: viewStore.state)
        Toggle("", isOn: viewStore.binding(send: ()).animation(fastAnimation))
      }
    }
  }
}

private struct BindingsAnimationsTestBench_Previews: PreviewProvider {
  static var previews: some View {
    BindingsAnimationsTestBench()
  }
}
