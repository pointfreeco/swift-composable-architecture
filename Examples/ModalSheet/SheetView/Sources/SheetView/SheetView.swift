//
//  SheetView.swift
//  WhatSize
//
//  Created by Klajd Deda on 7/19/21.
//

import SwiftUI
import ComposableArchitecture

extension String {
    /// Debug only
    var localized: String {
        self
    }
}

extension AlertState.Button {
    var title: TextState? {
        switch type {
        case let .cancel(label: label):
            return label ?? TextState("Cancel".localized)
        case let .default(label: label):
            return label
        case let .destructive(label: label):
            return label
        }
    }
}

extension AlertState.Button {
    public func toSwiftUI(send: @escaping (Action) -> Void) -> SwiftUI.Button<Text> {
        switch self.type {
        case let .cancel(.some(label)):
            return Button(action: buttonAction(send: send)) {
                Text(label)
            }
        case .cancel(.none):
            return Button(action: buttonAction(send: send)) {
                Text("Cancel")
            }
        case let .default(label):
            return Button(action: buttonAction(send: send)) {
                Text(label)
            }
        case let .destructive(label):
            return Button(action: buttonAction(send: send)) {
                Text(label)
            }
        }
    }
}

struct SheetView<Action>: View {
    let state: AlertState<Action>
    let send: (Action) -> Void
    private let width: CGFloat = 320
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .frame(width: 48, height: 48)
                    Text(state.title)
                        .bold()
                    Spacer()
                }
                // .border(Color.gray)
                .padding(.bottom, 16)
                // ContentView(message: message)
                ScrollView {
                    Text(state.message ?? TextState(""))
                        .font(.subheadline)
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            Divider()
            // bottom part for now with one button
            HStack(spacing: 16) {
                Spacer()
                state.secondaryButton.flatMap { button in
                    button.toSwiftUI(send: send)
                        .keyboardShortcut(.cancelAction)
                        .help("Click here to cancel changes and dismiss this sheet.".localized)
                }
                state.primaryButton.flatMap { button in
                    button.toSwiftUI(send: send)
                        .keyboardShortcut(.defaultAction)
                        .help("Click here to accept the changes and dismiss this sheet.".localized)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color(.sRGB, white: 0.86, opacity: 1))
        }
        .frame(width: width)
        .frame(maxHeight: 480)
    }
}

extension AlertState {
    fileprivate func toSheetView(send: @escaping (Action) -> Void) -> some View {
        SheetView(state: self, send: send)
    }
}

extension View {
    /// Displays a sheet when then store's state becomes non-`nil`, and dismisses it when it becomes
    /// `nil`.
    ///
    /// - Parameters:
    ///   - store: A store that describes if the alert is shown or dismissed.
    ///   - dismissal: An action to send when the alert is dismissed through non-user actions, such
    ///     as when an alert is automatically dismissed by the system. Use this action to `nil` out
    ///     the associated alert state.
    public func sheet<Action>(
        _ store: Store<AlertState<Action>?, Action>,
        dismiss: Action
    ) -> some View {
        WithViewStore(store, removeDuplicates: { $0?.id == $1?.id }) { viewStore in
            self.sheet(item: viewStore.binding(send: dismiss)) { state in
                state.toSheetView(send: viewStore.send)
            }
        }
    }
}
