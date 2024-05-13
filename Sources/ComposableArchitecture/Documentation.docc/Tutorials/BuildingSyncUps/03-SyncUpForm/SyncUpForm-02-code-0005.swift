import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpForm {
  // ...
}

struct SyncUpFormView: View {
  @Bindable var store: StoreOf<SyncUpForm>
  @FocusState var focus: Field?

  enum Field: Hashable {
    case attendee(Attendee.ID)
    case title
  }

  var body: some View {
    Form {
      Section {
        TextField("Title", text: $store.syncUp.title)
          .focused($focus, equals: .title)
          .onAppear { focus = .title }
        HStack {
          Slider(value: $store.syncUp.duration.minutes, in: 5...30, step: 1) {
            Text("Length")
          }
          Spacer()
          Text(store.syncUp.duration.formatted(.units()))
        }
        ThemePicker(selection: $store.syncUp.theme)
      } header: {
        Text("Sync-up Info")
      }
      Section {
        ForEach($store.syncUp.attendees) { $attendee in
          TextField("Name", text: $attendee.name)
            .focused($focus, equals: .attendee(attendee.id))
        }
        .onDelete { indices in
          store.send(.onDeleteAttendees(indices))
          guard
            !store.syncUp.attendees.isEmpty,
            let firstIndex = indices.first
          else { return }
          let index = min(firstIndex, store.syncUp.attendees.count - 1)
          focus = .attendee(store.syncUp.attendees[index].id)
        }

        Button("New attendee") {
          store.send(.addAttendeeButtonTapped)
          focus = .attendee(store.syncUp.attendees.last!.id)
        }
      } header: {
        Text("Attendees")
      }
    }
  }
}

struct ThemePicker: View {
  @Binding var selection: Theme

  var body: some View {
    Picker("Theme", selection: $selection) {
      ForEach(Theme.allCases) { theme in
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(theme.mainColor)
          Label(theme.name, systemImage: "paintpalette")
            .padding(4)
        }
        .foregroundColor(theme.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .tag(theme)
      }
    }
  }
}

extension Duration {
  fileprivate var minutes: Double {
    get { Double(components.seconds / 60) }
    set { self = .seconds(newValue * 60) }
  }
}
