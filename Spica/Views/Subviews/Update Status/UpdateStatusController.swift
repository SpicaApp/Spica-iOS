//
// Spica for iOS (Spica)
// File created by Lea Baumgart on 23.10.20.
//
// Licensed under the MIT License
// Copyright © 2020 Lea Baumgart. All rights reserved.
//
// https://github.com/SpicaApp/Spica-iOS
//

import Combine
import Foundation
import SwiftUI

protocol UpdateStatusDelegate {
    func statusUpdated()
    func statusError(err: MicroError)
}

class UpdateStatusController: ObservableObject {
    @Published var enteredText: String = ""
    @Published var selectedDate: Date = Date().addingTimeInterval(86400)
    var delegate: UpdateStatusDelegate!

    func clearStatus() {
        MicroAPI.default.updateStatus(nil, time: nil) { [self] result in
            switch result {
            case let .failure(err):
                delegate.statusError(err: err)
            case .success:
                delegate.statusUpdated()
            }
        }
    }

    func updateStatus() {
		if enteredText.count > 100 {
            delegate.statusError(err: .init(error: .init(isError: true, name: "The entered text is too long"), action: nil))
        } else {
            MicroAPI.default.updateStatus(enteredText, time: Int(selectedDate.timeIntervalSince(Date()))) { [self] result in
                switch result {
                case let .failure(err):
                    delegate.statusError(err: err)
                case .success:
                    delegate.statusUpdated()
                }
            }
        }
    }
}
