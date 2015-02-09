//
//  MatchDelimiters.swift
//
//  Created by Sam Tran on 2/8/15.
//  Copyright (c) 2015 Sam Tran. All rights reserved.
//

import AppKit

var sharedPlugin: MatchDelimiters?

let MatchDelimitersBackgroundColor = "MatchDelimitersBackgroundColorKey"
let MatchDelimitersEnabled = "MatchDelimitersEnabled"

extension String {
  subscript (i: Int) -> Character {
    return self[advance(self.startIndex, i)]
  }
}

class MatchDelimiters: NSObject {
  var backgroundColor: NSColor = NSColor.alternateSelectedControlColor().colorWithAlphaComponent(0.4)
  var bundle: NSBundle
  var enabled: Bool = true
  var currentStartDelimiter: Int = -1
  var currentStartDelimiterRange: NSRange = NSRange(location: 0, length: 0)
  var currentEndDelimiter: Int = -1
  var currentEndDelimiterRange: NSRange = NSRange(location: 0, length: 0)
  var currentTextView: NSTextView?

  class func pluginDidLoad(bundle: NSBundle) {
    let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? NSString
    if appName == "Xcode" {
      sharedPlugin = MatchDelimiters(bundle: bundle)
    }
  }

  init(bundle: NSBundle) {
    self.bundle = bundle
    super.init()
    initDelimMatcher()
    createMenuItems()
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }

  func initDelimMatcher() {
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "textViewChangedSelection:", name: NSTextViewDidChangeSelectionNotification, object: nil)
    createHighlight()
    if NSUserDefaults.standardUserDefaults().objectForKey(MatchDelimitersEnabled) != nil {
      enabled = NSUserDefaults.standardUserDefaults().boolForKey(MatchDelimitersEnabled)
    }
  }

  func textViewChangedSelection(notification: NSNotification) {
    let firstResponder = NSApp.keyWindow??.firstResponder
    if let responder = firstResponder as? NSTextView {
      if responder.isKindOfClass(NSClassFromString("DVTSourceTextView")) {
        updateDelimHighlight(responder)
      }
    }
  }

  /*
    TODO experiment with detecting strings and multiline strings, perhaps
    adapting _stringRegex from https://github.com/holtwick/HOStringSense-for-Xcode/blob/master/Classes/HOStringHelper.m
  */
  func updateDelimHighlight(textView: NSTextView) {
    currentTextView = textView
    let selection = textView.selectedRange
    if (selection.location == 0) {
      return
    }

    let pairs: NSString = "{}[]()"
    let searchCharsSet: NSCharacterSet = NSCharacterSet(charactersInString: pairs)

    if let str = textView.string {
      let strAtCursor = str[selection.location - 1]
      let bridgedCharacter = (String(strAtCursor) as NSString).characterAtIndex(0)

      if searchCharsSet.characterIsMember(bridgedCharacter) {
        println(textView.attributedString().attributesAtIndex(selection.location - 1, effectiveRange: nil))
        let pos = pairs.rangeOfString(String(strAtCursor)).location
        let lookingFor = NSString(format: "%C", pairs.characterAtIndex(pos ^ 1))
        let searchForward = (pos & 1) == 0
        if searchForward {
          currentStartDelimiter = selection.location - 1
        } else {
          currentEndDelimiter = selection.location - 1
        }

        var nesting: Int = 0
        let max = countElements(str)
        var idx = selection.location - 1

        while (searchForward ? idx < max : idx >= 0) {
          let c = NSString(format: "%c", NSString(string: str).characterAtIndex(idx))
          if c == lookingFor {
            if --nesting == 0 {
              if searchForward {
                currentEndDelimiter = idx
              } else {
                currentStartDelimiter = idx
              }
              break
            }
          } else if (c == String(strAtCursor)) {
            nesting += 1
          }
          searchForward ? idx++ : idx--
        }

        adjustDelimiterView()
      } else {
        currentStartDelimiter = -1
        currentEndDelimiter = -1
        adjustDelimiterView()
      }
    }
  }

  func adjustDelimiterView() {
    if let textView = currentTextView {
      if let layoutManager = textView.layoutManager {
        layoutManager.removeTemporaryAttribute(NSBackgroundColorAttributeName, forCharacterRange: currentStartDelimiterRange)
        layoutManager.removeTemporaryAttribute(NSBackgroundColorAttributeName, forCharacterRange: currentEndDelimiterRange)

        if (!enabled) {
          return;
        }

        if (currentStartDelimiter != -1) {
          currentStartDelimiterRange = NSRange(location: currentStartDelimiter, length: 1) //textView.selectedRange
          layoutManager.addTemporaryAttribute(NSBackgroundColorAttributeName,
              value: backgroundColor,
              forCharacterRange: currentStartDelimiterRange)
        }

        if (currentEndDelimiter != -1) {
          currentEndDelimiterRange = NSRange(location: currentEndDelimiter, length: 1)
          layoutManager.addTemporaryAttribute(NSBackgroundColorAttributeName,
              value: backgroundColor,
              forCharacterRange: currentEndDelimiterRange)
        }
      }
    }
  }

  func createHighlight() {
    let maybeColorData: NSData? = NSUserDefaults.standardUserDefaults().dataForKey(MatchDelimitersBackgroundColor)
    if let colorData = maybeColorData {
      self.backgroundColor = NSUnarchiver.unarchiveObjectWithData(colorData) as NSColor
      self.currentStartDelimiter = -1
      self.currentEndDelimiter = -1
    }
  }

  func createMenuItems() {
    let item = NSApp.mainMenu!!.itemWithTitle("Edit")

    if item != nil {
      let menuItem: NSMenuItem = NSMenuItem(title: "Match Delimiters", action: nil, keyEquivalent: "")
      let menu = NSMenu(title: "Match Delimiters")
      menuItem.submenu = menu

      menu.addItem({
        let enableMenu = NSMenuItem(title: "Enable matching", action: "toggleEnable:", keyEquivalent: "")
        enableMenu.target = self
        enableMenu.state = self.enabled ? NSOnState : NSOffState
        return enableMenu
      }())

      menu.addItem({
        let colorMenu = NSMenuItem(title: "Change background color", action: "showColorPanel", keyEquivalent: "")
        colorMenu.target = self
        return colorMenu
      }())

      item!.submenu!.addItem(NSMenuItem.separatorItem())
      item!.submenu!.addItem(menuItem)
    }
  }

  func toggleEnable(sender: NSMenuItem) {
    NSUserDefaults.standardUserDefaults().setBool(!enabled, forKey: MatchDelimitersEnabled)
    NSUserDefaults.standardUserDefaults().synchronize()

    enabled = !enabled
    sender.state = enabled ? NSOnState : NSOffState
    adjustDelimiterView()
  }

  func showColorPanel() {
    let panel: NSColorPanel = NSColorPanel.sharedColorPanel()
    panel.color = self.backgroundColor
    panel.setTarget(self)
    panel.setAction("adjustColor:")
    panel.orderFront(nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "colorPanelClosed:", name: NSWindowWillCloseNotification, object: nil)
  }

  func adjustColor(sender: NSColorPanel) {
    if (NSApp.keyWindow??.firstResponder != currentTextView) {
      return
    }

    backgroundColor = sender.color
    adjustDelimiterView()

    let colorData: NSData = NSArchiver.archivedDataWithRootObject(sender.color)
    NSUserDefaults.standardUserDefaults().setObject(colorData, forKey: MatchDelimitersBackgroundColor)
    NSUserDefaults.standardUserDefaults().synchronize()
  }

  func colorPanelClosed(notif: NSNotification) {
    let panel: NSColorPanel = NSColorPanel.sharedColorPanel()
    if panel == notif.object as? NSColorPanel {
      panel.setTarget(nil)
      panel.setAction(nil)
      NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowWillCloseNotification, object: nil)
    }
  }
}

