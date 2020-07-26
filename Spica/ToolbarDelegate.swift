//
//  ToolbarDelegate.swift
//  Spica
//
//  Created by Adrian Baumgart on 25.07.20.
//

import UIKit

class ToolbarDelegate: NSObject {
    var navStack: [UIViewController] = []
}

#if targetEnvironment(macCatalyst)

    extension NSToolbarItem.Identifier {
        static let createPost = NSToolbarItem.Identifier("dev.abmgrt.spica.createPost")
        static let editAccount = NSToolbarItem.Identifier("dev.abmgrt.spica.editAccount")
        static let saveAccount = NSToolbarItem.Identifier("dev.abmgrt.spica.saveAccount")
        static let navigateBack = NSToolbarItem.Identifier("dev.abmgrt.spica.navigateBack")
    }

    extension ToolbarDelegate {
        @objc func createPost(_: Any?) {
            NotificationCenter.default.post(name: .createPost, object: self)
        }

        @objc func editProfile(_: Any?) {
            NotificationCenter.default.post(name: .editProfile, object: self)
        }

        @objc func saveAccount(_: Any?) {
            NotificationCenter.default.post(name: .saveProfile, object: self)
        }

        @objc func navigateBack(_: Any?) {
            print("ALERTED")
            NotificationCenter.default.post(name: .navigateBack, object: self)
        }
    }

    extension ToolbarDelegate: NSToolbarDelegate {
        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            switch toolbar.identifier {
            case .init("timeline"):
                let identifiers: [NSToolbarItem.Identifier] = [
                    .toggleSidebar,
                    .navigateBack,
                    .flexibleSpace,
                    .createPost,
                ]
                return identifiers
            case .init("mentions"):
                let identifiers: [NSToolbarItem.Identifier] = [
                    .toggleSidebar,
                    .navigateBack,
                ]
                return identifiers
            case .init("bookmarks"):
                return [
                    .toggleSidebar,
                    .navigateBack,
                ]
            case .init("tagdetail"):
                return [
                    .toggleSidebar,
                    .navigateBack,
                ]
            case .init("userprofile"):
                return [
                    .toggleSidebar,
                    .navigateBack,
                    .flexibleSpace,
                    .editAccount,
                    .createPost,
                ]
            case .init("editUserProfile"):
                return [
                    .toggleSidebar,
                    .navigateBack,
                    .flexibleSpace,
                    .saveAccount,
                ]
            case .init("detail"):
                return [
                    .toggleSidebar,
                    .navigateBack,
                ]
            default:

                return [.toggleSidebar,
                        .flexibleSpace]
            }
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            return toolbarDefaultItemIdentifiers(toolbar)
        }

        func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
            var toolbarItem: NSToolbarItem?

            switch itemIdentifier {
            case .toggleSidebar:
                toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
            case .createPost:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.image = UIImage(systemName: "square.and.pencil")
                item.label = "Create post"
                item.action = #selector(createPost(_:))
                item.target = self
                toolbarItem = item
            case .editAccount:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.image = UIImage(systemName: "person.circle")
                item.label = "Edit profile"
                item.action = #selector(editProfile(_:))
                item.target = self
                toolbarItem = item
            case .saveAccount:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.label = SLocale(.SAVE_ACTION)
                item.image = UIImage(systemName: "checkmark.circle")
                item.action = #selector(saveAccount(_:))
                item.target = self
                toolbarItem = item
            case .navigateBack:
                if navStack.count > 1 {
                    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                    item.label = "Back"
                    item.image = UIImage(systemName: "chevron.left")
                    item.action = #selector(navigateBack(_:))
                    item.target = self
                    toolbarItem = item
                } else {
                    toolbarItem = nil
                }

            default:
                toolbarItem = nil
            }
            return toolbarItem
        }
    }
#endif
