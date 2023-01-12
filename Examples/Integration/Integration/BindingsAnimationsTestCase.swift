import Combine
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

let mediumAnimation = Animation.linear(duration: 0.75)
let fastAnimation = Animation.linear(duration: 0.25)

struct BindingsAnimationsTestCase: View {
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
    .toolbar {
      ToolbarItem {
        Button("Reset") {
          NotificationCenter.default
            .post(AnimationDurationModifier.resetNotification)
        }
        .accessibilityLabel("Reset")
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
      .padding(.top)
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
          .timeWidthChangeAnimation(label: "AnimatedWithObservation_OO")
          .animation(mediumAnimation, value: vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag)
          .accessibilityLabel("AnimatedWithObservation_OO_Toggle")
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        ContentView(flag: viewStore.binding(send: ()))
          .timeWidthChangeAnimation(label: "AnimatedWithObservation_VS")
          .animation(mediumAnimation, value: viewStore.state)
        Toggle("", isOn: viewStore.binding(send: ()))
          .accessibilityLabel("AnimatedWithObservation_VS_Toggle")
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
          .timeWidthChangeAnimation(label: "AnimatedFromBinding_OO")
        Toggle("", isOn: $vanillaModel.flag.animation(fastAnimation))
          .accessibilityLabel("AnimatedFromBinding_OO_Toggle")
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        ContentView(flag: viewStore.binding(send: ()))
          .timeWidthChangeAnimation(label: "AnimatedFromBinding_VS")
        Toggle("", isOn: viewStore.binding(send: ()).animation(fastAnimation))
          .accessibilityLabel("AnimatedFromBinding_VS_Toggle")
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
          .timeWidthChangeAnimation(label: "AnimatedFromBindingWithObservation_OO")
          .animation(mediumAnimation, value: vanillaModel.flag)
        Toggle("", isOn: $vanillaModel.flag.animation(fastAnimation))
          .accessibilityLabel("AnimatedFromBindingWithObservation_OO_Toggle")
      }
    }
  }

  struct ViewStoreBinding: View {
    @EnvironmentObject var viewStore: ViewStoreOf<BindingsAnimations>
    var body: some View {
      ZStack {
        ContentView(flag: viewStore.binding(send: ()))
          .timeWidthChangeAnimation(label: "AnimatedFromBindingWithObservation_VS")
          .animation(mediumAnimation, value: viewStore.state)
        Toggle("", isOn: viewStore.binding(send: ()).animation(fastAnimation))
          .accessibilityLabel("AnimatedFromBindingWithObservation_VS_Toggle")
      }
    }
  }
}

// Animation Measure
@MainActor
final class AnimationDurationModel: ObservableObject {
  var cancellable: AnyCancellable?
  @Published var effectiveAnimationDuration: EffectiveAnimationDuration?
  var isResetting: Bool = true
  let measures = CurrentValueSubject<[AnimationProgress], Never>([])
  let range: ClosedRange<CGFloat> = 100...200

  var effectiveAnimationDurationText: String {
    switch effectiveAnimationDuration {
    case let .duration(d): return d.formatted(.number.precision(.fractionLength(1)))
    case .instant: return "None"
    case .none: return "?"
    }
  }

  init() {}

  func prepareMeasure() {
    self.isResetting = true
    self.cancellable = nil
    self.measures.value = []
    self.effectiveAnimationDuration = nil
    self.startInstant = nil
    defer { self.isResetting = false }
    self.cancellable =
      measures
      .filter { [unowned self] _ in !self.isResetting }
      .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
      .map(effectiveAnimationDuration(progresses:))
      .sink { [unowned self] duration in
        self.effectiveAnimationDuration = duration
        isResetting = true
        self.measures.value = []
        isResetting = false
        self.startInstant = nil
      }
  }

  var startInstant: ContinuousClock.Instant?
  @MainActor
  func append(_ dimension: CGFloat, instant: ContinuousClock.Instant) {
    if startInstant == nil {
      startInstant = ContinuousClock().now
    }
    let progress = AnimationProgress(
      timestamp: startInstant!.duration(to: instant).timeInterval,
      progress: (dimension - range.lowerBound) / (range.upperBound - range.lowerBound)
    )
    measures.value.append(progress)
  }
}

struct AnimationProgress: Hashable, Comparable {
  let timestamp: TimeInterval
  let progress: Double
  static func < (lhs: AnimationProgress, rhs: AnimationProgress) -> Bool {
    lhs.timestamp < rhs.timestamp
  }
}

extension Duration {
  var timeInterval: TimeInterval {
    Double(self.components.seconds) + Double(self.components.attoseconds) * 1e-18
  }
}

enum EffectiveAnimationDuration: Hashable {
  case instant
  case duration(TimeInterval)
}

func effectiveAnimationDuration(progresses: [AnimationProgress]) -> EffectiveAnimationDuration {
  guard !progresses.isEmpty else { return .instant }

  struct Derivative {
    var dp: Double
    var dt: Double
    var timestamp: Double
    var lowerBound: Double { timestamp }
    var upperBound: Double { timestamp + dt }
  }

  var derivative = [Derivative]()

  for (p0, p1) in zip(progresses, progresses[1...]) {
    derivative.append(
      .init(
        dp: p1.progress - p0.progress,
        dt: p1.timestamp - p0.timestamp,
        timestamp: p0.timestamp
      )
    )
  }

  let trimmed =
    derivative
    .trimmingPrefix(while: { $0.dp == 0 })
    .reversed()
    .trimmingPrefix(while: { $0.dp == 0 })
    .reversed()

  guard !trimmed.isEmpty else { return .instant }
  return .duration(trimmed.last!.upperBound - trimmed.first!.lowerBound)
}

// View Modifier
extension View {
  func timeWidthChangeAnimation(label: String) -> some View {
    self.modifier(AnimationDurationModifier(label: label))
  }
}

struct AnimationDurationModifier: ViewModifier {
  static let resetNotification = Notification(name: .init("AnimationDurationModifierReset"))

  let label: String
  @StateObject var model: AnimationDurationModel = .init()
  func body(content: Content) -> some View {
    content
      .background {
        MeasureView { model.append($0, instant: $1) }
          .opacity(0)
      }
      .overlay(alignment: .top) {
        Text(model.effectiveAnimationDurationText)
          .accessibilityLabel(label)
          .accessibilityValue(model.effectiveAnimationDurationText)
          .alignmentGuide(.top, computeValue: { $0[.bottom] })
      }

      .task {
        // We don't want the initial layout to register as an
        // animation, so we activate the model only after a few ms.
        try? await Task.sleep(for: .milliseconds(100))
        self.model.prepareMeasure()
      }
      .onReceive(
        NotificationCenter.Publisher(
          center: .default,
          name: Self.resetNotification.name
        )
      ) { _ in
        self.model.prepareMeasure()
      }
  }
}

// Representable that performs the measure.
struct MeasureView: UIViewRepresentable {
  let onChange: (CGFloat, ContinuousClock.Instant) -> Void

  func makeUIView(context: Context) -> View {
    View(onChange: onChange)
  }
  func updateUIView(_ uiView: View, context: Context) {
    uiView.onChange = onChange
  }

  final class View: UIView {
    var onChange: (CGFloat, ContinuousClock.Instant) -> Void

    init(
      onChange: @escaping (CGFloat, ContinuousClock.Instant) -> Void
    ) {
      self.onChange = onChange
      super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override var frame: CGRect {
      didSet {
        let now = ContinuousClock().now
        DispatchQueue.main.async { [frame, onChange] in
          onChange(frame.width, now)
        }
      }
    }
  }
}

struct BindingsAnimationsTestCase_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      BindingsAnimationsTestCase(
        store: .init(
          initialState: false,
          reducer: BindingsAnimations()
        )
      )
    }
  }
}
