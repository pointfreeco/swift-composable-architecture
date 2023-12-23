import ComposableArchitecture
import SwiftUI

@Reducer
struct SyncUpForm {
  // ...
}

struct SyncUpFormView: View {
  @Bindable var store: StoreOf<SyncUpForm>
  
  var body: some View {
    Form {
      
    }
  }
}
