//
//  MatchDelimiters.swift
//
//  Created by Sam Tran on 2/8/15.
//  Copyright (c) 2015 Sam Tran. All rights reserved.
//

import AppKit

var sharedPlugin: MatchDelimiters?

class MatchDelimiters: NSObject {
    var bundle: NSBundle

    class func pluginDidLoad(bundle: NSBundle) {
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? NSString
        if appName == "Xcode" {
            sharedPlugin = MatchDelimiters(bundle: bundle)
        }
    }

    init(bundle: NSBundle) {
        self.bundle = bundle

        super.init()
        createMenuItems()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func createMenuItems() {
        var item = NSApp.mainMenu!!.itemWithTitle("Edit")
        if item != nil {
            var actionMenuItem = NSMenuItem(title:"Do Action", action:"doMenuAction", keyEquivalent:"")
            actionMenuItem.target = self
            item!.submenu!.addItem(NSMenuItem.separatorItem())
            item!.submenu!.addItem(actionMenuItem)
        }
    }

    func doMenuAction() {
        let error = NSError(domain: "Hello World!", code:42, userInfo:nil)
        NSAlert(error: error).runModal()
    }
}

