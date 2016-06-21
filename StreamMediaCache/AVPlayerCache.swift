//
//  AVPlayerCache.swift
//  StreamMediaCache
//
//  Created by Andrii Kravchenko on 6/21/16.
//  Copyright © 2016 kievkao. All rights reserved.
//

import AVKit
import AVFoundation
import MobileCoreServices

class AVPlayerCache: NSObject, AVAssetResourceLoaderDelegate, NSURLSessionTaskDelegate {

    var player: AVPlayer?

    private let loader_queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
    private var dataTask: NSURLSessionDataTask?

    private lazy var session: NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
    }()

    private var pendingRequests = [AVAssetResourceLoadingRequest]()
    private var mediaData: NSMutableData?
    private var response: NSURLResponse?

    private let FakeScheme = "fakeScheme"
    private var initialUrlScheme: String?

    private static let DefaultDirectory = NSTemporaryDirectory()
    var cachedFilesDirectory: String = DefaultDirectory

    private(set) var cacheEnabled: Bool?
    private(set) var fileName: String?

    static func isCachedFileAvailable(directory directory: String = DefaultDirectory, fileName: String) -> Bool {
        return NSFileManager.defaultManager().fileExistsAtPath((directory as NSString).stringByAppendingPathComponent(fileName))
    }

    init(URL: NSURL, onlineCaching: Bool) {
        super.init()

        cacheEnabled = onlineCaching

        let components = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)!
        self.initialUrlScheme = components.scheme
        self.fileName = components.URL?.lastPathComponent
        components.scheme = FakeScheme

        let asset = AVURLAsset(URL: components.URL!)
        asset.resourceLoader.setDelegate(self, queue: dispatch_get_main_queue())

        let playerItem = AVPlayerItem(asset: asset)
        playerItem.addObserver(self, forKeyPath: "status", options: .New, context: nil)

        self.player = AVPlayer(playerItem: playerItem)
    }

    func play() {
        if let cache = cacheEnabled where cache == false || cacheEnabled == nil {
            self.player?.play()
        }
    }

    // MARK: AVAssetResourceLoaderDelegate

    func resourceLoader(resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {

        if self.dataTask == nil {
            if let urlComponents = NSURLComponents(URL: loadingRequest.request.URL!, resolvingAgainstBaseURL: false) {
                urlComponents.scheme = initialUrlScheme

                let request = NSURLRequest(URL: urlComponents.URL!)
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

    // MARK: NSURLSessionTaskDelegate

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        self.mediaData = NSMutableData()
        self.response = response

        self.processPendingRequests()

        completionHandler(.Allow)
    }

    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        self.mediaData?.appendData(data)

        self.processPendingRequests()
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        self.processPendingRequests()

        print("Data task is completed")
        let cachedFilePath = (self.cachedFilesDirectory as NSString).stringByAppendingPathComponent(self.fileName!)

        do {
            try self.mediaData?.writeToFile(cachedFilePath, options: .AtomicWrite)
        }
        catch let error {
            print("Save cached video error:\(error)")
        }
    }

    // MARK: Helpers

    func processPendingRequests() {
        var completedRequests = [AVAssetResourceLoadingRequest]()

        for request in self.pendingRequests {

            if let dataRequest = request.dataRequest {

                if let info = request.contentInformationRequest {
                    self.fillInContentInformation(info)
                }

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

        guard let data = self.mediaData else {
            return false
        }

        guard Int64(data.length) >= startOffset else {
            return false
        }

        let unreadBytes = Int64(data.length) - startOffset
        let numberOfBytesToRespondWith = min(Int64(dataRequest.requestedLength), unreadBytes)

        let respondData = data.subdataWithRange(NSMakeRange(Int(startOffset), Int(numberOfBytesToRespondWith)))
        dataRequest.respondWithData(respondData)

        let endOffset = startOffset + dataRequest.requestedLength
        let didRespondFully = data.length >= Int(endOffset);

        return didRespondFully
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        let status = self.player?.currentItem?.status
        if status == .ReadyToPlay
        {
            self.player?.play()
        }
        else {
            print("Error")
        }
    }
}
