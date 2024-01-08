import SwiftUI

struct ContactDetailView: View {
  let store: StoreOf<ContactDetailFeature>
  
  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
      }
      .navigationBarTitle(Text(viewStore.contact.name))
    }
  }
}
