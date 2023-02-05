//
//  Rainbow.swift
//  MyTestProject
//
//  Created by Akash soni on 05/02/23.
//

import SwiftUI

struct Rainbow_Previews: PreviewProvider {
  static var previews: some View {
    ChipView(
      title: "Item \(1)",
      subtitle: "Subtitle \(2)",
      detail: "Detail \(3)")
  }
}

struct ContentView2: View {
  var body: some View {
    VStack {
      ForEach(0..<3) { item in
        ChipView(
          title: "Item \(item)",
          subtitle: "Subtitle \(item)",
          detail: "Detail \(item)")
      }
    }
    .padding()
  }
}

struct ChipView: View {
  let title: String
  let subtitle: String
  let detail: String

  @State private var isChecked: Bool = false
  @State private var isSelected: Bool = false

  var body: some View {
    HStack {
      Image(systemName: "person.fill")
        .foregroundColor(.gray)

      VStack(alignment: .leading) {
        Text(title)
          .font(.headline)

        Text(subtitle)
          .font(.subheadline)

        Text(detail)
          .font(.caption)
      }

      Spacer()

      Image(systemName: "arrow.right")
        .foregroundColor(.gray)

    }
    .padding(8)
    .background(isSelected ? Color.blue : Color.white)
    .cornerRadius(isSelected ? 15 : 20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
        .padding(1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .mask(RoundedRectangle(cornerRadius: 20))
    )
    .shadow(radius: 2)
    .onTapGesture {
      self.isSelected.toggle()
    }
  }
}

struct SemiCircularCheckbox: View {
  @Binding var isChecked: Bool

  var body: some View {
    ZStack {
      Circle()
        .fill(isChecked ? Color.green : Color.gray)
        .frame(width: 50, height: 50)
      if isChecked {
        Path { path in
          path.move(to: CGPoint(x: 20, y: 20))
          path.addLine(to: CGPoint(x: 30, y: 30))
          path.addLine(to: CGPoint(x: 40, y: 10))
        }
        .stroke(Color.white, lineWidth: 5)
        .animation(.default)
      }
    }
    .onTapGesture {
      self.isChecked.toggle()
    }
  }
}
