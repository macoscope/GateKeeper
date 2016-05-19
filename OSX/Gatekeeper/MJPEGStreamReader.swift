//
//  MJPEGStreamReader.swift
//  Gatekeeper
//
//  Created by Daniel on 20/12/15.
//  Copyright © 2015 Macoscope. All rights reserved.
//
import Foundation
import AppKit

public class MJPEGStreamReader: NSObject, NSURLSessionDataDelegate {
    static let beginMarkerData = NSData(bytes: [0xFF, 0xD8] as [UInt8], length: 2)
    static let endMarkerData = NSData(bytes: [0xFF, 0xD9] as [UInt8], length: 2)
    
    public private(set) var streamURL: NSURL
    
    typealias HandlerIdentifier = String
    typealias Handler = (NSImage?, NSData?, NSURL?) -> Void
    var handlers = Dictionary<HandlerIdentifier, Handler>()
    
    private var dataTask: NSURLSessionDataTask?
    private let receivedData = NSMutableData()
    
    init(streamURL url: NSURL) {
        streamURL = url
    }
    
    deinit{
        dataTask?.cancel()
    }
    
    func addHandler(handler: Handler) -> HandlerIdentifier{
        let handlerUUID = NSUUID().UUIDString
        var handlers = self.handlers
        handlers[handlerUUID] = handler
        self.handlers = handlers
        
        return handlerUUID
    }
    func removeHandler(handlerID: HandlerIdentifier?){
        if let handlerID = handlerID {
            self.handlers.removeValueForKey(handlerID)
        }
        if handlers.isEmpty {
            print("No more handlers left, suspending connection...")
            suspendReading()
        }
    }
    
    func startReadingWithURL(url:NSURL){
        if(streamURL != url){
           stopReading()
           streamURL = url
        }
        startReading()
    }
    
    func startReading(){
        if let task = dataTask {
            switch task.state {
                case NSURLSessionTaskState.Running:
                break
                
                case NSURLSessionTaskState.Suspended:
                print("Resuming data task")
                task.resume()
                
                case NSURLSessionTaskState.Canceling:
                fallthrough
                case NSURLSessionTaskState.Completed:
                
                dataTask = nil
            }
        }
        
        if dataTask==nil {
            let request = NSURLRequest(URL: streamURL )
            let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate:self, delegateQueue:nil)
            
            let newDataTask = session.dataTaskWithRequest(request)
            newDataTask.resume()
            
            dataTask = newDataTask
        }
    }
    
    func stopReading(){
        if let task = dataTask {
            task.cancel()
        }
    }
    
    func suspendReading(){
        if let task = dataTask {
            task.suspend()
        }
    }
    
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        //print("countOfBytesReceived: \(dataTask.countOfBytesReceived) state:\(dataTask.state.rawValue)" )

        receivedData.appendData(data)
        
        var searchRange = NSMakeRange(0, receivedData.length)
        let beginRange = receivedData.rangeOfData(MJPEGStreamReader.beginMarkerData, options:NSDataSearchOptions.Backwards, range:searchRange)
        if beginRange.location == NSNotFound{
            return
        }
        
        searchRange = NSMakeRange(NSMaxRange(beginRange), receivedData.length - NSMaxRange(beginRange))
        let endRange = receivedData.rangeOfData(MJPEGStreamReader.endMarkerData, options:NSDataSearchOptions.Backwards, range:searchRange)
        if endRange.location == NSNotFound {
            return
        }
        
        let jpegRange = NSMakeRange(beginRange.location, endRange.location-beginRange.location)
        let jpegData = receivedData.subdataWithRange(jpegRange)
        
        let unusedRange = NSMakeRange(NSMaxRange(jpegRange), receivedData.length - NSMaxRange(jpegRange))
        receivedData.setData(receivedData.subdataWithRange(unusedRange))
        
        produceImageAndNotifyObservers(jpegData)
    }
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError e: NSError?){
        if let error = e {
            print("An error occured: \(error)")
            
        }
        // TODO: shouldn't we handle that?
        print("Data transfer finished... task: \(task)")

    }
    private func produceImageAndNotifyObservers(jpegData: NSData) {
        //If a tree falls in a forest and no one is around to hear it, does it make a sound?
        guard !handlers.isEmpty else {
            return
        }
        let image = NSImage(data: jpegData)
        
        for (_, handler) in handlers {
            handler(image, jpegData, streamURL)
        }
    }
}

