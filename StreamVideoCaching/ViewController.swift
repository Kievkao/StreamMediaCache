//
//  ViewController.swift
//  StreamVideoCaching
//
//  Created by Andrii Kravchenko on 6/17/16.
//  Copyright © 2016 kievkao. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import MobileCoreServices

class ViewController: UIViewController, AVAssetResourceLoaderDelegate, NSURLSessionTaskDelegate {

    var player: AVPlayer!

    let loader_queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
    var dataTask: NSURLSessionDataTask?
    var session: NSURLSession!

    var pendingRequests = [AVAssetResourceLoadingRequest]()
    var receivedData: NSMutableData?
    var response: NSURLResponse?

    override func viewDidLoad() {
        super.viewDidLoad()

        let asset = AVURLAsset(URL: NSURL(string: "fakeProtocol://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!)
        asset.resourceLoader.setDelegate(self, queue: dispatch_get_main_queue())

        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)

        let playerController = AVPlayerViewController()
        playerController.player = player
        self.addChildViewController(playerController)
        self.view.addSubview(playerController.view)
        playerController.view.frame = self.view.frame

        playerItem.addObserver(self, forKeyPath: "status", options: .New, context: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }

    func resourceLoader(resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {

        if self.dataTask == nil {
            if let urlComponents = NSURLComponents(URL: loadingRequest.request.URL!, resolvingAgainstBaseURL: false) {
                urlComponents.scheme = "http"

                let request = NSURLRequest(URL: urlComponents.URL!)
                self.session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
                self.dataTask = self.session.dataTaskWithRequest(request)
                self.dataTask?.resume()
            }
        }

        self.pendingRequests.append(loadingRequest)

        return true
    }

    func resourceLoader(resourceLoader: AVAssetResourceLoader, didCancelLoadingRequest loadingRequest: AVAssetResourceLoadingRequest) {
        self.pendingRequests = self.pendingRequests.filter{$0 != loadingRequest}
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        self.receivedData = NSMutableData()
        self.response = response

        self.processPendingRequests()

        completionHandler(.Allow)
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        self.receivedData?.appendData(data)

        self.processPendingRequests()
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        self.processPendingRequests()

        let cachedFilePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("cachedVideo.mp4")

        do {
            try self.receivedData?.writeToFile(cachedFilePath, options: .AtomicWrite)
        }
        catch let error {
            print("Save cached video error:\(error)")
        }
    }

    func processPendingRequests() {
        var completedRequests = [AVAssetResourceLoadingRequest]()

        for request in self.pendingRequests {

            if let info = request.contentInformationRequest, let dataRequest = request.dataRequest {
                self.fillInContentInformation(info)
                let didRespondCompletely = self.respondWithDataForRequest(dataRequest)

                if didRespondCompletely {
                    completedRequests.append(request)
                    request.finishLoading()
                }
            }
        }

        let pendingSet = Set(self.pendingRequests)
        let completedSet = Set(completedRequests)
        self.pendingRequests = Array(pendingSet.subtract(completedSet))
    }

    func fillInContentInformation(infoRequest: AVAssetResourceLoadingContentInformationRequest) {
        guard let response = self.response, let mimeType = response.MIMEType else {
            return
        }

        if let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, nil) {
            infoRequest.byteRangeAccessSupported = true
            infoRequest.contentType = contentType.takeRetainedValue() as String
            infoRequest.contentLength = response.expectedContentLength
        }
    }

    func respondWithDataForRequest(dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {

        var startOffset = dataRequest.requestedOffset

        if dataRequest.currentOffset != 0 {
            startOffset = dataRequest.currentOffset
        }

        guard let data = self.receivedData else {
            return false
        }

        guard Int64(data.length) >= startOffset else {
            return false
        }

        let unreadBytes = Int64(data.length) - startOffset
        let numberOfBytesToRespondWith = min(Int64(dataRequest.requestedLength), unreadBytes)

        dataRequest.respondWithData(data.subdataWithRange(NSMakeRange(Int(startOffset), Int(numberOfBytesToRespondWith))))

        let endOffset = startOffset + dataRequest.requestedLength
        let didRespondFully = data.length >= Int(endOffset);

        return didRespondFully
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

        let status = self.player.currentItem?.status
        if status == .ReadyToPlay
        {
           self.player.play()
        }
    }
}

