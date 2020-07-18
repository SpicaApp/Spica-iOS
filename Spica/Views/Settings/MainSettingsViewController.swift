//
//  MainSettingsViewController.swift
//  Spica
//
//  Created by Adrian Baumgart on 10.07.20.
//

import SwiftKeychainWrapper
import UIKit

protocol MainSettingsDelegate {
    func clickedMore(username: String)
}

class MainSettingsViewController: UITableViewController {
    @IBOutlet var userPfpImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var versionBuildLabel: UILabel!

	// Outlets for Localization
	@IBOutlet weak var goToProfileButton: UIButton!
	@IBOutlet weak var SignOutButton: UIButton!
	
	@IBOutlet weak var spicaPrivacyButton: UIButton!
	@IBOutlet weak var spicaWebsiteButton: UIButton!
	
	@IBOutlet weak var allesPrivacyButton: UIButton!
	@IBOutlet weak var allesTOSButton: UIButton!
	@IBOutlet weak var allesWebsiteButton: UIButton!
	
	@IBOutlet weak var usedLibrariesButton: UIButton!
	@IBOutlet weak var creditsButton: UIButton!
	
	@IBOutlet weak var copyrightLabel: UILabel!
	
    var username = ""

    var delegate: MainSettingsDelegate!
	
	func localizeView() {
		goToProfileButton.setTitle(SLocale(.GO_TO_PROFILE), for: .normal)
		SignOutButton.setTitle(SLocale(.SIGN_OUT), for: .normal)
		
		spicaPrivacyButton.setTitle(SLocale(.PRIVACY_POLICY), for: .normal)
		spicaWebsiteButton.setTitle(SLocale(.WEBSITE), for: .normal)
		
		allesPrivacyButton.setTitle(SLocale(.PRIVACY_POLICY), for: .normal)
		allesTOSButton.setTitle(SLocale(.TERMS_OF_SERVICE), for: .normal)
		allesWebsiteButton.setTitle(SLocale(.WEBSITE), for: .normal)
		
		usedLibrariesButton.setTitle(SLocale(.USED_LIBRARIES), for: .normal)
		creditsButton.setTitle(SLocale(.CREDITS), for: .normal)
		
		copyrightLabel.text = SLocale(.SPICA_COPYRIGHT)
	}

    @IBAction func profileMore(_: Any) {
        if let splitViewController = splitViewController, !splitViewController.isCollapsed {
            let vc = UserProfileViewController()
            vc.user = User(id: username, username: username, displayName: username, nickname: username, imageURL: URL(string: "https://avatar.alles.cx/u/\(username)")!, isPlus: false, rubies: 0, followers: 0, image: UIImage(systemName: "person.circle")!, isFollowing: false, followsMe: false, about: "", isOnline: false)
            vc.hidesBottomBarWhenPushed = true

            navigationController?.pushViewController(vc, animated: true)
        } else {
            dismiss(animated: true)
            if delegate != nil {
                delegate.clickedMore(username: username)
            }
        }
    }

    @IBAction func signOut(_: Any) {
        KeychainWrapper.standard.removeObject(forKey: "dev.abmgrt.spica.user.username")
        KeychainWrapper.standard.removeObject(forKey: "dev.abmgrt.spica.user.token")
        KeychainWrapper.standard.removeObject(forKey: "dev.abmgrt.spica.user.id")
        let mySceneDelegate = view.window!.windowScene!.delegate as! SceneDelegate
        mySceneDelegate.window?.rootViewController = UINavigationController(rootViewController: LoginViewController())
        mySceneDelegate.window?.makeKeyAndVisible()
    }

    @IBAction func spicaPrivacy(_: Any) {
        let url = URL(string: "https://spica.fliney.eu/privacy")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!)
        }
    }

    @IBAction func spicaWebsite(_: Any) {
        let url = URL(string: "https://spica.fliney.eu/")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!)
        }
    }

    @IBAction func allesPrivacy(_: Any) {
        let url = URL(string: "https://alles.cx/docs/privacy")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!)
        }
    }

    @IBAction func allesTerms(_: Any) {
        let url = URL(string: "https://alles.cx/docs/terms")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!)
        }
    }

    @IBAction func allesWebsite(_: Any) {
        let url = URL(string: "https://alles.cx/")
        if UIApplication.shared.canOpenURL(url!) {
            UIApplication.shared.open(url!)
        }
    }

    @IBAction func usedLibraries(_: Any) {
        navigationController?.pushViewController(UsedLibrariesViewController(), animated: true)
    }

    @IBAction func credits(_: Any) {
        navigationController?.pushViewController(CreditsViewController(), animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
		self.navigationItem.title = SLocale(.SETTINGS)
		//self.tableView.delegate = self
		localizeView()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_: Bool) {
        if #available(iOS 14.0, *) {
            if let splitViewController = splitViewController, !splitViewController.isCollapsed {
                if let sidebar = globalSideBarController {
                    sidebar.collectionView.selectItem(at: IndexPath(row: 0, section: SidebarSection.settings.rawValue), animated: true, scrollPosition: .top)
                }
            }
        }

        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let build = dictionary["CFBundleVersion"] as! String

        versionBuildLabel.text = "Version \(version) Build \(build)"

        DispatchQueue.global(qos: .utility).async {
            self.username = KeychainWrapper.standard.string(forKey: "dev.abmgrt.spica.user.username")!

            DispatchQueue.main.async {
                self.usernameLabel.text = "@\(self.username)"
            }

            let userImage = ImageLoader.loadImageFromInternet(url: URL(string: "https://avatar.alles.cx/u/\(self.username)")!)

            DispatchQueue.main.async {
                self.userPfpImageView.image = userImage
            }
        }
    }

	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return SLocale(.ACCOUNT)
		case 1:
			return "Spica"
		case 2:
			return "Alles"
		case 3:
			return SLocale(.OTHER)
		case 4:
			return ""
		default:
			return ""
		}
	}
    override func viewDidAppear(_: Bool) {
        #if targetEnvironment(macCatalyst)
            let sceneDelegate = view.window!.windowScene!.delegate as! SceneDelegate
            if let titleBar = sceneDelegate.window?.windowScene?.titlebar {
                let toolBar = NSToolbar(identifier: "settingsToolbar")

                titleBar.toolbar = toolBar
            }
        #endif
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 5
    }
	

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 3
        case 1:
            return 2
        case 2:
            return 3
        case 3:
            return 2
        case 4:
            return 2
        default:
            return 0
        }
    }
}
