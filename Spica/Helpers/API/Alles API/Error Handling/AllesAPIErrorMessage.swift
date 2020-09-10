//
// Spica for iOS (Spica)
// File created by Lea Baumgart on 02.07.20.
//
// Licensed under the GNU General Public License v3.0
// Copyright © 2020 Lea (Adrian) Baumgart. All rights reserved.
//
// https://github.com/SpicaApp/Spica-iOS
//

import Foundation

/// Alles API Error Message with information
public struct AllesAPIErrorMessage: Error {
    var message: String
    var error: AllesAPIError
    var actionParameter: String?
    var action: AllesAPIErrorAction?
}