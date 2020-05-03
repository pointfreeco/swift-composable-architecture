import SwiftUI

struct CircularProgressView: View {
  private let value: Double

  init(value: Double) {
    self.value = value
  }

  var body: some View {
    Circle()
      .trim(from: 0, to: CGFloat(self.value))
      .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
      .foregroundColor(Color.black)
      .rotationEffect(Angle(degrees: -90))
      .animation(.easeIn)
  }
}

struct CircularProgressView_Previews: PreviewProvider {
  static var previews: some View {
    CircularProgressView(value: 0.3).frame(width: 44, height: 44)
  }
}
