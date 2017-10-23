//
//  ListBooksViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer
import Chameleon
import MBProgressHUD
import DeckTransition

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
    
    //TableView's datasource
    var bookArray = [Book]()
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
        
        //register for percentage change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)
        
        //register for book end notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookEnd(_:)), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        
        //register for remote events
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        self.loadFiles()
        self.footerHeightConstraint.constant = 0
    }
    
    //no longer need to deregister observers for iOS 9+!
    //https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        //for iOS 8
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    //Playback may be interrupted by calls. Handle pause
    func handleAudioInterruptions(_ notification:Notification){
        
        guard let audioPlayer = PlayerManager.sharedInstance.audioPlayer else {
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
        
        DataManager.loadBooks { (books) in
            self.bookArray = books
            self.refreshControl.endRefreshing()
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            
            //show/hide instructions view
            self.emptyListContainerView.isHidden = !self.bookArray.isEmpty
            self.tableView.reloadData()
        }
    }
    
    /**
     * Set play or pause image on button
     */
    func setPlayImage(){
        if PlayerManager.sharedInstance.isPlaying() {
            self.footerPlayButton.setImage(self.miniPauseButton, for: UIControlState())
        }else{
            self.footerPlayButton.setImage(self.miniPlayImage, for: UIControlState())
        }
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
        PlayerManager.sharedInstance.playPressed()
        self.setPlayImage()
    }
    
    func forwardPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.forwardPressed()
    }
    
    func rewindPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.rewindPressed()
    }
    
    @IBAction func didPressShowDetail(_ sender: UIButton) {
        guard let indexPath = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        self.tableView(self.tableView, didSelectRowAt: indexPath)
    }
    
    //percentage callback
    func updatePercentage(_ notification:Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let percentageString = userInfo["percentageString"] as? String else {
                return
        }
        
        guard let index = (self.bookArray.index { (book) -> Bool in
            return book.fileURL == fileURL
        }) else {
            return
        }

        let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as! BookCellView

        cell.completionLabel.text = percentageString
    }
    
    func bookEnd(_ notification:Notification) {
        self.setPlayImage()
    }
}

extension ListBooksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.bookArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as! BookCellView
        
        let book = self.bookArray[indexPath.row]
        
        cell.titleLabel.text = book.title
        cell.titleLabel.highlightedTextColor = UIColor.black
        cell.authorLabel.text = book.author
        
        //NOTE: we should have a default image for artwork
        cell.artworkImageView.image = book.artwork
        
        //load stored percentage value
        cell.completionLabel.text = UserDefaults.standard.string(forKey: self.bookArray[indexPath.row].identifier + "_percentage") ?? "0%"
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
                let book = self.bookArray.remove(at: indexPath.row)
                try! FileManager.default.removeItem(at: book.fileURL)
                
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .none)
                tableView.endUpdates()
                
                self.emptyListContainerView.isHidden = !self.bookArray.isEmpty
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
        let book = self.bookArray[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath) as! BookCellView
        
        let title = cell.titleLabel.text ?? book.fileURL.lastPathComponent
        let author = cell.authorLabel.text ?? "Unknown Author"
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as! PlayerViewController
        playerVC.currentBook = book
        let transitionDelegate = DeckTransitioningDelegate()
        playerVC.transitioningDelegate = transitionDelegate
        playerVC.modalPresentationStyle = .custom
        
        //show the current player
        present(playerVC, animated: true) {
            self.footerView.isHidden = false
            self.footerTitleLabel.text = title + " - " + author
            self.footerImageView.image = cell.artworkImageView.image
            self.footerHeightConstraint.constant = 55
            self.setPlayImage()
        }
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

extension ListBooksViewController {
    override func remoteControlReceived(with event: UIEvent?) {
        guard let event = event else {
            return
        }
        
        //TODO: after decoupling AVAudioPlayer from the PlayerViewController 
        switch event.subtype {
        case .remoteControlTogglePlayPause:
            print("toggle play/pause")
            
        case .remoteControlBeginSeekingBackward:
            print("seeking backward")
        case .remoteControlEndSeekingBackward:
            print("end seeking backward")
        case .remoteControlBeginSeekingForward:
            print("seeking forward")
        case .remoteControlEndSeekingForward:
            print("end seeking forward")
        
        case .remoteControlPause:
            print("control pause")
        case .remoteControlPlay:
            print("control play")
        case .remoteControlStop:
            print("stop")
            
        case .remoteControlNextTrack:
            print("next track")
        case .remoteControlPreviousTrack:
            print("previous track")
        default:
            print(event.description)
        }
    }
}

class BookCellView: UITableViewCell {
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var completionLabel: UILabel!
    
}
