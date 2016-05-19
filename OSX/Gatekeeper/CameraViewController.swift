//
//  CameraViewController.swift
//  Gatekeeper
//
//  Created by Daniel on 19/12/15.
//  Copyright © 2015 Macoscope. All rights reserved.
//

import Cocoa

class CameraViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var gearButtonMenu: NSMenu!




    let gearMenuController = GearMenuController()
    let streamReader:MJPEGStreamReader
    var handlerID: MJPEGStreamReader.HandlerIdentifier?

    init?(streamReader reader: MJPEGStreamReader){
        streamReader = reader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("shouldn't be called - use init(streamReader:) instead")
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.wantsLayer = true
        gearButtonMenu.delegate = gearMenuController
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        print("Start data fetching")
        handlerID = streamReader.addHandler { (image, _, streamURL) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                // Since this block is called in an asynchronous manner before any UI update let's make sure that
                // the streamURL for the given image matches the currently handled URL
                if streamURL == self.streamReader.streamURL {
                    self.stopLoadingAnimation()
                    self.imageView.image = image
                }
            })
        }

        startLoadingAnimation()
        streamReader.startReading()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        streamReader.removeHandler(handlerID)
    }

    override var preferredContentSize: CGSize {
        get {
            return self.view.frame.size
        }
        set {
            super.preferredContentSize = newValue
        }
    }
    /*
    override internal func mouseDragged(theEvent: NSEvent) {
        print("dragged, let's open a regular window here")
        // hacking :)
        self.view.window?.styleMask = (self.view.window?.styleMask)! | NSResizableWindowMask | NSTitledWindowMask | NSUnifiedTitleAndToolbarWindowMask | NSClosableWindowMask
        self.view.window?.movableByWindowBackground = true
    }
    */

    @IBAction func changeActiveStreamURL(sender:AnyObject){
        if sender.respondsToSelector(Selector("representedObject")) {
            if let object = sender.representedObject, url = object as? NSURL {
                startLoadingAnimation()
                streamReader.startReadingWithURL(url)
            }
        }else{
            print("Oops sender does not have `representedObject` property");
        }
    }

    @IBAction func openGate(sender: AnyObject) {
        print("clicked")
        let request = NSMutableURLRequest( URL: Preferences.raspberryPiOpenURL)

        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            data, response, error in

            if error != nil {
                print("error=\(error)")
                return
            } else {
                let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
                print("All good, gate opened")
            }
        }

        task.resume()

    }

}

extension CameraViewController {
    class GearMenuController: NSObject, NSMenuDelegate {
        // Tags below are assigned to the menu items in IB
        enum MenuItemTags : Int {
            case UseRaspberryPi  = 1001
            case OtherWebcams    = 1003
        }
        static var menuWasUpdated = false

        func initMenuItem(item:NSMenuItem, _ url:NSURL, title:String?=nil) -> NSMenuItem {
            let action = Selector("changeActiveStreamURL:")

            assert(NSApplication.sharedApplication().targetForAction(action) != nil, "Could not find `changeActiveStreamURL:` action in the responder chain!")

            item.representedObject = url
            item.target = nil
            item.action = action
            if let itemTitle = title {
                item.title = itemTitle
            }
            return item
        }

        func menuNeedsUpdate(menu: NSMenu) {
            print(__FUNCTION__)

            guard !GearMenuController.menuWasUpdated else {
                return
            }

            for item in menu.itemArray {
                if let tag = MenuItemTags(rawValue: item.tag) {
                    switch tag {
                    case .UseRaspberryPi:
                        initMenuItem(item, Preferences.raspberryPiStreamURL)

                    case .OtherWebcams:
                        let menu = Preferences.otherWebcams.reduce(NSMenu(), combine: { (menu:NSMenu, data:(String, NSURL)) -> NSMenu in
                            let (title, url) = data
                            menu.addItem(initMenuItem(NSMenuItem(), url, title:title))

                            return menu
                        })

                        item.submenu = menu
                    }

                    GearMenuController.menuWasUpdated = true
                }
            }
        }
    }

}
private typealias LoadingIndicatorAnimation = CameraViewController
private extension LoadingIndicatorAnimation {
    func startLoadingAnimation() {
        imageView.image = NSImage(named: "LoadingTemplate")

        if let layer = imageView.layer {
            if layer.anchorPoint == CGPointMake(0.0,0.0) {
                // the view's layer needs to be anchored in the center to properly rotate when animated
                layer.anchorPoint = CGPointMake(0.5, 0.5);
                let frame = layer.frame;
                let position = CGPointMake(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height)
                layer.position = position
            }

            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0.0
            animation.toValue = 2 * M_PI;
            animation.repeatCount = Float.infinity
            animation.duration = 0.9
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)

            layer.addAnimation(animation, forKey:"SpinnerAnimation")
        }
    }

    func stopLoadingAnimation(){
        if let layer = imageView.layer {
            layer.removeAnimationForKey("SpinnerAnimation")
        }
    }
}
