import ComposableArchitecture
import Speech
import SwiftUI

@Reducer
struct RecordMeeting {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var secondsElapsed = 0
    var speakerIndex = 0
    @Shared var syncUp: SyncUp
    var transcript = ""

    var durationRemaining: Duration {
      syncUp.duration - .seconds(secondsElapsed)
    }
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case endMeetingButtonTapped
    case nextButtonTapped
    case onTask
    case timerTick
    case speechFailure
    case speechResult(SpeechRecognitionResult)

    @CasePathable
    enum Alert {
      case confirmDiscard
      case confirmSave
    }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.speechClient) var speechClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .alert(.presented(.confirmDiscard)):
        return .run { _ in await dismiss() }

      case .alert(.presented(.confirmSave)):
        state.syncUp.insert(transcript: state.transcript)
        return .run { _ in await dismiss() }

      case .alert:
        return .none

      case .endMeetingButtonTapped:
        state.alert = .endMeeting(isDiscardable: true)
        return .none

      case .nextButtonTapped:
        guard state.speakerIndex < state.syncUp.attendees.count - 1
        else {
          state.alert = .endMeeting(isDiscardable: false)
          return .none
        }
        state.speakerIndex += 1
        state.secondsElapsed =
          state.speakerIndex * Int(state.syncUp.durationPerAttendee.components.seconds)
        return .none

      case .onTask:
        return .run { send in
          let authorization =
            await speechClient.authorizationStatus() == .notDetermined
            ? speechClient.requestAuthorization()
            : speechClient.authorizationStatus()

          await withTaskGroup(of: Void.self) { group in
            if authorization == .authorized {
              group.addTask {
                await startSpeechRecognition(send: send)
              }
            }
            group.addTask {
              await startTimer(send: send)
            }
          }
        }

      case .timerTick:
        guard state.alert == nil
        else { return .none }

        state.secondsElapsed += 1

        let secondsPerAttendee = Int(state.syncUp.durationPerAttendee.components.seconds)
        if state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
          if state.secondsElapsed == state.syncUp.duration.components.seconds {
            state.syncUp.insert(transcript: state.transcript)
            return .run { _ in await dismiss() }
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
    .ifLet(\.$alert, action: \.alert)
  }

  private func startSpeechRecognition(send: Send<Action>) async {
    do {
      let speechTask = await speechClient.startTask(SFSpeechAudioBufferRecognitionRequest())
      for try await result in speechTask {
        await send(.speechResult(result))
      }
    } catch {
      await send(.speechFailure)
    }
  }

  private func startTimer(send: Send<Action>) async {
    for await _ in clock.timer(interval: .seconds(1)) {
      await send(.timerTick)
    }
  }
}

extension SyncUp {
  fileprivate mutating func insert(transcript: String) {
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    meetings.insert(
      Meeting(
        id: Meeting.ID(uuid()),
        date: now,
        transcript: transcript
      ),
      at: 0
    )
  }
}

struct RecordMeetingView: View {
  @Bindable var store: StoreOf<RecordMeeting>

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16)
        .fill(store.syncUp.theme.mainColor)

      VStack {
        MeetingHeaderView(
          secondsElapsed: store.secondsElapsed,
          durationRemaining: store.durationRemaining,
          theme: store.syncUp.theme
        )
        MeetingTimerView(
          syncUp: store.syncUp,
          speakerIndex: store.speakerIndex
        )
        MeetingFooterView(
          syncUp: store.syncUp,
          nextButtonTapped: {
            store.send(.nextButtonTapped)
          },
          speakerIndex: store.speakerIndex
        )
      }
    }
    .padding()
    .foregroundColor(store.syncUp.theme.accentColor)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("End meeting") {
          store.send(.endMeetingButtonTapped)
        }
      }
    }
    .navigationBarBackButtonHidden(true)
    .alert($store.scope(state: \.alert, action: \.alert))
    .task { await store.send(.onTask).finish() }
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
      ProgressView(value: progress)
        .progressViewStyle(MeetingProgressViewStyle(theme: theme))
      HStack {
        VStack(alignment: .leading) {
          Text("Time Elapsed")
            .font(.caption)
          Label(
            Duration.seconds(secondsElapsed).formatted(.units()),
            systemImage: "hourglass.bottomhalf.fill"
          )
        }
        Spacer()
        VStack(alignment: .trailing) {
          Text("Time Remaining")
            .font(.caption)
          Label(durationRemaining.formatted(.units()), systemImage: "hourglass.tophalf.fill")
            .font(.body.monospacedDigit())
            .labelStyle(.trailingIcon)
        }
      }
    }
    .padding([.top, .horizontal])
  }

  private var totalDuration: Duration {
    .seconds(secondsElapsed) + durationRemaining
  }

  private var progress: Double {
    guard totalDuration > .seconds(0) else { return 0 }
    return Double(secondsElapsed) / Double(totalDuration.components.seconds)
  }
}

struct MeetingProgressViewStyle: ProgressViewStyle {
  var theme: Theme

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10)
        .fill(theme.accentColor)
        .frame(height: 20)

      ProgressView(configuration)
        .tint(theme.mainColor)
        .frame(height: 12)
        .padding(.horizontal)
    }
  }
}

struct MeetingTimerView: View {
  let syncUp: SyncUp
  let speakerIndex: Int

  var body: some View {
    Circle()
      .strokeBorder(lineWidth: 24)
      .overlay {
        VStack {
          Group {
            if speakerIndex < syncUp.attendees.count {
              Text(syncUp.attendees[speakerIndex].name)
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
        .foregroundStyle(syncUp.theme.accentColor)
      }
      .overlay {
        ForEach(Array(syncUp.attendees.enumerated()), id: \.element.id) { index, attendee in
          if index < speakerIndex + 1 {
            SpeakerArc(totalSpeakers: syncUp.attendees.count, speakerIndex: index)
              .rotation(Angle(degrees: -90))
              .stroke(syncUp.theme.mainColor, lineWidth: 12)
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
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: false
      )
    }
  }

  private var degreesPerSpeaker: Double {
    360 / Double(totalSpeakers)
  }
  private var startAngle: Angle {
    Angle(degrees: degreesPerSpeaker * Double(speakerIndex) + 1)
  }
  private var endAngle: Angle {
    Angle(degrees: startAngle.degrees + degreesPerSpeaker - 1)
  }
}

struct MeetingFooterView: View {
  let syncUp: SyncUp
  var nextButtonTapped: () -> Void
  let speakerIndex: Int

  var body: some View {
    VStack {
      HStack {
        if speakerIndex < syncUp.attendees.count - 1 {
          Text("Speaker \(speakerIndex + 1) of \(syncUp.attendees.count)")
        } else {
          Text("No more speakers.")
        }
        Spacer()
        Button(action: nextButtonTapped) {
          Image(systemName: "forward.fill")
        }
      }
    }
    .padding([.bottom, .horizontal])
  }
}

#Preview {
  NavigationStack {
    RecordMeetingView(
      store: Store(initialState: RecordMeeting.State(syncUp: Shared(.mock))) {
        RecordMeeting()
      }
    )
  }
}
