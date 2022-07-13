import SwiftUI

struct ClockHand: Shape {
  var lineWidth: CGFloat = 3
  var animatableData: CGFloat {
    get { lineWidth }
    set { lineWidth = newValue }
  }
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + lineWidth / 2))
    return path.strokedPath(.init(lineWidth: lineWidth, lineCap: .round))
  }
}

struct ClockHand_Previews: PreviewProvider {
  static var previews: some View {
    ClockHand()
  }
}
