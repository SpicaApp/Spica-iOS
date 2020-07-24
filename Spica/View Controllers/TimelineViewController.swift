//
//  ViewController.swift
//  Spica
//
//  Created by Adrian Baumgart on 29.06.20.
//

import Combine
import JGProgressHUD
import Lightbox
import LocalAuthentication
// import NotificationBannerSwift
import SnapKit
import SPAlert
import SwiftKeychainWrapper
import UIKit

class TimelineViewController: UIViewController, PostCreateDelegate, UITextViewDelegate {
    var tableView: UITableView!
    var createPostBtn: UIButton!
    var posts = [Post]() {
        didSet { /* applyChanges() */ }
    }

    var refreshControl = UIRefreshControl()

    var loadingHud: JGProgressHUD!

    private var subscriptions = Set<AnyCancellable>()
	
	var verificationString = ""

    var containsCachedElements = false {
        didSet {
            /* if containsCachedElements {
                 let banner = NotificationBanner(title: "Cached items", subtitle: "The timeline contains cached information. Please reload to get the most recent data.", style: .warning)
                 banner.show(queuePosition: .front, bannerPosition: .top, queue: .default, on: self)
             } */
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = SLocale(.HOME)

        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        /* if traitCollection.userInterfaceIdiom == .mac {
         	navigationController?.setNavigationBarHidden(true, animated: false)
         } */

        let createPostBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .plain, target: self, action: #selector(openPostCreateView))

        /* #if targetEnvironment(macCatalyst)
             navigationController?.navigationBar.prefersLargeTitles = true
             navigationController?.navigationItem.largeTitleDisplayMode = .always
         #else */
        navigationItem.rightBarButtonItems = [createPostBarButtonItem]
        // #endif

        if let splitViewController = splitViewController, !splitViewController.isCollapsed {
            //
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(openSettings))

            let accountBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "person.circle"), style: .plain, target: self, action: #selector(openOwnProfileView))

            navigationItem.rightBarButtonItems?.append(accountBarButtonItem)
        }

        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.register(PostCellView.self, forCellReuseIdentifier: "postCell")
        view.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.snp.top)
            make.leading.equalTo(view.snp.leading)
            make.trailing.equalTo(view.snp.trailing)
            make.bottom.equalTo(view.snp.bottom)
        }
        refreshControl.addTarget(self, action: #selector(loadFeed), for: .valueChanged)
        tableView.addSubview(refreshControl)

        loadingHud = JGProgressHUD(style: .dark)
        loadingHud.textLabel.text = SLocale(.LOADING_ACTION)
        loadingHud.interactionType = .blockNoTouches

        createPostBtn = UIButton(type: .system)
        createPostBtn.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        createPostBtn.tintColor = .white
        createPostBtn.backgroundColor = UIColor(named: "PostButtonColor")
        createPostBtn.layer.cornerRadius = 25
        createPostBtn.addTarget(self, action: #selector(openPostCreateView), for: .touchUpInside)
        if #available(iOS 13.4, *) {
            createPostBtn.isPointerInteractionEnabled = true
        }

        /* view.addSubview(createPostBtn)

         createPostBtn.snp.makeConstraints { make in
             make.width.equalTo(50)
             make.height.equalTo(50)
             make.bottom.equalTo(view.snp.bottom).offset(-100)
             make.trailing.equalTo(view.snp.trailing).offset(-16)
         } */
    }

    // MARK: - Datasource

    typealias DataSource = UITableViewDiffableDataSource<Section, Post>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Post>

    enum Section: Hashable {
        case main
    }

    private lazy var dataSource = makeDataSource()

    func makeDataSource() -> DataSource {
        let source = DataSource(tableView: tableView) { [self] (tableView, indexPath, post) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as! PostCellView

            cell.delegate = self
            cell.indexPath = indexPath
            cell.post = post

            let tap = UITapGestureRecognizer(target: self, action: #selector(openUserProfile(_:)))

            cell.pfpImageView.tag = indexPath.row

            cell.pfpImageView.isUserInteractionEnabled = true
            cell.pfpImageView.addGestureRecognizer(tap)

            cell.upvoteButton.tag = indexPath.row
            cell.upvoteButton.addTarget(self, action: #selector(upvotePost(_:)), for: .touchUpInside)

            cell.downvoteButton.tag = indexPath.row
            cell.downvoteButton.addTarget(self, action: #selector(downvotePost(_:)), for: .touchUpInside)

            return cell
        }
        source.defaultRowAnimation = .fade
        return source
    }

    func applyChanges(_ animated: Bool = true) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(posts, toSection: .main)
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: animated)
        }
    }

    @objc func openSettings() {
        let storyboard = UIStoryboard(name: "MainSettings", bundle: nil)
        let vc = storyboard.instantiateInitialViewController() as! UINavigationController
        (vc.viewControllers.first as! MainSettingsViewController).delegate = self
        present(vc, animated: true)
    }

    @objc func openOwnProfileView() {
        let vc = UserProfileViewController()
        let username = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.username")

        vc.user = User(id: "", username: username!, displayName: username!, nickname: username!, imageURL: URL(string: "https://avatar.alles.cx/u/\(username!)")!, isPlus: false, rubies: 0, followers: 0, image: ImageLoader.loadImageFromInternet(url: URL(string: "https://avatar.alles.cx/u/\(username!)")!), isFollowing: false, followsMe: false, about: "", isOnline: false)

        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func openPostCreateView() {
        let vc = PostCreateViewController()
        vc.type = .post
        vc.delegate = self
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func setSidebar() {
        if #available(iOS 14.0, *) {
            if let splitViewController = splitViewController, !splitViewController.isCollapsed {
                if let sidebar = globalSideBarController {
                    if let collectionView = sidebar.collectionView {
                        collectionView.selectItem(at: IndexPath(row: 0, section: SidebarSection.home.rawValue), animated: true, scrollPosition: .top)
                    }
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setSidebar()

        navigationController?.navigationBar.prefersLargeTitles = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestBiometricAuth()
        setSidebar()

        /* #if targetEnvironment(macCatalyst)
             let sceneDelegate = view.window!.windowScene!.delegate as! SceneDelegate
             if let titleBar = sceneDelegate.window?.windowScene?.titlebar {
                 let toolBar = NSToolbar(identifier: "timelineToolbar")
                 toolBar.delegate = self
                 titleBar.toolbar = toolBar
             }
         #endif */

        loadFeed()
    }

    @objc func loadFeed() {
		self.verificationString = ""
        if posts.isEmpty { loadingHud.show(in: view) }

        // DispatchQueue.global(qos: .utility).async {

        AllesAPI.loadFeed(cache: .cache)
            .receive(on: RunLoop.main)
            .sink {
                switch $0 {
                case let .failure(err):
                    self.refreshControl.endRefreshing()
                    self.loadingHud.dismiss()
                    AllesAPI.default.errorHandling(error: err, caller: self.view)

                default: break
                }
			} receiveValue: { [self] posts in
                // DispatchQueue.main.async {
                /* self.containsCachedElements = posts.filter { $0.isCached == true }.isEmpty ? false : true
                 self.posts = posts.map { $0.post! } */
                self.posts = posts
                self.applyChanges()
                self.refreshControl.endRefreshing()
                self.loadingHud.dismiss()
				verificationString = randomString(length: 30)
                self.loadImages()
                // }
            }.store(in: &subscriptions)

        // }
    }

    func requestBiometricAuth() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let sceneDelegate = view.window!.windowScene!.delegate as! SceneDelegate
        let sceneRootView = sceneDelegate.window?.rootViewController?.view!

        if UserDefaults.standard.bool(forKey: "biometricAuthEnabled"), appDelegate?.sessionAuthorized == false {
            let blurStyle = traitCollection.userInterfaceStyle == .dark ? UIBlurEffect.Style.dark : UIBlurEffect.Style.light
            let blurEffect = UIBlurEffect(style: blurStyle)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = view.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurEffectView.alpha = 1.0
            blurEffectView.tag = 395
            if let blurTag = sceneRootView!.viewWithTag(395) {
            } else {
                sceneRootView!.addSubview(blurEffectView)
                blurEffectView.snp.makeConstraints { make in
                    make.top.equalTo(sceneRootView!.snp.top)
                    make.leading.equalTo(sceneRootView!.snp.leading)
                    make.bottom.equalTo(sceneRootView!.snp.bottom)
                    make.trailing.equalTo(sceneRootView!.snp.trailing)
                }
            }

            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: SLocale(.UNLOCK_SPICA)) { success, _ in
                    if success {
                        DispatchQueue.main.async {
                            appDelegate!.sessionAuthorized = true
                            UIView.animate(withDuration: 0.3, animations: {
                                blurEffectView.alpha = 0.0
										}) { _ in
                                if let blurTag = sceneRootView!.viewWithTag(395) {
                                    blurTag.removeFromSuperview()
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            EZAlertController.alert(SLocale(.BIOMETRIC_AUTH_FAILED), message: SLocale(.PLEASE_TRY_AGAIN), acceptMessage: SLocale(.RETRY_ACTION)) {
                                self.requestBiometricAuth()
                            }
                        }
                    }
                }
            } else {
                var type = "FaceID / TouchID"
                let biometric = biometricType()
                switch biometric {
                case .face:
                    type = "FaceID"
                case .touch:
                    type = "TouchID"
                case .none:
                    type = "FaceID / TouchID"
                }
                EZAlertController.alert(SLocale(.DEVICE_ERROR), message: String(format: SLocale(.BIOMETRIC_DEVICE_NOTAVAILABLE), "\(type)", "\(type)"), acceptMessage: SLocale(.RETRY_ACTION)) {
                    self.requestBiometricAuth()
                }
            }
        }
    }
	
	
	func loadImages() {
		let veri = verificationString
		DispatchQueue.global(qos: .background).async { [self] in
			let dispatchGroup = DispatchGroup()
			for (index, post) in posts.enumerated() {
				if veri != verificationString { return }
				dispatchGroup.enter()
				if index <= posts.count - 1 {
					if let author = posts[index].author {
						if veri != verificationString { return }
						posts[index].author?.image = ImageLoader.loadImageFromInternet(url: author.imageURL)
					}
					
					// applyChanges()
					if let url = post.imageURL {
						if veri != verificationString { return }
						posts[index].image = ImageLoader.loadImageFromInternet(url: url)
					} else {
						posts[index].image = UIImage()
					}
					if index < 5 {
						if veri != verificationString { return }
						applyChanges()
					}
					dispatchGroup.leave()
				}
			}
			applyChanges()
		}
	}

    @objc func openUserProfile(_ sender: UITapGestureRecognizer) {
        let userByTag = posts[sender.view!.tag].author
        let vc = UserProfileViewController()
        vc.user = userByTag
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func upvotePost(_ sender: UIButton) {
        vote(tag: sender.tag, vote: .upvote)
    }

    @objc func downvotePost(_ sender: UIButton) {
        vote(tag: sender.tag, vote: .downvote)
    }

    func vote(tag: Int, vote: VoteType) {
        let selectedPost = posts[tag]
        VotePost.default.vote(post: selectedPost, vote: vote)
            .receive(on: RunLoop.main)
            .sink {
                switch $0 {
                case let .failure(err):

                    AllesAPI.default.errorHandling(error: err, caller: self.view)

                default: break
                }
            } receiveValue: { [unowned self] in
                posts[tag].voteStatus = $0.status
                posts[tag].score = $0.score
                applyChanges()
            }.store(in: &subscriptions)
    }

    func didSendPost(sentPost: SentPost) {
        let detailVC = PostDetailViewController()
        detailVC.selectedPostID = sentPost.id
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension TimelineViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let post = dataSource.itemIdentifier(for: indexPath) else { return }
        let detailVC = PostDetailViewController()
        detailVC.selectedPost = post
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension TimelineViewController: MainSettingsDelegate {
    func clickedMore(username: String) {
        let vc = UserProfileViewController()
        vc.user = User(id: username, username: username, displayName: username, nickname: username, imageURL: URL(string: "https://avatar.alles.cx/u/\(username)")!, isPlus: false, rubies: 0, followers: 0, image: UIImage(systemName: "person.circle")!, isFollowing: false, followsMe: false, about: "", isOnline: false)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension TimelineViewController: PostCellViewDelegate, UIImagePickerControllerDelegate {
    func saveImage(image: UIImage?) {
        if let savingImage = image {
            UIImageWriteToSavedPhotosAlbum(savingImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    @objc func image(_: UIImage, didFinishSavingWithError error: Error?, contextInfo _: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            SPAlert.present(title: SLocale(.ERROR), message: error.localizedDescription, preset: .error)

        } else {
            SPAlert.present(title: SLocale(.SAVED_ACTION), preset: .done)
        }
    }

    func selectedTag(tag: String, indexPath _: IndexPath) {
        let vc = TagDetailViewController()
        vc.tag = Tag(name: tag, posts: [])
        navigationController?.pushViewController(vc, animated: true)
    }

    func clickedOnImage(controller: LightboxController) {
        present(controller, animated: true, completion: nil)
    }

    func repost(id: String, username: String) {
        let vc = PostCreateViewController()
        vc.type = .post
        vc.delegate = self
        vc.preText = "@\(username)\n\n\n\n%\(id)"
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func replyToPost(id: String) {
        let vc = PostCreateViewController()
        vc.type = .reply
        vc.delegate = self
        vc.parentID = id
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func copyPostID(id: String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = id
        SPAlert.present(title: SLocale(.COPIED_ACTION), preset: .done)
    }

    func deletePost(id: String) {
        EZAlertController.alert(SLocale(.DELETE_POST), message: SLocale(.DELETE_CONFIRMATION), buttons: [SLocale(.CANCEL), SLocale(.DELETE_ACTION)], buttonsPreferredStyle: [.cancel, .destructive]) { [self] _, index in
            guard index == 1 else { return }

            AllesAPI.default.deletePost(id: id)
                .receive(on: RunLoop.main)
                .sink {
                    switch $0 {
                    case let .failure(err):

                        self.refreshControl.endRefreshing()
                        self.loadingHud.dismiss()
                        AllesAPI.default.errorHandling(error: err, caller: self.view)

                    default: break
                    }
                } receiveValue: { _ in
                    SPAlert.present(title: SLocale(.DELETED_ACTION), preset: .done)
                    self.loadFeed()
                }.store(in: &subscriptions)
        }
    }

    func selectedPost(post: String, indexPath _: IndexPath) {
        let detailVC = PostDetailViewController()
        detailVC.selectedPostID = post
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func selectedURL(url: String, indexPath _: IndexPath) {
        if let url = URL(string: url), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    func selectedUser(username: String, indexPath _: IndexPath) {
        let user = User(id: username, username: username, displayName: username, nickname: username, imageURL: URL(string: "https://avatar.alles.cx/u/\(username)")!, isPlus: false, rubies: 0, followers: 0, image: ImageLoader.loadImageFromInternet(url: URL(string: "https://avatar.alles.cx/u/\(username)")!), isFollowing: false, followsMe: false, about: "", isOnline: false)
        let vc = UserProfileViewController()
        vc.user = user
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}

#if targetEnvironment(macCatalyst)
    extension TimelineViewController: NSToolbarDelegate {
        func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
            if itemIdentifier == NSToolbarItem.Identifier("newPost") {
                let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("newPost"), barButtonItem: UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .plain, target: self, action: #selector(openPostCreateView)))
                return item
            } else if itemIdentifier == NSToolbarItem.Identifier("userProfile") {
                let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("userProfile"), barButtonItem: UIBarButtonItem(image: UIImage(systemName: "person.circle"), style: .plain, target: self, action: #selector(openOwnProfileView)))
                return item
            } else if itemIdentifier == NSToolbarItem.Identifier("reloadData") {
                let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("reloadData"), barButtonItem: UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(loadFeed)))

                return item
            }
            return nil
        }

        func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
            return [NSToolbarItem.Identifier("reloadData"), NSToolbarItem.Identifier.flexibleSpace, NSToolbarItem.Identifier("userProfile"), NSToolbarItem.Identifier(rawValue: "newPost")]
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            return toolbarDefaultItemIdentifiers(toolbar)
        }
    }
#endif
