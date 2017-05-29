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
import MBProgressHUD

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
    
    //TableView's datasource Array of tuples:(identifier, item)
    var itemArray:[(String, AVPlayerItem)] = []
    var urlArray:[URL] = []
    //keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    
    let refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //pull-down-to-refresh support
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull down to reload books")
        self.refreshControl.addTarget(self, action: #selector(loadFiles), for: .valueChanged)
        self.tableView.addSubview(self.refreshControl)
        
        //enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self
        
        //fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()
        
        //set colors
        self.navigationController?.navigationBar.barTintColor = UIColor.flatSkyBlue()
        self.footerView.backgroundColor = UIColor.flatSkyBlue()
        self.footerView.isHidden = true
        
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
        
        //register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.loadFiles), name: Notification.Name.AudiobookPlayer.openURL, object: nil)
        
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
        //load local files
        let loadingWheel = MBProgressHUD.showAdded(to: self.view, animated: true)
        loadingWheel?.labelText = "Loading Books"
        
        //get reference of all the files located inside the Documents folder
        guard let fileEnumerator = FileManager.default.enumerator(atPath: self.documentsPath) else {
            return
        }
        var filenameArray = fileEnumerator.map({ return $0}) as! [String]
        //iterate and process files
        
        DispatchQueue.global().async {
            self.process(&filenameArray, loadingWheel: loadingWheel!)
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            }
        }
    }
    
    func process(_ files:inout [String], loadingWheel: MBProgressHUD){
        if files.count == 0 {
            return
        }
        
        let filename = files.removeFirst()
        
        if filename  == "Inbox" {
            return self.process(&files, loadingWheel: loadingWheel)
        }
        
        let documentsURL = URL(fileURLWithPath: self.documentsPath)
        
        // which should return valid url strings
        let fileURL = documentsURL.appendingPathComponent(filename)
        loadingWheel.detailsLabelText = fileURL.lastPathComponent
        
        //if file already in list, skip to next one
        if self.urlArray.contains(fileURL) {
            return self.process(&files, loadingWheel: loadingWheel)
        }
        
        //autoreleasepool needed to avoid OOM crashes from the file manager
        autoreleasepool { () -> () in
            let hash = fileURL.lastPathComponent
            
            //NOTE: AVPlayerItem from URL might not be ready right away,
            //		it might be better to create it from a AVAsset
            //create AVPlayerItem to better access each files' metadata
            let item = AVPlayerItem(url: fileURL)
            self.itemArray.append((hash, item))
            self.urlArray.append(fileURL)
            
            //migrate keys
            let title = (AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyTitle, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? String ?? "Unknown Book").replacingOccurrences(of: " ", with: "_")
            
            let author = (AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyArtist, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? String ?? "Unknown Author").replacingOccurrences(of: " ", with: "_")
            
            let identifier = title+author
            
            let storedTime = UserDefaults.standard.integer(forKey: hash) // 0 for nil
            let currentTime = UserDefaults.standard.integer(forKey: identifier)
            
            if storedTime == 0 && currentTime != 0 {
                //store values in new key
                UserDefaults.standard.set(currentTime, forKey: hash)
                //remove previous values
                UserDefaults.standard.removeObject(forKey: identifier)
            }
            
            if let currentPercentage = UserDefaults.standard.string(forKey: identifier+"_percentage") {
                UserDefaults.standard.set(currentPercentage, forKey: hash+"_percentage")
                UserDefaults.standard.removeObject(forKey: identifier+"_percentage")
            }

        }
        
        DispatchQueue.main.async {
            //show/hide instructions view
            self.emptyListContainerView.isHidden = self.itemArray.count > 0 ? true : false
            self.tableView.reloadData()
        }
        
        return self.process(&files, loadingWheel: loadingWheel)
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
    
    @IBAction func didPressShowSettings(_ sender: UIBarButtonItem) {
        print("showing settings")
    }
    
}

extension ListBooksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as! BookCellView
        
        let item = self.itemArray[indexPath.row].1

        // use the file name if the title can't be read from metadata
        let alternateTitle = self.urlArray[indexPath.row].lastPathComponent
        
        cell.titleLabel.text = AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyTitle, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? String ?? alternateTitle

        cell.titleLabel.highlightedTextColor = UIColor.black
        
        cell.authorLabel.text = AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyArtist, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? String ?? "Unknown Author"
        
        var defaultImage:UIImage!
        if let artwork = AVMetadataItem.metadataItems(from: item.asset.metadata, withKey: AVMetadataCommonKeyArtwork, keySpace: AVMetadataKeySpaceCommon).first?.value?.copy(with: nil) as? Data {
            defaultImage = UIImage(data: artwork)
        }else{
            defaultImage = UIImage()
        }
        
        //NOTE: we should have a default image for artwork
        cell.artworkImageView.image = defaultImage
        
        //load stored percentage value
        cell.completionLabel.text = UserDefaults.standard.string(forKey: self.itemArray[indexPath.row].0+"_percentage") ?? "0%"
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
            
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
            
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
        if playerVC.playerItem != item.1 {
            audioPlayer.stop()
            //replace player with new one
            self.loadPlayer(item, url: url, cell: cell, indexPath: indexPath)
            return
        }
        
        //show the current player
        self.navigationController?.pushViewController(playerVC, animated: true)
    }
    
    func loadPlayer(_ item:(String, AVPlayerItem), url:URL, cell:BookCellView, indexPath:IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        self.playerViewController = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController
        
        self.playerViewController?.identifier = item.0
        self.playerViewController?.playerItem = item.1
        
        let url = self.urlArray[indexPath.row]
        self.playerViewController!.fileURL = url
        
        let title = cell.titleLabel.text ?? "Unknown Book"
        let author = cell.authorLabel.text ?? "Unknown Author"
        
        self.footerView.isHidden = false
        
        self.footerTitleLabel.text = title + " - " + author
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
            
            providerList.popoverPresentationController?.sourceView = self.view
            providerList.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
            self.present(providerList, animated: true, completion: nil)
        }
        
        let airdropButton = UIAlertAction(title: "AirDrop", style: .default) { (action) in
            self.showAlert("AirDrop", message: "Make sure AirDrop is enabled.\n\nOnce you transfer the file to your device via AirDrop, choose 'BookPlayer' from the app list that will appear", style: .alert)
        }
        
        sheet.addAction(localButton)
        sheet.addAction(airdropButton)
        sheet.addAction(cancelButton)
        
        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
        
        self.present(sheet, animated: true, completion: nil)
    }
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        //show document picker
        documentPicker.delegate = self;
        
        documentPicker.popoverPresentationController?.sourceView = self.view
        documentPicker.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
        self.present(documentPicker, animated: true, completion: nil)
    }
}

extension ListBooksViewController:UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        
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
        
        do {
            try FileManager.default.moveItem(at: url, to: fileURL)
        }catch{
            self.showAlert("Error", message: "File import fail, try again later", style: .alert)
            return
        }
        
        self.loadFiles()
    }
}

class BookCellView: UITableViewCell {
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var completionLabel: UILabel!
    
}
