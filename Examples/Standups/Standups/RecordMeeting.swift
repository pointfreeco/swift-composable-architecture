import ComposableArchitecture
import Speech
import SwiftUI

struct RecordMeeting: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var alert: AlertState<Action.Alert>?
    var secondsElapsed = 0
    var speakerIndex = 0
    var standup: Standup
    var transcript = ""

    var durationRemaining: Duration {
      self.standup.duration - .seconds(self.secondsElapsed)
    }
  }
  enum Action: Equatable {
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)
    case endMeetingButtonTapped
    case nextButtonTapped
    case onTask
    case timerTick
    case speechFailure
    case speechResult(SpeechRecognitionResult)

    enum Alert {
      case confirmDiscard
      case confirmSave
    }
    enum Delegate: Equatable {
      case save(transcript: String)
    }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.speechClient) var speechClient

  private enum CancelID { case timer }

  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .alert(.presented(.confirmDiscard)):
        return .run { _ in
          await self.dismiss()
        }

      case .alert(.presented(.confirmSave)):
        return self.meetingFinished(transcript: state.transcript)

      case .alert:
        return .none

      case .delegate:
        return .none

      case .endMeetingButtonTapped:
        state.alert = .endMeeting(isDiscardable: true)
        return .none

      case .nextButtonTapped:
        guard state.speakerIndex < state.standup.attendees.count - 1
        else {
          state.alert = .endMeeting(isDiscardable: false)
          return .none
        }
        state.speakerIndex += 1
        state.secondsElapsed =
          state.speakerIndex * Int(state.standup.durationPerAttendee.components.seconds)
        return .none

      case .onTask:
        return .run { send in
          let authorization =
            await self.speechClient.authorizationStatus() == .notDetermined
            ? self.speechClient.requestAuthorization()
            : self.speechClient.authorizationStatus()

          await withTaskGroup(of: Void.self) { group in
            if authorization == .authorized {
              group.addTask {
                await self.startSpeechRecognition(send: send)
              }
            }
            group.addTask {
              await self.startTimer(send: send)
            }
          }
        }
        .cancellable(id: CancelID.timer)

      case .timerTick:
        guard state.alert == nil
        else { return .none }

        state.secondsElapsed += 1

        let secondsPerAttendee = Int(state.standup.durationPerAttendee.components.seconds)
        if state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
          if state.speakerIndex == state.standup.attendees.count - 1 {
            return self.meetingFinished(transcript: state.transcript)
          }
          state.speakerIndex += 1
        }

        return .none

      case .speechFailure:
        if !state.transcript.isEmpty {
          state.transcript += " ❌"
        }
        state.alert = .speechRecognizerFailed
        return .none

      case let .speechResult(result):
        state.transcript = result.bestTranscription.formattedString
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }

  private func startSpeechRecognition(send: Send<Action>) async {
    do {
      let speechTask = await self.speechClient.startTask(SFSpeechAudioBufferRecognitionRequest())
      for try await result in speechTask {
        await send(.speechResult(result))
      }
    } catch {
      await send(.speechFailure)
    }
  }

  private func startTimer(send: Send<Action>) async {
    for await _ in self.clock.timer(interval: .seconds(1)) {
      await send(.timerTick)
    }
  }

  private func meetingFinished(transcript: String) -> EffectTask<Action> {
    .merge(
      .cancel(id: CancelID.timer),
      .send(.delegate(.save(transcript: transcript)))
    )
  }
}

struct RecordMeetingView: View {
  let store: StoreOf<RecordMeeting>

  struct ViewState: Equatable {
    let durationRemaining: Duration
    let secondsElapsed: Int
    let speakerIndex: Int
    let standup: Standup
    init(state: RecordMeeting.State) {
      self.durationRemaining = state.durationRemaining
      self.secondsElapsed = state.secondsElapsed
      self.standup = state.standup
      self.speakerIndex = state.speakerIndex
    }
  }

  var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      ZStack {
        RoundedRectangle(cornerRadius: 16)
          .fill(viewStore.standup.theme.mainColor)

        VStack {
          MeetingHeaderView(
            secondsElapsed: viewStore.secondsElapsed,
            durationRemaining: viewStore.durationRemaining,
            theme: viewStore.standup.theme
          )
          MeetingTimerView(
            standup: viewStore.standup,
            speakerIndex: viewStore.speakerIndex
          )
          MeetingFooterView(
            standup: viewStore.standup,
            nextButtonTapped: {
              viewStore.send(.nextButtonTapped)
            },
            speakerIndex: viewStore.speakerIndex
          )
        }
      }
      .padding()
      .foregroundColor(viewStore.standup.theme.accentColor)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("End meeting") {
            viewStore.send(.endMeetingButtonTapped)
          }
        }
      }
      .navigationBarBackButtonHidden(true)
      .alert(store: self.store.scope(state: \.$alert, action: { .alert($0) }))
      .task { await viewStore.send(.onTask).finish() }
    }
  }
}

extension AlertState where Action == RecordMeeting.Action.Alert {
  static func endMeeting(isDiscardable: Bool) -> Self {
    Self {
      TextState("End meeting?")
    } actions: {
      ButtonState(action: .confirmSave) {
        TextState("Save and end")
      }
      if isDiscardable {
        ButtonState(role: .destructive, action: .confirmDiscard) {
          TextState("Discard")
        }
      }
      ButtonState(role: .cancel) {
        TextState("Resume")
      }
    } message: {
      TextState("You are ending the meeting early. What would you like to do?")
    }
  }

  static let speechRecognizerFailed = Self {
    TextState("Speech recognition failure")
  } actions: {
    ButtonState(role: .cancel) {
      TextState("Continue meeting")
    }
    ButtonState(role: .destructive, action: .confirmDiscard) {
      TextState("Discard meeting")
    }
  } message: {
    TextState(
      """
      The speech recognizer has failed for some reason and so your meeting will no longer be \
      recorded. What do you want to do?
      """
    )
  }
}

struct MeetingHeaderView: View {
  let secondsElapsed: Int
  let durationRemaining: Duration
  let theme: Theme

  var body: some View {
    VStack {
      ProgressView(value: self.progress)
        .progressViewStyle(MeetingProgressViewStyle(theme: self.theme))
      HStack {
        VStack(alignment: .leading) {
          Text("Time Elapsed")
            .font(.caption)
          Label(
            Duration.seconds(self.secondsElapsed).formatted(.units()),
            systemImage: "hourglass.bottomhalf.fill"
          )
        }
        Spacer()
        VStack(alignment: .trailing) {
          Text("Time Remaining")
            .font(.caption)
          Label(self.durationRemaining.formatted(.units()), systemImage: "hourglass.tophalf.fill")
            .font(.body.monospacedDigit())
            .labelStyle(.trailingIcon)
        }
      }
    }
    .padding([.top, .horizontal])
  }

  private var totalDuration: Duration {
    .seconds(self.secondsElapsed) + self.durationRemaining
  }

  private var progress: Double {
    guard self.totalDuration > .seconds(0) else { return 0 }
    return Double(self.secondsElapsed) / Double(self.totalDuration.components.seconds)
  }
}

struct MeetingProgressViewStyle: ProgressViewStyle {
  var theme: Theme

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(self.theme.accentColor)
        .frame(height: 20)

      ProgressView(configuration)
        .tint(self.theme.mainColor)
        .frame(height: 12)
        .padding(.horizontal)
    }
  }
}

struct MeetingTimerView: View {
  let standup: Standup
  let speakerIndex: Int

  var body: some View {
    Circle()
      .strokeBorder(lineWidth: 24)
      .overlay {
        VStack {
          Group {
            if self.speakerIndex < self.standup.attendees.count {
              Text(self.standup.attendees[self.speakerIndex].name)
            } else {
              Text("Someone")
            }
          }
          .font(.title)
          Text("is speaking")
          Image(systemName: "mic.fill")
            .font(.largeTitle)
            .padding(.top)
        }
        .foregroundStyle(self.standup.theme.accentColor)
      }
      .overlay {
        ForEach(Array(self.standup.attendees.enumerated()), id: \.element.id) { index, attendee in
          if index < self.speakerIndex + 1 {
            SpeakerArc(totalSpeakers: self.standup.attendees.count, speakerIndex: index)
              .rotation(Angle(degrees: -90))
              .stroke(self.standup.theme.mainColor, lineWidth: 12)
          }
        }
      }
      .padding(.horizontal)
  }
}

struct SpeakerArc: Shape {
  let totalSpeakers: Int
  let speakerIndex: Int

  func path(in rect: CGRect) -> Path {
    let diameter = min(rect.size.width, rect.size.height) - 24
    let radius = diameter / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    return Path { path in
      path.addArc(
        center: center,
        radius: radius,
        startAngle: self.startAngle,
        endAngle: self.endAngle,
        clockwise: false
      )
    }
  }

  private var degreesPerSpeaker: Double {
    360 / Double(self.totalSpeakers)
  }
  private var startAngle: Angle {
    Angle(degrees: self.degreesPerSpeaker * Double(self.speakerIndex) + 1)
  }
  private var endAngle: Angle {
    Angle(degrees: self.startAngle.degrees + self.degreesPerSpeaker - 1)
  }
}

struct MeetingFooterView: View {
  let standup: Standup
  var nextButtonTapped: () -> Void
  let speakerIndex: Int

  var body: some View {
    VStack {
      HStack {
        if self.speakerIndex < self.standup.attendees.count - 1 {
          Text("Speaker \(self.speakerIndex + 1) of \(self.standup.attendees.count)")
        } else {
          Text("No more speakers.")
        }
        Spacer()
        Button(action: self.nextButtonTapped) {
          Image(systemName: "forward.fill")
        }
      }
    }
    .padding([.bottom, .horizontal])
  }
}

struct RecordMeeting_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      RecordMeetingView(
        store: Store(initialState: RecordMeeting.State(standup: .mock)) {
          RecordMeeting()
        }
      )
    }
  }
}
