//
//  AVPlayerCacheWrapper.swift
//  StreamMediaCache
//
//  Created by Andrii Kravchenko on 6/21/16.
//  Copyright © 2016 kievkao. All rights reserved.
//

import AVKit
import AVFoundation
import MobileCoreServices
import Foundation

protocol AVPlayerCacheWrapperDelegate: class {
    func cachingDidStartInPath(path: String)
    func cachingDidFinishInPath(path: String, withError: NSError)
}

class AVPlayerCacheWrapper: NSObject, AVAssetResourceLoaderDelegate, URLSessionTaskDelegate {

    var player: AVPlayer?
    var cachedFilesDirectory: String = DefaultDirectory
    weak var delegate: AVPlayerCacheWrapperDelegate?

    private var dataTask: URLSessionDataTask?

    private var session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.mainQueue)

    private var pendingRequests = [AVAssetResourceLoadingRequest]()
    private var mediaData: KAODataWrapper?
    private var response: URLResponse?

    private let FakeScheme = "fakeScheme"
    private var initialUrlScheme: String?

    private static let DefaultDirectory = NSTemporaryDirectory()

    private(set) var cacheEnabled: Bool?
    private(set) var fileName: String?

    private lazy var cachedFilePath: String = {
        guard let fileName = self.fileName else {
            print("Filename is nil, unable to cache media")
            return ""
        }
        return (self.cachedFilesDirectory as NSString).appendingPathComponent(fileName)
    }()

    static func isCachedFileAvailable(directory: String = DefaultDirectory, fileName: String) -> Bool {
        return FileManager.default.fileExists(atPath: (directory as NSString).appendingPathComponent(fileName))
    }

    init(URL: NSURL, onlineCaching: Bool) {
        super.init()

        cacheEnabled = onlineCaching

        if onlineCaching {
            let components = NSURLComponents(url: URL as URL, resolvingAgainstBaseURL: true)!
            self.initialUrlScheme = components.scheme
            self.fileName = components.url?.lastPathComponent
            components.scheme = FakeScheme

            let asset = AVURLAsset(url: components.url!)
            asset.resourceLoader.setDelegate(self, queue: DispatchQueue.main)

            let playerItem = AVPlayerItem(asset: asset)
            playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)

            self.player = AVPlayer(playerItem: playerItem)
        }
        else {
            self.player = AVPlayer(url: URL as URL)
        }
    }

    func play() {
        if let cache = cacheEnabled , cache == false || cacheEnabled == nil {
            self.player?.play()
        }
    }

    // MARK: AVAssetResourceLoaderDelegate

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {

        if self.dataTask == nil {
            if let urlComponents = NSURLComponents(url: loadingRequest.request.url!, resolvingAgainstBaseURL: false) {
                urlComponents.scheme = initialUrlScheme

                let request = NSURLRequest(url: urlComponents.url!)
                self.dataTask = self.session.dataTask(with: request as URLRequest)
                self.dataTask?.resume()
            }
        }

        self.pendingRequests.append(loadingRequest)

        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        self.pendingRequests = self.pendingRequests.filter{$0 != loadingRequest}
    }

    // MARK: NSURLSessionTaskDelegate

    private func URLSession(session: URLSession, dataTask: URLSessionDataTask, didReceiveResponse response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        self.mediaData = KAODataWrapper()
        self.response = response

        self.processPendingRequests()

        completionHandler(.allow)
    }

    func URLSession(session: URLSession, dataTask: URLSessionDataTask, didReceiveData data: NSData) {
        self.mediaData?.appendData(data: data)

        do {
            try self.mediaData?.writeToFile(path: cachedFilePath, options: .atomicWrite)
        }
        catch let error {
            print("Save cached video error:\(error)")
        }

        self.processPendingRequests()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.processPendingRequests()

        print("Data task is completed")
    }

    // MARK: Helpers

    func processPendingRequests() {
        var completedRequests = [AVAssetResourceLoadingRequest]()

        for request in self.pendingRequests {

            if let dataRequest = request.dataRequest {

                if let info = request.contentInformationRequest {
                    self.fillInContentInformation(infoRequest: info)
                }

                let didRespondCompletely = self.respondWithDataForRequest(dataRequest: dataRequest)

                if didRespondCompletely {
                    completedRequests.append(request)
                    request.finishLoading()
                }
            }
        }

        let pendingSet = Set(self.pendingRequests)
        let completedSet = Set(completedRequests)
        self.pendingRequests = Array(pendingSet.subtracting(completedSet))
    }

    func fillInContentInformation(infoRequest: AVAssetResourceLoadingContentInformationRequest) {
        guard let response = self.response, let mimeType = response.mimeType else {
            return
        }

        if let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil) {
            infoRequest.isByteRangeAccessSupported = true
            infoRequest.contentType = contentType.takeRetainedValue() as String
            infoRequest.contentLength = response.expectedContentLength
        }
    }

    func respondWithDataForRequest(dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {

        var startOffset = dataRequest.requestedOffset

        if dataRequest.currentOffset != 0 {
            startOffset = dataRequest.currentOffset
        }

        guard let data = self.mediaData , Int64(data.length) >= startOffset else {
            return false
        }

        let unreadBytes = Int64(data.length) - startOffset
        let numberOfBytesToRespondWith = min(Int64(dataRequest.requestedLength), unreadBytes)

        let respondData = data.subdataWithRange(range: NSMakeRange(Int(startOffset), Int(numberOfBytesToRespondWith)))
        dataRequest.respond(with: respondData as Data)

        let endOffset = startOffset + dataRequest.requestedLength
        let didRespondFully = data.length >= Int(endOffset);

        return didRespondFully
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let status = self.player?.currentItem?.status
        if status == .readyToPlay
        {
            self.player?.play()
        }
        else {
            print("Error")
        }
    }
}
