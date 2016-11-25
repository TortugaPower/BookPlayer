//
//  ListBooksViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import Chameleon

class ListBooksViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var emptyListContainerView: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerImageView: UIImageView!
    @IBOutlet weak var footerTitleLabel: UILabel!
    @IBOutlet weak var footerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerPlayButton: UIButton!
    
    //keep in memory images to toggle play/pause
    let miniPlayImage = UIImage(named: "miniPlayButton")
    let miniPauseButton = UIImage(named: "miniPauseButton")
    
    //keep reference to player to know if there's an book loaded
    var playerViewController:PlayerViewController?
    
    var listBooks:[String] = []
    
    //TableView's datasource
    var itemArray:[AVPlayerItem] = []
    var urlArray:[URL] = []
    //keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self
        
        //fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()

        //set colors
        self.navigationController?.navigationBar.barTintColor = UIColor.flatSkyBlue()
        self.footerView.backgroundColor = UIColor.flatSkyBlue()
        
        self.tableView.tableFooterView = UIView()
        
        //set external control listeners
        let skipForward = MPRemoteCommandCenter.shared().skipForwardCommand
        skipForward.isEnabled = true
        skipForward.addTarget(self, action: #selector(self.forwardPressed(_:)))
        skipForward.preferredIntervals = [30]
        
        let skipRewind = MPRemoteCommandCenter.shared().skipBackwardCommand
        skipRewind.isEnabled = true
        skipRewind.addTarget(self, action: #selector(self.rewindPressed(_:)))
        skipRewind.preferredIntervals = [30]
        
        let playCommand = MPRemoteCommandCenter.shared().playCommand
        playCommand.isEnabled = true
        playCommand.addTarget(self, action: #selector(self.didPressPlay(_:)))
        
        let pauseCommand = MPRemoteCommandCenter.shared().pauseCommand
        pauseCommand.isEnabled = true
        pauseCommand.addTarget(self, action: #selector(self.didPressPlay(_:)))
        
        //set tap handler to show detail on tap on footer view
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didPressShowDetail(_:)))
        self.footerView.addGestureRecognizer(tapRecognizer)
        
        //register to audio-interruption notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioInterruptions(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)
        
        //load local files
        self.loadFiles()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //show navigation bar for this controller
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        //check if audiobook is loaded
        guard let _ = self.playerViewController else {
            self.footerHeightConstraint.constant = 0
            return
        }
        
        //resize footer view
        self.footerHeightConstraint.constant = 55
        
        self.setPlayImage()
        
        //reload selected cell to show accurate percentage label
        guard let index = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        self.tableView.reloadRows(at: [index], with: .automatic)
    }
    
    //no longer need to deregister observers for iOS 9+!
    //https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        //for iOS 8
        NotificationCenter.default.removeObserver(self)
    }
    
    //Playback may be interrupted by calls. Handle pause
    func handleAudioInterruptions(_ notification:Notification){
        guard let playerVC = self.playerViewController, let audioPlayer = playerVC.audioPlayer else {
            return
        }
        if audioPlayer.isPlaying {
            self.didPressPlay(self.footerPlayButton)
        }
    }
    
    /**
     *  Load local files and process them (rename them if necessary)
     *  Spaces in file names can cause side effects when trying to load the data
     */
    func loadFiles() {
        self.itemArray = []
        self.urlArray = []
        
        //get reference of all the files located inside the Documents folder
        let fileEnumerator = FileManager.default.enumerator(atPath: self.documentsPath)!
        
        //iterate and process files
        for filename in fileEnumerator {
            var finalPath = self.documentsPath+"/"+(filename as! String)
            
            var originalURL:URL?
            
            if finalPath.contains(" ") {
                originalURL = URL(fileURLWithPath: finalPath)
                finalPath = finalPath.replacingOccurrences(of: " ", with: "_")
            }
            
            let fileURL = URL(fileURLWithPath: finalPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)
            
            if let original = originalURL {
                try! FileManager.default.moveItem(at: original, to: fileURL)
            }
            
            //NOTE: AVPlayerItem from URL might not be ready right away, 
            //		it might be better to create it from a AVAsset
            
            //create AVPlayerItem to better access each files' metadata
            self.itemArray.append(AVPlayerItem(url: fileURL))
            self.urlArray.append(fileURL)
        }
        
        //show/hide instructions view
        self.emptyListContainerView.isHidden = self.itemArray.count > 0 ? true : false
        
        self.tableView.reloadData()
    }
    
    /**
     * Set play or pause image on button
     */
    func setPlayImage(){
        guard let playerVC = self.playerViewController, let audioPlayer = playerVC.audioPlayer else{
            self.footerPlayButton.setImage(self.miniPlayImage, for: UIControlState())
            return
        }
        
        if audioPlayer.isPlaying {
            self.footerPlayButton.setImage(self.miniPauseButton, for: UIControlState())
        }else{
            self.footerPlayButton.setImage(self.miniPlayImage, for: UIControlState())
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if(navigationController!.viewControllers.count > 1){
            return true
        }
        return false
    }
    @IBAction func didPressReload(_ sender: UIBarButtonItem) {
        self.loadFiles()
    }
    
    @IBAction func didPressPlay(_ sender: UIButton) {
        //check if audiobook is loaded
        guard let playerVC = self.playerViewController else {
            return
        }
        
        playerVC.playPressed(playerVC.playButton)
        
        self.setPlayImage()
    }
    
    func forwardPressed(_ sender: UIButton) {
        //check if audiobook is loaded
        guard let playerVC = self.playerViewController else {
            return
        }
        
        playerVC.forwardPressed(sender)
    }
    
    func rewindPressed(_ sender: UIButton) {
        //check if audiobook is loaded
        guard let playerVC = self.playerViewController else {
            return
        }
        
        playerVC.rewindPressed(sender)
    }
    
    @IBAction func didPressShowDetail(_ sender: UIButton) {
        guard let playerVC = self.playerViewController else {
            return
        }
        self.navigationController?.show(playerVC, sender: self)
    }
}

extension ListBooksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as! BookCellView
        
        let item = self.itemArray[indexPath.row]
        
        cell.titleLabel.text = AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyTitle, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? String
        cell.titleLabel.highlightedTextColor = UIColor.black
        
        cell.authorLabel.text = AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyArtist, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? String
      
        var defaultImage:UIImage!
        if let artwork = AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyArtwork, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? Data {
            defaultImage = UIImage(data: artwork)
        }else{
            defaultImage = UIImage()
        }
        
        //NOTE: we should have a default image for artwork
        cell.artworkImageView.image = defaultImage
        
        let title = cell.titleLabel.text?.replacingOccurrences(of: " ", with: "_") ?? "defaulttitle"
        let author = cell.authorLabel.text?.replacingOccurrences(of: " ", with: "_") ?? "defaultauthor"
        
        //load stored percentage value
        cell.completionLabel.text = UserDefaults.standard.string(forKey: title+author+"_percentage") ?? "0%"
        cell.completionLabel.textColor = UIColor.flatGreenColorDark()
        
        return cell
    }
}

extension ListBooksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (action, indexPath) in
            let alert = UIAlertController(title: "Confirmation", message: "Are you sure you would like to remove this audiobook?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in
                tableView.setEditing(false, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
                self.itemArray.remove(at: indexPath.row)
                let url = self.urlArray.remove(at: indexPath.row)
                try! FileManager.default.removeItem(at: url)
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .none)
                tableView.endUpdates()
                
                self.emptyListContainerView.isHidden = self.itemArray.count > 0 ? true : false
            }))
            
            self.present(alert, animated: true, completion: nil)
        }
        
        deleteAction.backgroundColor = UIColor.red
        
        return [deleteAction]
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let index = tableView.indexPathForSelectedRow else {
            return indexPath
        }
        
        tableView.deselectRow(at: index, animated: true)
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let item = self.itemArray[indexPath.row]
        let url = self.urlArray[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath) as! BookCellView
        
        guard let playerVC = self.playerViewController, let audioPlayer = playerVC.audioPlayer else {
            //create new player
            self.loadPlayer(item, url: url, cell: cell, indexPath: indexPath)
            return
        }
        
        //check if player is for a different book
        if playerVC.playerItem != item {
            audioPlayer.stop()
            //replace player with new one
            self.loadPlayer(item, url: url, cell: cell, indexPath: indexPath)
            return
        }
        
        //show the current player
        self.navigationController?.pushViewController(playerVC, animated: true)
    }
    
    func loadPlayer(_ item:AVPlayerItem, url:URL, cell:BookCellView, indexPath:IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        self.playerViewController = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController
        
        self.playerViewController!.playerItem = item
        
        let url = self.urlArray[indexPath.row]
        self.playerViewController!.fileURL = url
        
        self.footerTitleLabel.text = cell.titleLabel.text! + " - " + cell.authorLabel.text!
        self.footerImageView.image = cell.artworkImageView.image
        
        self.navigationController?.pushViewController(self.playerViewController!, animated: true)
    }
}

extension ListBooksViewController:UIDocumentMenuDelegate {
    @IBAction func didPressImportOptions(_ sender: UIBarButtonItem) {
        let sheet = UIAlertController(title: "Import Books", message: nil, preferredStyle: .actionSheet)
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let localButton = UIAlertAction(title: "From Local Apps", style: .default) { (action) in
            let providerList = UIDocumentMenuViewController(documentTypes: ["public.audio"], in: .import)
            providerList.delegate = self;
            
            self.present(providerList, animated: true, completion: nil)
        }
        
        sheet.addAction(localButton)
        sheet.addAction(cancelButton)
        
        self.present(sheet, animated: true, completion: nil)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        //show document picker
        documentPicker.delegate = self;
        self.present(documentPicker, animated: true, completion: nil)
    }
}

extension ListBooksViewController:UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        print("file picked: \(url)")
        
        //Documentation states that the file might not be imported due to being accessed from somewhere else
        do {
            try FileManager.default.attributesOfItem(atPath: url.path)
        }catch{
            self.showAlert("Error", message: "File import fail, try again later", style: .alert)
            return
        }
        
        let trueName = url.lastPathComponent
        var finalPath = self.documentsPath+"/"+(trueName)
        
        if trueName.contains(" ") {
            finalPath = finalPath.replacingOccurrences(of: " ", with: "_")
        }
        
        let fileURL = URL(fileURLWithPath: finalPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)
        
        try! FileManager.default.moveItem(at: url, to: fileURL)
        
        self.loadFiles()
    }
}

class BookCellView: UITableViewCell {
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var completionLabel: UILabel!
    
}
