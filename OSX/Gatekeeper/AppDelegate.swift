//
//  AppDelegate.swift
//  Gatekeeper
//
//  Created by Daniel on 19/12/15.
//  Copyright © 2015 Macoscope. All rights reserved.
//

import Cocoa
import CCNStatusItem

struct Preferences {
    static let raspberryPiStreamURL = NSURL(string: "http://raspberrypi.local:8081/")!
    static let otherWebcams = [
        ("Counter",  NSURL(string:"http://mjpeg.sanford.io/count.mjpeg")!),
        ("Tai Tam Island Hong Kong", NSURL(string:"http://weathercam.gsis.edu.hk/mjpg/video.mjpg")!),
        ("Internet Cafe in Moscow",  NSURL(string:"http://212.42.54.137:8008/mjpg/video.mjpg")!),
        ("Steinhatchee River (FL)",  NSURL(string:"http://70.155.177.184/mjpg/video.mjpg")!),
        ("Calexico Border Crossing", NSURL(string:"http://201.166.63.44/axis-cgi/mjpg/video.cgi?camera=5")!),
        ("Reykjavik Harbour", NSURL(string:"http://webcam-1.faxa.rvk.is/mjpg/video.mjpg")!),
        ("Byxtorget Piteå Sweedeb", NSURL(string:"http://193.104.160.47/axis-cgi/mjpg/video.cgi?camera=1")!),
    ]
    static let raspberryPiOpenURL = NSURL(string: "http://raspberrypi.local:5000/open")!
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var streamReader: MJPEGStreamReader!
    var frameDumpingHandlerID: MJPEGStreamReader.HandlerIdentifier?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        streamReader = MJPEGStreamReader(streamURL: Preferences.raspberryPiStreamURL)

        let cameraViewController = CameraViewController(streamReader: streamReader)


        let sharedItem = CCNStatusItem.sharedInstance();
        sharedItem.windowConfiguration.presentationTransition = CCNPresentationTransition.SlideAndFade
        sharedItem.presentStatusItemWithImage(NSImage(named: "NSIChatTheaterTemplate"),
            contentViewController: cameraViewController,
            dropHandler:nil)

    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }



    @IBAction func toggleFrameToJPEGDumping(sender: AnyObject){
        if let menuItem = sender as? NSMenuItem {
            if menuItem.title == "Start Saving Frames as JPEGs" {
                let savePanel = NSSavePanel()
                savePanel.nameFieldLabel = "Basename:"
                savePanel.title = "Saving image sequence from webcam stream..."
                savePanel.message = "Please select the destination folder and the basename for the image sequence created from the webcam stream."
                savePanel.nameFieldStringValue = "Stream01" //TODO: make it more humanized maybe?

                let result = savePanel.runModal()
                if result == NSFileHandlingPanelOKButton {
                    print("Basename: \(savePanel.nameFieldStringValue) folder: \(savePanel.directoryURL)")
                    if let url = savePanel.directoryURL, directoryPath = url.path{
                        startSavingFrames(directoryPath, basename: savePanel.nameFieldStringValue)
                    }
                }

                menuItem.title = "Stop Saving Frames..."
            }else{
                stopSavingFrames()

                // Note: maybe we should consider a new title - like 'Restart saving frames...' with preserved internal frame counter state (?)
                menuItem.title = "Start Saving Frames as JPEGs"
            }

        }else{
            assertionFailure("\(__FUNCTION__) action should be called from a menu item")
        }
    }


    struct FramesCounter {
        static var counter = 0
    }
    func startSavingFrames(directory:NSString, basename:NSString) {

        guard NSFileManager.defaultManager().isWritableFileAtPath(directory as String) else {
            assertionFailure("The given directory:`\(directory)` is not writable")
            return
        }

        frameDumpingHandlerID = streamReader.addHandler { (_, data, _) -> Void in
            if let jpeg = data {
                FramesCounter.counter++

                let filename = String(format: "\(basename)-%06d.jpg", FramesCounter.counter)
                let path = directory.stringByAppendingPathComponent(filename)

                let result = jpeg.writeToFile(path, atomically: true)
                if result {
                    print("Frame #\(FramesCounter.counter) successfully saved into \(path)")
                }else {
                    print("Ooops could not save image to file: \(path)")
                }
            }
        }

        streamReader.startReading()
    }

    func stopSavingFrames() {
        streamReader.removeHandler(frameDumpingHandlerID)
        FramesCounter.counter = 0
    }
}

