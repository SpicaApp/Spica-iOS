//
// Spica for iOS (Spica)
// File created by Lea Baumgart on 07.10.20.
//
// Licensed under the MIT License
// Copyright © 2020 Lea Baumgart. All rights reserved.
//
// https://github.com/SpicaApp/Spica-iOS
//

import Alamofire
import Combine
import Foundation
import SwiftKeychainWrapper
import SwiftyJSON

public class MicroAPI {
    static let `default` = MicroAPI()

    func loadAuthKey() -> String {
        return KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") ?? ""
    }

    func isError(_ response: AFDataResponse<Any>) -> MicroError {
        if response.data == nil {
            return .init(error: .init(isError: true, name: "spica_noData"), action: nil)
        } else {
            let json = JSON(response.data!)
            if json["err"].exists() {
				return .init(error: .init(isError: true, name: json["err"].string ?? "unknown", humanDescription: getErrorMessage(error: json["err"].string ?? "")), action: json["err"].string ?? "" == "badAuthorization" ? "nav:login" : "")
            }
            return .init(error: .init(isError: false, name: ""), action: nil)
        }
    }
}

struct MicroAnalyzedError {
    var isError: Bool
    var name: String
	var humanDescription: String
	
	init(isError: Bool, name: String, humanDescription: String = "") {
		self.isError = isError
		self.name = name
		self.humanDescription = humanDescription != "" ? humanDescription : name
	}
}
