//
//  EditorViewController.swift
//  Codinator
//
//  Created by Lennart Kerkvliet on 26-03-16.
//  Copyright © 2016 Vladimir Danila. All rights reserved.
//

import UIKit

class EditorViewController: UIViewController, UITextViewDelegate, ProjectSplitViewControllerDelegate, UISearchBarDelegate, SnippetsDelegate {
    
    
    @IBOutlet weak var searchBar: UISearchBar!
    let htmlTextView = HTMLTextView()
    let jsTextView = JsTextView()
    let cssTextView = CSSTextView()
    
    
    var text: String? {
        get {
            if let polaris = projectManager {
                let fileExtension = polaris.selectedFileURL!.pathExtension!
                switch fileExtension {
                case "css":
                    return cssTextView.text
                case "js":
                    return jsTextView.text
                    
                default:
                    return htmlTextView.text
                }
            }
            else {
                return htmlTextView.text
            }
        }
        
        set {
            if let fileExtension = projectManager?.selectedFileURL!.pathExtension! {
                
                
                switch fileExtension {
                case "css":
                    cssTextView.text = newValue
                    cssTextView.undoManager!.removeAllActions()
                    jsTextView.isHidden = true
                    htmlTextView.isHidden = true
                    cssTextView.isHidden = false
                    
                    if htmlTextView.isFirstResponder() {
                        htmlTextView.resignFirstResponder()
                        cssTextView.becomeFirstResponder()
                    }
                    
                    if jsTextView.isFirstResponder() {
                        jsTextView.resignFirstResponder()
                        cssTextView.becomeFirstResponder()
                    }
                    
                    
                case "js":
                    jsTextView.text = newValue
                    jsTextView.undoManager!.removeAllActions()
                    cssTextView.isHidden = true
                    htmlTextView.isHidden = true
                    jsTextView.isHidden = false
                    
                    if htmlTextView.isFirstResponder() {
                        htmlTextView.resignFirstResponder()
                        jsTextView.becomeFirstResponder()
                    }
                    
                    if cssTextView.isFirstResponder() {
                        cssTextView.resignFirstResponder()
                        jsTextView.becomeFirstResponder()
                    }
                    
                default:
                    htmlTextView.text = newValue
                    htmlTextView.undoManager!.removeAllActions()
                    jsTextView.isHidden = true
                    cssTextView.isHidden = true
                    htmlTextView.isHidden = false
                    
                    if jsTextView.isFirstResponder() {
                        jsTextView.resignFirstResponder()
                        htmlTextView.becomeFirstResponder()
                    }
                    
                    if cssTextView.isFirstResponder() {
                        cssTextView.resignFirstResponder()
                        htmlTextView.becomeFirstResponder()
                    }
                }
                
            }
            
        }
    }
    
    
    var textView: CYRTextView {
        get {
            let fileExtension = projectManager!.selectedFileURL!.pathExtension!
            switch fileExtension {
            case "css":
                return cssTextView
            case "js":
                return jsTextView
                
            default:
                return htmlTextView
            }
        }
    }
    
    var splitViewFailreference: ProjectSplitViewController!
    var getSplitView: ProjectSplitViewController? {
        
        get {

            if splitViewFailreference == nil {
                if let splitVC = self.splitViewController as? ProjectSplitViewController {
                    splitViewFailreference = splitVC
                    return splitViewFailreference
                }
                else {
                    return nil
                }
            }
            else {
                return splitViewFailreference
            }
            
        }
        
    }
    
    var polarisFailreference: Polaris!
    var projectManager: Polaris? {
        get {
            if polarisFailreference == nil {
                if let splitView = getSplitView {
                    let projectManager = splitView.projectManager
                    polarisFailreference = projectManager
                    return projectManager
                }
                else {
                    return nil
                }
            }
            else {
                return polarisFailreference
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpTextView(jsTextView)
        setUpTextView(cssTextView)
        setUpTextView(htmlTextView)

        
        // Auto Completion
        let suggestionDisplayController = WUTextSuggestionDisplayController()
        suggestionDisplayController.dataSource = self
        let suggestionController = WUTextSuggestionController(textView: htmlTextView, suggestionDisplayController: suggestionDisplayController)
        suggestionController?.suggestionType = .tag
        NotificationCenter.default().addObserver(self, selector: #selector(range), name: "range", object: nil)

        
        
        view.layoutSubviews()
        
        // Subscribe to Delegates
        getSplitView?.splitViewDelegate = self
        
        // Set up notification view
        Notifications.sharedInstance.viewController = self
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setUpKeyboardForTextView(htmlTextView)
        setUpKeyboardForTextView(cssTextView)
        setUpKeyboardForTextView(jsTextView)
        
        
        getSplitView?.assistantViewController!.delegate = self
        
        
        // Keyboard show/hide notifications 
        let notificationCenter = NotificationCenter.default()
        notificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: "changedWebViewSize", object: nil)
        
        self.view.bringSubview(toFront: searchBar)
        searchBar.keyboardAppearance = .dark
        
    }

    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    
        // Remove Keyboard show/hide notifications
        let notificationCenter = NotificationCenter.default()
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        let operation = Operation()
        operation.queuePriority = .low
        operation.qualityOfService = .background
        operation.completionBlock = {
            
            let fileURL = self.projectManager!.selectedFileURL
            let root = try! self.projectManager!.selectedFileURL!.deletingLastPathComponent()
            
            DispatchQueue.main.async(execute: { 
                if let splitViewController = self.splitViewController as? ProjectSplitViewController {
                    splitViewController.webView!.loadFileURL(fileURL!, allowingReadAccessTo: root)
                }
            })
            
            do {
                try textView.text.write(to: self.projectManager!.selectedFileURL!, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                
            }
            
        }
        
        OperationQueue.main().addOperation(operation)
        
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        if text == "\n" {
        
            // Get the line
            let line = (textView.text as NSString).substring(to: range.location)
                .components(separatedBy: "\n")
                .last!

            
            // Get indent
            var indentingString: String {
                let characters = line.characters
                var indentations = ""
                
                for character in characters {
                    if character == " " {
                        indentations += String(character)
                    }
                    else {
                        break
                    }
                }
                return indentations
            }
            
            // line break + indent
            textView.insertText("\n" + indentingString)
            
            textView.undoManager?.__registerUndoWithTarget(self, handler: { _ in
                textView.undoManager?.disableUndoRegistration()

                
                if indentingString.characters.count > 1 {
                    for _ in 1...indentingString.characters.count {
                        textView.deleteBackward()
                    }
                }
                
               
                textView.undoManager?.enableUndoRegistration()
            })
            
            return false
        }
        else if range.length == 1 {
            
            // Get the line
            let line = (textView.text as NSString).substring(to: range.location + 1)
                .components(separatedBy: "\n")
                .last!

            
            let containsOtherCharacters = line.characters.filter { $0 != " " }
            
            // if there's a indentation delete 4 characters at once
            if containsOtherCharacters.count == 0 && line.characters.count != 0{
                textView.deleteBackward()
                textView.deleteBackward()
                textView.deleteBackward()
                textView.deleteBackward()
                
                textView.undoManager?.__registerUndoWithTarget(self, handler: { _ in
                    textView.undoManager?.disableUndoRegistration()
                    textView.insertText("    ")
                    textView.undoManager?.enableUndoRegistration()
                })
                
                return false
            }
            else {
                return true
            }
        }
        else {
            return true
        }
    }
    
    
    // MARK: - Searchbar
    
    //Show searchbar and add insets
    @IBOutlet weak var searchBarTopConstraint: NSLayoutConstraint!
    
    func searchBarAppeared() {
        
        searchBar.isHidden = false
        
        view.layoutIfNeeded()
        searchBarTopConstraint.constant = 0

        var insets = htmlTextView.contentInset
        insets.top = searchBar.frame.height
        
        UIView.animate(withDuration: 0.4, animations: {
            self.view.layoutIfNeeded()

            self.htmlTextView.contentInset = insets
            self.htmlTextView.scrollIndicatorInsets = insets
        }, completion : { bool in
          self.searchBar.becomeFirstResponder()
        })
    }
    
    // Hide searchbar and reset insets
    func searchBarDisAppeard() {
        
        searchBar.isHidden = true
        
        view.layoutIfNeeded()
        searchBarTopConstraint.constant = -searchBar.frame.height
        
        var insets = htmlTextView.contentInset
        insets.top = 0
        
        UIView.animate(withDuration: 0.4, animations: {
            self.view.layoutIfNeeded()
            
            self.htmlTextView.contentInset = insets
            self.htmlTextView.scrollIndicatorInsets = insets

            
            }, completion: { bool in
                self.searchBar.resignFirstResponder()
                self.searchBar.isHidden = true
            })
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        getSplitView?.searchBarDissappeared()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        // Search algorithm
        searchForText(searchBar.text!)
        getSplitView?.searchBarDissappeared()
        
    }
    
    var startedSearchInstance = false
    func searchForText(_ text: String) {
            let range = (htmlTextView.text as NSString).range(of: text, options: .caseInsensitiveSearch)
            
            if range.location == NSNotFound {
                Notifications.sharedInstance.displayErrorMessage("No occupancy found!")
            }
            else {
                htmlTextView.becomeFirstResponder()
                htmlTextView.selectedRange = range
            }
        
    }
    
    
    
    
    // MARK: - Keyboard show/hide 
    
    var keyboardHeight: CGFloat = 0
    
    func keyboardWillShow(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo!
        keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue().height
        
        dealWithAddingInsetsOnKeyboard()
        
        getSplitView?.undoButton.isEnabled = true
        getSplitView?.redoButton.isEnabled = true

    }
    
    func keyboardWillHide(_ notification: Notification) {
        keyboardHeight = 0
        
        var insets = htmlTextView.contentInset
        insets.bottom = 0
        
        textView.contentInset = insets
        textView.scrollIndicatorInsets = insets
        
        
        getSplitView?.undoButton.isEnabled = false
        getSplitView?.redoButton.isEnabled = false
    
    }
    
    func webViewSizeDidChange() {
        if keyboardHeight != 0 {
            dealWithAddingInsetsOnKeyboard()
        }
    }
    
    let grabberViewHeight = CGFloat(15)
    func dealWithAddingInsetsOnKeyboard() {
        
        var insetValue: CGFloat = 0
        
        // Create insets depending: if the webivew is on screen and bigger than the webView
        let keyboardHigher = (getSplitView!.webView!.frame.height + grabberViewHeight) < keyboardHeight
    
        if keyboardHigher {
            
            // Make sure the webView is on screen otherwise dont include it in the calculations
            if getSplitView!.webViewOnScreen {
                insetValue = keyboardHeight - getSplitView!.webView!.frame.height - grabberViewHeight
            }
            else {
                insetValue = keyboardHeight
            }
        }
    
        
        // Apply insets
        var insets = htmlTextView.contentInset
        insets.bottom = insetValue
        
        textView.contentInset = insets
        textView.scrollIndicatorInsets = insets

    }
    
    
    // MARK: - AssistantViewController
    
    func snippetWasCoppied(_ status: String) {
        
        print("status: " + status)
        
        if status == "copied" {
            Notifications.sharedInstance.displayNeutralMessage("Snippet was copied")
        }
        else {
            Notifications.sharedInstance.displayNeutralMessage("Fill out all the fields.")
        }
    }
    
    func colorDidChange(_ color: UIColor) {
        
        let colorHex = color.toHexString()
        
        let pasteBoard = UIPasteboard.general()
        pasteBoard.string = colorHex
        
        Notifications.sharedInstance.displayNeutralMessage("HEX Color was copied")

        
    }
    

    

    // MARK: - Split View
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        htmlTextView.resignFirstResponder()
        
    }
    
    
}
