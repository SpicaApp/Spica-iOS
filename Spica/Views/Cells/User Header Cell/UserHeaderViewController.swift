//
// Spica for iOS (Spica)
// File created by Lea Baumgart on 09.10.20.
//
// Licensed under the MIT License
// Copyright © 2020 Lea Baumgart. All rights reserved.
//
// https://github.com/SpicaApp/Spica-iOS
//

import Combine
import SwiftKeychainWrapper
import SwiftUI

protocol UserHeaderDelegate {
    func showError(title: String, message: String)
    func clickedOnFollowerCount()
    func clickedOnFollowingCount()
}

class UserHeaderViewController: ObservableObject {
    @Published var user: User = User()

    @Published var userDataLoaded: Bool = false
    @Published var isLoggedInUser: Bool = false

    var delegate: UserHeaderDelegate!

    func followUnfollowUser() {
        user.iamFollowing.toggle()
        let action: FollowUnfollow = user.iamFollowing ? .follow : .unfollow // Inverted because of previous line
        MicroAPI.default.followUnfollowUser(action, id: user.id) { [self] result in
            switch result {
            case let .failure(err):
                DispatchQueue.main.async {
                    user.iamFollowing.toggle()
                    delegate.showError(title: "Error", message: "The action failed with the following response:\n\n\(err.error.name)")
                }
            default: break
            }
        }
    }

    func showFollowers() {
        delegate.clickedOnFollowerCount()
    }

    func showFollowing() {
        delegate.clickedOnFollowingCount()
    }

    func getLoggedInUser() {
        let signedInID = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.id")

        isLoggedInUser = user.id == signedInID
    }
}
