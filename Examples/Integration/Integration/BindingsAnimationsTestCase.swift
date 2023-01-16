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

let slowAnimation = Animation.linear(duration: 0.90)
let mediumAnimation = Animation.linear(duration: 0.70)
let fastAnimation = Animation.linear(duration: 0.20)

public enum AnimationCaseTag: String{
  case observedObject = "OO"
  case viewStore = "VS"
}

public enum AnimationCase: String, CaseIterable, Hashable {
  case none
  case observeValue
  case animatedBinding
  case observeValue_BindingAnimation
  case observeValue_Transaction
  case observeValue_Transaction_BindingAnimation
  case observeValue_Binding_Transaction
  case observeValue_Transaction_Binding_Transaction
}

extension AnimationCase {
  public func toggleAccessibilityLabel(tag: AnimationCaseTag) -> String {
    self.rawValue + "_Toggle_" + tag.rawValue
  }
  public func effectiveAnimationDurationAccessibilityLabel(tag: AnimationCaseTag) -> String {
    self.rawValue + "_Result_" + tag.rawValue
  }
}

extension AnimationCase {
  @ViewBuilder
  func view(binding: Binding<Bool>) -> some View {
    switch self {
    case .none:
      CaseView(animationCase: self, flag: binding)

    case .observeValue:
      CaseView(animationCase: self, flag: binding)
        .animation(mediumAnimation, value: binding.wrappedValue)

    case .animatedBinding:
      CaseView(animationCase: self, flag: binding.animation(fastAnimation))

    case .observeValue_BindingAnimation:
      CaseView(animationCase: self, flag: binding.animation(fastAnimation))
        .animation(mediumAnimation, value: binding.wrappedValue)

    case .observeValue_Transaction:
      CaseView(animationCase: self, flag: binding)
        .transaction { $0.animation = slowAnimation }
        .animation(mediumAnimation, value: binding.wrappedValue)

    case .observeValue_Transaction_BindingAnimation:
      CaseView(animationCase: self, flag: binding.animation(fastAnimation))
        .transaction { $0.animation = slowAnimation }
        .animation(mediumAnimation, value: binding.wrappedValue)

    case .observeValue_Binding_Transaction:
      CaseView(animationCase: self, flag: binding.transaction(.init(animation: fastAnimation)))
        .animation(mediumAnimation, value: binding.wrappedValue)

    case .observeValue_Transaction_Binding_Transaction:
      CaseView(animationCase: self, flag: binding.transaction(.init(animation: fastAnimation)))
        .transaction { $0.animation = slowAnimation }
        .animation(mediumAnimation, value: binding.wrappedValue)
    }
  }
}


extension AnimationCaseTag: EnvironmentKey  {
  public static var defaultValue: AnimationCaseTag? { nil }
}

extension EnvironmentValues {
  var animationCaseTag: AnimationCaseTag? {
    get { self[AnimationCaseTag.self] }
    set { self[AnimationCaseTag.self] = newValue }
  }
}

struct VanillaView: View {
  let animationCase: AnimationCase
  @EnvironmentObject var model: VanillaModel
  var body: some View {
    animationCase.view(binding: $model.flag)
      .environment(\.animationCaseTag, .observedObject)
  }
}

struct ViewStoreView: View {
  let animationCase: AnimationCase
  @EnvironmentObject var viewStore: ViewStore<Bool, Void>
  var body: some View {
    animationCase.view(binding: viewStore.binding(send: ()))
      .environment(\.animationCaseTag, .viewStore)
  }
}

let resetNotification = Notification(name: .init("MeasureWidthAnimationDuration"))
struct CaseView: View {
  let animationCase: AnimationCase
  @Binding var flag: Bool
  @StateObject var model: AnimationDurationModel = .init()
  @Environment(\.animationCaseTag) var animationCaseTag
  let dimension: CGFloat = 100

  var body: some View {
    VStack {
      Text(model.effectiveAnimationDurationText)
        .accessibilityLabel(
          animationCase.effectiveAnimationDurationAccessibilityLabel(tag: animationCaseTag!)
        )
        .accessibilityValue(model.effectiveAnimationDurationText)
      MeasureView(animatableData: flag ? dimension : dimension * 0.75) { model.append($0) }
        .overlay {
          Toggle("", isOn: $flag)
            .accessibilityLabel(animationCase.toggleAccessibilityLabel(tag: animationCaseTag!))
            .labelsHidden()
        }
        .frame(width: dimension, height: dimension)
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
        name: resetNotification.name
      )
    ) { _ in
      self.model.prepareMeasure()
    }
  }

  struct MeasureView: View, Animatable {
    var animatableData: CGFloat
    let onChange: (AnimationProgress) -> Void
    var body: some View {
      ZStack {
        Circle()
          .fill(.red.opacity(0.25))
        Circle()
          .strokeBorder(.red.opacity(0.5), lineWidth: 2)
      }
      .drawingGroup()  // Prevents a small offset glitch when using transactions
      .frame(width: animatableData)
      .onChange(of: animatableData) {
        onChange(.init(timestamp: ProcessInfo.processInfo.systemUptime, progress: $0))
      }
    }
  }
}

struct SideBySide2: View {
  let animationCase: AnimationCase
  var body: some View {
    Grid {
      GridRow {
        VanillaView(animationCase: animationCase)
        ViewStoreView(animationCase: animationCase)
      }
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

struct BindingsAnimationsTestCase: View {
  let viewStore: ViewStoreOf<BindingsAnimations>
  let vanillaModel = VanillaModel()
  @State var currentID = 0
  init(store: StoreOf<BindingsAnimations>) {
    self.viewStore = ViewStore(store, observe: { $0 })
  }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        let cases = Array(zip(0..., AnimationCase.allCases))
        ForEach(cases, id: \.0) { (id, animationCase) in
          Section {
            SideBySide2(animationCase: animationCase)
              .id(id)
          } header: {
            Text(animationCase.title)
          } footer: {
            Text("Shoud animate with \(animationCase.expectedAnimationDescription)")
          }
        }
      }
      .toolbar {
        ToolbarItem {
          Button("Reset") { NotificationCenter.default.post(resetNotification) }
            .accessibilityLabel("Reset")
        }
        ToolbarItem {
          Button("Next case") {
            currentID += 1
            currentID %= AnimationCase.allCases.count
            withAnimation {
              proxy.scrollTo(currentID)
            }
          }
          .accessibilityLabel("Next")
        }
      }
      .headerProminence(.increased)
      .environmentObject(viewStore)
      .environmentObject(vanillaModel)
    }
  }
}

extension AnimationCase {
  var title: String {
    switch self {
    case .none:
      return "No animation"
    case .observeValue:
      return "Observe value"
    case .animatedBinding:
      return "Animated Binding"
    case .observeValue_BindingAnimation:
      return "Observed value + Animated Binding"
    case .observeValue_Transaction:
      return "Observed value + Transaction"
    case .observeValue_Transaction_BindingAnimation:
      return "Observed value + Transaction + Animated Binding"
    case .observeValue_Binding_Transaction:
      return "Observed value + Binding transaction"
    case .observeValue_Transaction_Binding_Transaction:
      return "Observed value + Transaction + Binding transaction"
    }
  }
  var expectedAnimationDescription: String {
    switch self {
    case .none:
      return "no animation"
    case .observeValue:
      return "the \"medium\" animation (0.7s)"
    case .animatedBinding:
      return "the \"fast\" animation (0.2s)"
    case .observeValue_BindingAnimation:
      return "the \"medium\" animation (0.7s)"
    case .observeValue_Transaction:
      return "the \"slow\" animation (0.9s)"
    case .observeValue_Transaction_BindingAnimation:
      return "the \"slow\" animation (0.9s)"
    case .observeValue_Binding_Transaction:
      return "the \"medium\" animation (0.7s)"
    case .observeValue_Transaction_Binding_Transaction:
      return "the \"slow\" animation (0.9s)"
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
      }
  }

  @MainActor
  func append(_ progress: AnimationProgress) {
    measures.value.append(progress)
  }
}

struct AnimationProgress: Hashable {
  let timestamp: TimeInterval
  let progress: Double
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
