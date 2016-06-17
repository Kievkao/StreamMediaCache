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

class ViewController: UIViewController {

    var player: AVPlayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        let playerItem = AVPlayerItem(URL: NSURL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!)
        self.player = AVPlayer(playerItem: playerItem)

        let playerController = AVPlayerViewController()
        playerController.player = player
        self.addChildViewController(playerController)
        self.view.addSubview(playerController.view)
        playerController.view.frame = self.view.frame
        
        player.play()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }
}

