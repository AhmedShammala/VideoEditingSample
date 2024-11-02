//
//  ViewController.swift
//  VideoEditingSample
//
//  Created by aHmeD on 02/11/2024.
//

import UIKit

import UIKit
import AVFoundation
import CoreImage
import PhotosUI


class ViewController: UIViewController {

    // UI Elements
    private var videoPlayerView: UIView!
    private var loadButton: UIButton!
    private var filterButton: UIButton!
    private var startSlider: UISlider!
    private var endSlider: UISlider!
    
    // Video Player and Filter
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoAsset: AVAsset?
    private var videoURL: URL?
    private var filterApplied = false
    private let filter = CIFilter(name: "CIPhotoEffectMono") // Grayscale filter

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        videoPlayerView = UIView(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: 300))
        view.addSubview(videoPlayerView)

        loadButton = UIButton(type: .system)
        loadButton.setTitle("Load Video", for: .normal)
        loadButton.addTarget(self, action: #selector(loadVideo), for: .touchUpInside)
        loadButton.frame = CGRect(x: 20, y: 470, width: 100, height: 40)
        view.addSubview(loadButton)

        filterButton = UIButton(type: .system)
        filterButton.setTitle("Toggle Filter", for: .normal)
        filterButton.addTarget(self, action: #selector(toggleFilter), for: .touchUpInside)
        filterButton.frame = CGRect(x: 140, y: 470, width: 120, height: 40)
        view.addSubview(filterButton)

        startSlider = UISlider(frame: CGRect(x: 20, y: 550, width: view.bounds.width - 40, height: 30))
        startSlider.minimumValue = 0
        startSlider.maximumValue = 1
        startSlider.value = 0
        startSlider.addTarget(self, action: #selector(playTrimmedVideo), for: .valueChanged)
        view.addSubview(startSlider)

        endSlider = UISlider(frame: CGRect(x: 20, y: 590, width: view.bounds.width - 40, height: 30))
        endSlider.minimumValue = 0
        endSlider.maximumValue = 1
        endSlider.value = 1
        endSlider.addTarget(self, action: #selector(playTrimmedVideo), for: .valueChanged)
        view.addSubview(endSlider)
    }
    
    // Load video from gallery
    @objc private func loadVideo() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.mediaTypes = ["public.movie"]
        present(picker, animated: true)
    }

    // Toggle grayscale filter
    @objc private func toggleFilter() {
        filterApplied.toggle()
        playTrimmedVideo()
    }

    @objc private func playTrimmedVideo() {
        guard let videoURL = videoURL else { return }
        
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.seconds
        let startTime = CMTime(seconds: duration * Double(startSlider.value), preferredTimescale: 600)
        let endTime = CMTime(seconds: duration * Double(endSlider.value), preferredTimescale: 600)

        // Trim the video asset
        let composition = AVMutableComposition()
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        
        let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try? videoCompositionTrack?.insertTimeRange(CMTimeRange(start: startTime, end: endTime), of: track, at: .zero)

        // Get the preferred transform for orientation
        let transform = track.preferredTransform
        let isPortrait = transform.a == 0 && transform.d == 0
        let isLandscapeLeft = transform.b == 1.0 && transform.c == -1.0
        let isLandscapeRight = transform.b == -1.0 && transform.c == 1.0

        // Apply filter if enabled
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let source = request.sourceImage
            let outputImage = self.filterApplied ? source.applyingFilter("CIPhotoEffectMono") : source
            request.finish(with: outputImage, context: nil)
        }
        videoComposition.renderSize = track.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS

        // Prepare player
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition
        player = AVPlayer(playerItem: playerItem)

        // Add player layer
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = videoPlayerView.bounds
        videoPlayerView.layer.addSublayer(playerLayer!)

        // Adjust player layer's transform based on video orientation
        if isPortrait {
            playerLayer?.transform = CATransform3DMakeRotation(.pi / 2, 0, 0, 1)
        } else if isLandscapeLeft {
            playerLayer?.transform = CATransform3DMakeRotation(.pi, 0, 0, 1)
        } else if isLandscapeRight {
            playerLayer?.transform = CATransform3DMakeRotation(0, 0, 0, 1)
        }

        // Start playback
        player?.seek(to: .zero)
        player?.play()
    }

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        dismiss(animated: true)
        
        if let videoURL = info[.mediaURL] as? URL {
            self.videoURL = videoURL  // Store the URL
            videoAsset = AVURLAsset(url: videoURL)  // Create the asset from the URL
            playTrimmedVideo()
        }
    }
}
