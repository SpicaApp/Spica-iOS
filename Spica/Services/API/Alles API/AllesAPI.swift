//
//  AllesAPI.swift
//  Spica
//
//  Created by Adrian Baumgart on 30.06.20.
//

import Alamofire
import Combine
import Foundation
import SwiftKeychainWrapper
import SwiftyJSON
import UIKit

public class AllesAPI {
    static let `default` = AllesAPI()

    private var subscriptions = Set<AnyCancellable>()

    public func signInUser(username: String, password: String) -> Future<SignedInUser, AllesAPIErrorMessage> {
        Future<SignedInUser, AllesAPIErrorMessage> { promise in
            AF.request("https://alles.cx/api/login", method: .post, parameters: [
                "username": username,
                "password": password,
            ], encoding: JSONEncoding.default).responseJSON(queue: .global(qos: .utility)) { [self] response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            if responseJSON["token"].string != nil {
                                KeychainWrapper.standard.set(responseJSON["token"].string!, forKey: "dev.abmgrt.spica.user.token")

                                AllesAPI.default.loadUser(id: username)
                                    .receive(on: RunLoop.main)
                                    .sink {
                                        switch $0 {
                                        case let .failure(err): return promise(.failure(err))
                                        default: break
                                        }
                                    } receiveValue: { user in
                                        KeychainWrapper.standard.set(user.name, forKey: "dev.abmgrt.spica.user.username")
                                        KeychainWrapper.standard.set(user.id, forKey: "dev.abmgrt.spica.user.id")

                                        SpicAPI.getPrivacyPolicy()
                                            .receive(on: RunLoop.main)
                                            .sink {
                                                switch $0 {
                                                case .failure:
                                                    promise(.success(SignedInUser(username: username, sessionToken: responseJSON["token"].string!)))
                                                default: break
                                                }
                                            } receiveValue: { privacy in
                                                UserDefaults.standard.set(privacy.updated, forKey: "spica_privacy_accepted_version")
                                                promise(.success(SignedInUser(username: username, sessionToken: responseJSON["token"].string!)))
                                            }.store(in: &subscriptions)

                                    }.store(in: &subscriptions)

                            } else {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_noLoginTokenReturned")))
                            }
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func loadFeed(cache _: CachePolicy = .remote, loadBefore: Int? = nil) -> Future<[Post], AllesAPIErrorMessage> {
        Future<[Post], AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }

            let url = loadBefore != nil ? "https://micro.alles.cx/api/feed?before=\(loadBefore!)" : "https://micro.alles.cx/api/feed"
            AF.request(url, method: .get, parameters: nil, headers: [
                "Cookie": authKey,
            ]).responseJSON { response in
                switch response.result {
                case .success:
                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            let disGroup = DispatchGroup()
                            var tempPosts = [Post]()
                            for json in responseJSON["posts"].arrayValue {
                                disGroup.enter()
                                print(json)
                                // tempPosts.append(Post(id: json.string!, author: User(id: json.string!, name: json.string!, tag: "0000"), author_id: json.string!))
                                AllesAPI.default.loadPost(id: json.string!)
                                    .receive(on: RunLoop.main)
                                    .sink {
                                        print($0)
                                        switch $0 {
                                        case let .failure(err):
                                            promise(.failure(err))
                                        default: break
                                        }
                                    } receiveValue: { post in
                                        tempPosts.append(post)
                                        disGroup.leave()
                                    }.store(in: &self.subscriptions)
                            }

                            disGroup.notify(queue: .main) {
                                print("RETURN POSTS: \(tempPosts)")
                                tempPosts.sort(by: { $0.created.compare($1.created) == .orderedDescending })
                                promise(.success(tempPosts))
                            }

                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.localizedDescription)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func sendOnlineStatus() {
        guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
            return
        }
        AF.request("https://online.alles.cx", method: .post, parameters: nil, headers: [
            "Authorization": authKey,
        ]).response(queue: .global(qos: .utility)) { _ in }
    }

    public func markNotificationsAsRead() {
        guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
            return
        }

        AF.request("https://micro.alles.cx/api/mentions/read", method: .post, headers: [
            "Cookie": authKey,
        ])
            .responseJSON { response in
                print(JSON(response.data))
                return
            }
    }

    public func loadUser(id: String) -> Future<User, AllesAPIErrorMessage> {
        Future<User, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            AF.request("https://micro.alles.cx/api/users/\(id)", method: .get, parameters: nil, headers: [
                "Cookie": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            let newUser = User(responseJSON, isOnline: true)
                            print("USERNAM_FETCH_COMP: \(id)")
                            promise(.success(newUser))
                            /* AF.request("https://online.alles.cx/\(responseJSON["id"].string!)", method: .get, parameters: nil, headers: [
                                 "Authorization": authKey,
                             ]).response(queue: .global(qos: .utility)) { onlineResponse in
                                 switch onlineResponse.result {
                                 case .success:
                                     let data = String(data: onlineResponse.data!, encoding: .utf8)
                                     let isOnline = data == "🟢"
                                     let newUser = User(responseJSON, isOnline: isOnline)
                                     promise(.success(newUser))
                                 case let .failure(err):
                                     var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                                     apiError.message.append("\nError: \(err.errorDescription!)")
                                     promise(.failure(apiError))
                                 }
                             } */
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public static func loadFollowers() -> Future<Followers, AllesAPIErrorMessage> {
        Future<Followers, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }

            AF.request("https://alles.cx/api/followers", method: .get, parameters: nil, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:
                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            let followers = responseJSON["followers"].map { _, json in
                                FollowUser(json)
                            }

                            let following = responseJSON["following"].map { _, json in
                                FollowUser(json)
                            }

                            promise(.success(Followers(followers: followers, following: following)))

                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }
                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func loadUserPosts(user: User) -> Future<[Post], AllesAPIErrorMessage> {
        Future<[Post], AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            AF.request("https://micro.alles.cx/api/users/\(user.id)", method: .get, parameters: nil, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            let disGroup = DispatchGroup()
                            var tempPosts = [Post]()
                            for json in responseJSON["posts"]["recent"].arrayValue {
                                disGroup.enter()
                                print(json)
                                // tempPosts.append(Post(id: json.string!, author: User(id: json.string!, name: json.string!, tag: "0000"), author_id: json.string!))
                                AllesAPI.default.loadPost(id: json.string!)
                                    .receive(on: RunLoop.main)
                                    .sink {
                                        print($0)
                                        switch $0 {
                                        case let .failure(err):
                                            promise(.failure(err))
                                        default: break
                                        }
                                    } receiveValue: { post in
                                        tempPosts.append(post)
                                        disGroup.leave()
                                    }.store(in: &self.subscriptions)
                            }

                            disGroup.notify(queue: .main) {
                                tempPosts.sort(by: { $0.created.compare($1.created) == .orderedDescending })
                                promise(.success(tempPosts))
                            }
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func loadMentions() -> Future<[PostNotification], AllesAPIErrorMessage> {
        Future<[PostNotification], AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            AF.request("https://micro.alles.cx/api/mentions", method: .get, parameters: nil, headers: [
                "Cookie": authKey,
            ]).responseJSON { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            var tempPosts = [PostNotification]()
                            let disGroup = DispatchGroup()
                            for notification in responseJSON["posts"].arrayValue {
                                disGroup.enter()
                                let notificationID = notification["id"].string!
                                print("NOTIFICATION_LOAD: \(notificationID)")

                                AllesAPI.default.loadPost(id: notificationID)
                                    .receive(on: RunLoop.main)
                                    .sink {
                                        print($0)
                                        switch $0 {
                                        case let .failure(err):
                                            disGroup.leave()
                                            promise(.failure(err))
                                        default: break
                                        }
                                    } receiveValue: { post in

                                        tempPosts.append(PostNotification(post: post, read: notification["read"].bool ?? true))
                                        print("NOTIFICATION_ASSIGN: \(post)")
                                        disGroup.leave()
                                    }.store(in: &self.subscriptions)
                            }

                            disGroup.notify(queue: .main) {
                                tempPosts.sort { $0.post.created.compare($1.post.created) == .orderedDescending }
                                promise(.success(tempPosts))
                            }
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public static func loadTag(tag: String) -> Future<Tag, AllesAPIErrorMessage> {
        Future<Tag, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            AF.request("https://alles.cx/api/tag/\(tag)", method: .get, parameters: nil, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            var tempPosts = responseJSON["posts"].map { _, json in
                                Post(json, mentionedUsers: [])
                            }

                            tempPosts.sort { $0.created.compare($1.created) == .orderedDescending }

                            let tag = Tag(name: responseJSON["name"].string!, posts: tempPosts)

                            promise(.success(tag))
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func loadPost(id: String) -> Future<Post, AllesAPIErrorMessage> {
        Future<Post, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }

            AF.request("https://micro.alles.cx/api/posts/\(id)", method: .get, parameters: nil, headers: [
                "Cookie": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        var userSubscriptions = Set<AnyCancellable>()
                        if response.response?.statusCode == 200 {
                            var post = Post(responseJSON, mentionedUsers: [])
                            print("AUTHID:" + post.author_id)
                            let author_id = responseJSON["author"].string!

                            var author_img_url = ""
                            if let fsId = responseJSON["users"][author_id]["avatar"].string {
                                author_img_url = "https://fs.alles.cx/\(fsId)"
                            } else {
                                author_img_url = "https://avatar.alles.cc/\(author_id)"
                            }

                            post.author = User(id: author_id, name: responseJSON["users"][author_id]["name"].string!, nickname: responseJSON["users"][author_id]["nickname"].string!, plus: responseJSON["users"][author_id]["plus"].bool!, alles: responseJSON["users"][author_id]["alles"].bool!, imgURL: URL(string: author_img_url)!)
                            DispatchQueue.main.async {
                                let postContent = post.content.replacingOccurrences(of: "\n", with: " \n ")
                                let splitContent = postContent.split(separator: " ")
                                let disGroup = DispatchGroup()
                                if splitContent.count > 0 {
                                    for word in splitContent {
                                        disGroup.enter()
                                        if word.hasPrefix("@"), word.count > 1 {
                                            var userID = removeSpecialCharsFromString(text: String(word))
                                            userID.remove(at: userID.startIndex)
                                            if responseJSON["users"][userID].exists() {
                                                var mentionedUserData = responseJSON["users"][userID]
                                                mentionedUserData["id"].stringValue = userID
                                                post.mentionedUsers.append(User(mentionedUserData))
                                                /* post.mentionedUsers.append(User(id: userID, name: responseJSON["users"][userID]["name"].string!, nickname: responseJSON["users"][userID]["nickname"].string!, plus: responseJSON["users"][userID]["plus"].bool!, alles: responseJSON["users"][userID]["alles"].bool!)) */
                                                disGroup.leave()
                                            } else {
                                                AllesAPI.default.loadUser(id: userID)
                                                    .receive(on: RunLoop.current)
                                                    .sink {
                                                        switch $0 {
                                                        case let .failure(error):
                                                            print("CRITER: \(error)")
                                                            disGroup.leave()
                                                        default: break
                                                        }
                                                    } receiveValue: { mentionedUser in
                                                        print("MENTION: \(mentionedUser.name)")
                                                        post.mentionedUsers.append(mentionedUser)
                                                        disGroup.leave()
                                                    }
                                                    .store(in: &self.subscriptions)
                                            }
                                        } else {
                                            disGroup.leave()
                                        }
                                    }

                                    disGroup.notify(queue: .main) {
                                        promise(.success(post))
                                    }
                                }
                            }

                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func loadPostDetail(id: String) -> Future<PostDetail, AllesAPIErrorMessage> {
        Future<PostDetail, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            AF.request("https://micro.alles.cx/api/posts/\(id)", method: .get, parameters: nil, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { [self] response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            var tempPostDetail = PostDetail(ancestors: [], post: Post(responseJSON, mentionedUsers: []), replies: [])
                            AllesAPI.default.loadPost(id: responseJSON["id"].string!)
                                .receive(on: RunLoop.main)
                                .sink {
                                    switch $0 {
                                    case let .failure(err):
                                        promise(.failure(err))
                                    default: break
                                    }
                                } receiveValue: { post in
                                    tempPostDetail.post = post

                                    let disGroup = DispatchGroup()

                                    for child in responseJSON["children"]["list"].arrayValue {
                                        disGroup.enter()
                                        AllesAPI.default.loadPost(id: child.string!)
                                            .receive(on: RunLoop.main)
                                            .sink {
                                                switch $0 {
                                                case let .failure(err):
                                                    disGroup.leave()
                                                    promise(.failure(err))
                                                default: break
                                                }
                                            } receiveValue: { childrenPost in
                                                tempPostDetail.replies.append(childrenPost)
                                                disGroup.leave()

                                            }.store(in: &subscriptions)
                                    }

                                    disGroup.notify(queue: .main) {
                                        let ancDisGroup = DispatchGroup()

                                        var highestAncestor: Post? {
                                            didSet {
                                                if highestAncestor?.parent_id != nil {
                                                    ancDisGroup.enter()
                                                    print("FETCH ANCESTOR: \(highestAncestor!.content)")
                                                    AllesAPI.default.loadPost(id: highestAncestor!.parent_id!)
                                                        .receive(on: RunLoop.main)
                                                        .sink {
                                                            switch $0 {
                                                            case let .failure(err):
                                                                ancDisGroup.leave()
                                                                highestAncestor?.parent_id = nil
                                                                promise(.failure(err))
                                                            default: break
                                                            }
                                                        } receiveValue: { ancPost in
                                                            tempPostDetail.ancestors.append(ancPost)
                                                            highestAncestor = ancPost
                                                            ancDisGroup.leave()
                                                        }.store(in: &subscriptions)
                                                }
                                            }
                                        }

                                        highestAncestor = tempPostDetail.post

                                        ancDisGroup.notify(queue: .main) {
                                            print("RETURN DETAIL")
                                            tempPostDetail.ancestors.sort(by: { $0.created.compare($1.created) == .orderedAscending })
                                            tempPostDetail.replies.sort(by: { $0.created.compare($1.created) == .orderedDescending })
                                            promise(.success(tempPostDetail))
                                        }
                                    }

                                }.store(in: &subscriptions)
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func sendPost(newPost: NewPost) -> Future<SentPost, AllesAPIErrorMessage> {
        Future<SentPost, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            var newPostConstruct: [String: String] = [
                "content": newPost.content,
            ]

            /* if let image = newPost.image {
                 let base64Image = "data:image/jpeg;base64,\((image.jpegData(compressionQuality: 0.5)?.base64EncodedString())!)"
                 newPostConstruct["image"] = "\(base64Image)"
             } */

            if let parent = newPost.parent {
                newPostConstruct["parent"] = parent
            }

            AF.request("https://micro.alles.cx/api/posts", method: .post, parameters: newPostConstruct, encoding: JSONEncoding.prettyPrinted, headers: [
                "Cookie": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            if responseJSON["id"].exists() {
                                promise(.success(SentPost(responseJSON)))
                            }
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func deletePost(id: String) -> Future<EmptyCompletion, AllesAPIErrorMessage> {
        Future<EmptyCompletion, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }

            AF.request("https://alles.cx/api/post/\(id)/remove", method: .post, parameters: nil, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            promise(.success(.init()))
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case let .failure(err):
                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    apiError.message.append("\nError: \(err.errorDescription!)")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func votePost(post: Post, value: Int) -> Future<Post, AllesAPIErrorMessage> {
        Future<Post, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            if value == -1 || value == 0 || value == 1 {
                AF.request("https://micro.alles.cx/api/posts/\(post.id)/vote", method: .post, parameters: ["vote": value], encoding: JSONEncoding.default, headers: [
                    "Cookie": authKey,
                ]).responseJSON(queue: .global(qos: .utility)) { response in
                    switch response.result {
                    case .success:

                        let responseJSON = JSON(response.data!)
                        if !responseJSON["err"].exists() {
                            if response.response?.statusCode == 200 {
                                promise(.success(post))
                            } else {
                                if response.response!.statusCode == 401 {
                                    promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                                } else {
                                    var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                    apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                    promise(.failure(apiError))
                                }
                            }

                        } else {
                            let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                            promise(.failure(apiError))
                        }

                    case let .failure(err):
                        var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                        apiError.message.append("\nError: \(err.errorDescription!)")
                        promise(.failure(apiError))
                    }
                }
            } else {
                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_valueNotAllowed")))
            }
        }
    }

    public func performFollowAction(username: String, action: FollowAction) -> Future<FollowAction, AllesAPIErrorMessage> {
        Future<FollowAction, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            AF.request("https://alles.cx/api/users/\(username)/\(action.actionString)", method: .post, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:

                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            promise(.success(action))
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case .failure:
                    let apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func updateProfile(newData: UpdateUser) -> Future<UpdateUser, AllesAPIErrorMessage> {
        Future<UpdateUser, AllesAPIErrorMessage> { promise in
            guard let authKey = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.token") else {
                return promise(.failure(AllesAPIErrorHandler.default.returnError(error: "spica_authTokenMissing")))
            }
            let userConstruct = [
                "about": newData.about,
                "name": newData.name,
                "nickname": newData.nickname,
            ]
            AF.request("https://alles.cx/api/updateProfile", method: .post, parameters: userConstruct, encoding: JSONEncoding.prettyPrinted, headers: [
                "Authorization": authKey,
            ]).responseJSON(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success:
                    let responseJSON = JSON(response.data!)
                    if !responseJSON["err"].exists() {
                        if response.response?.statusCode == 200 {
                            promise(.success(newData))
                        } else {
                            if response.response!.statusCode == 401 {
                                promise(.failure(AllesAPIErrorHandler.default.returnError(error: "badAuthorization")))
                            } else {
                                var apiError = AllesAPIErrorHandler.default.returnError(error: "spica_invalidStatusCode")
                                apiError.message.append("\n(Code: \(response.response!.statusCode))")
                                promise(.failure(apiError))
                            }
                        }

                    } else {
                        let apiError = AllesAPIErrorHandler.default.returnError(error: responseJSON["err"].string!)
                        promise(.failure(apiError))
                    }

                case .failure:
                    let apiError = AllesAPIErrorHandler.default.returnError(error: "spica_unknownError")
                    promise(.failure(apiError))
                }
            }
        }
    }

    public func errorHandling(error: AllesAPIErrorMessage, caller: UIView) {
        EZAlertController.alert(SLocale(.ERROR), message: error.message, buttons: ["Ok"]) { _, _ in

            if error.action != nil, error.actionParameter != nil {
                if error.action == AllesAPIErrorAction.navigate, error.actionParameter == "login" {
                    let mySceneDelegate = caller.window!.windowScene!.delegate as! SceneDelegate
                    mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
                    mySceneDelegate.window?.makeKeyAndVisible()
                }
            }
        }
    }
}

public struct EmptyCompletion {}
