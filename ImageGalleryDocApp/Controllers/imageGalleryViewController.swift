//
//  imageGalleryCollectionViewController.swift
//  imageGallery
//
//  Created by 1C on 09/07/2022.
//

import UIKit

private let reuseIdentifier = "imageGalleryCell"

class imageGalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UIDropInteractionDelegate, UIGarbageViewDelegate {
        
    //MARK: - public API, Model
    
    var imageGallery: ImageGallery?
    var document: ImageGalleryDocument?
    
    //MARK: - Outlets
    
    @IBOutlet private weak var imageGalleryCollectionView: UICollectionView! {
        didSet{
            imageGalleryCollectionView.dataSource = self
            imageGalleryCollectionView.delegate = self
            imageGalleryCollectionView.dragDelegate = self
            imageGalleryCollectionView.dropDelegate = self
            imageGalleryCollectionView.dragInteractionEnabled = true
        }
    }
    
    @IBAction private func close(_ sender: UIBarButtonItem) {
        
        if document?.imageGallery != nil {
            
            if let firstImage = firstImage {
                document?.thumbnail = firstImage.snapshot
            } else {
                document?.thumbnail = imageGalleryCollectionView.snapshot
            }
                            
        }
        
        dismiss(animated: true) {
            self.document?.close()
        }
        
    }
            
    //MARK: - Controller Life Cycle
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let navBar = navigationController?.navigationBar {
            garbageView.frame = CGRect(x: navBar.frame.width * 0.7,
                                       y: 0,
                                       width: navBar.frame.width * 0.3,
                                       height: navBar.frame.height)
            
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: garbageView)
        }
                       
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoomCollectionView(_:)))
        view.addGestureRecognizer(pinch)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
//        let url = try? FileManager.default.url(for: .documentDirectory,
//                                          in: .userDomainMask,
//                                          appropriateFor: nil,
//                                          create: true).appendingPathComponent("Untitled.json")
//
//        if let jsonData = try? Data(contentsOf: url!) {
//            imageGallery = ImageGallery(jsonData: jsonData)
//        } else {
//            imageGallery = ImageGallery(title: "Gallery 1", images: [])
//        }
        if document?.documentState != .normal {
            document?.open { success in
                if success {
                    self.imageGallery = self.document?.imageGallery
                    self.title = self.document?.localizedName //self.imageGallery?.name
                    self.imageGalleryCollectionView.reloadData()
                } else {
                    self.imageGallery = ImageGallery(title: "Gallery", images: [])
                }
            }
        }
            
    }
        
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        flowLayout?.invalidateLayout()
    }
    
    // MARK: - Gesture recognizers implementation
    
    @objc private func zoomCollectionView(_ recognizer: UIPinchGestureRecognizer) {
        
        var scaleStart: CGFloat = 1
        
        switch recognizer.state {
        case .began:
            scaleStart = scaleFactor
        case .changed:
            
            scaleFactor = recognizer.scale * scaleStart
            flowLayout?.invalidateLayout()
            
        default:
            break
        }
        
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageGallery?.images.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                      for: indexPath)
        
        if let imageCell = cell as? imageGalleryCollectionViewCell, let url = imageGallery?.images[indexPath.item].url {
            imageCell.imageUrl = url.isFileURL ? makeRelativePath(with: url.lastPathComponent) : url
        }
    
        return cell
    }

    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        let width = min(((widthCollectionView - gapBetweenCells - gapBetweenLines)/Constants.columnCount) * scaleFactor, widthCollectionView * 0.95)

        let height = width / getAspectRatio(at: indexPath)
        
        return CGSize(width: width , height: height)

    }
      
    // MARK: - Drag delegate methods
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
       return getDragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        session.localContext = collectionView
        return getDragItems(at: indexPath)
    }
    
    // MARK: - Drop delegate methods of collection view
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        session.canLoadObjects(ofClass: NSURL.self) || session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        let isSelf = (session.localDragSession?.localContext) as? UICollectionView == imageGalleryCollectionView
        
        return UICollectionViewDropProposal(operation: isSelf ? .move : .copy, intent: .insertAtDestinationIndexPath)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        guard imageGallery != nil else {
            return
        }
        
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
               //local drop
                if let indexPath = item.dragItem.localObject as? IndexPath, let imageModel = imageGallery?.images[indexPath.item] {
                    imageGalleryCollectionView.performBatchUpdates({
                        imageGallery?.images.remove(at: sourceIndexPath.item)
                        imageGallery?.images.insert(imageModel, at: destinationIndexPath.item)
                        imageGalleryCollectionView.deleteItems(at: [sourceIndexPath])
                        imageGalleryCollectionView.insertItems(at: [destinationIndexPath])
                        self.saveChanges()
                    })
                }
                coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            } else {
                //it's drop from another app
                let placeHolder = UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath,
                                                                  reuseIdentifier: "imagePlaceHolder")
                
                placeHolder.cellUpdateHandler = { cell in
                    guard let placeHolderCell = cell as? ImagePlaceHolderCollectionViewCell else {
                        return
                    }
                    placeHolderCell.configureCell()
                }
                
                let placeHolderContext = coordinator.drop(item.dragItem,
                                                          to: placeHolder)
                                                
                var url: URL!
                var aspectRatio: Double!
                var imageForLocallyStore: UIImage!
                
                item.dragItem.itemProvider.loadObject(ofClass: UIImage.self){
                    [weak self] (provider, error) in
                    
                    if let image = provider as? UIImage {
                        
                        imageForLocallyStore = image
                        
                        if aspectRatio == nil {
                            aspectRatio = Double(image.size.width/image.size.height)
                        }
                        if url != nil {
                            self?.commitPlaceholder(placeHolderContext: placeHolderContext, with: url, with: aspectRatio)
                        }
                        
                    } else {
                        placeHolderContext.deletePlaceholder()
                    }
                }
                
                item.dragItem.itemProvider.loadObject(ofClass: NSURL.self) {
                    [weak self] (provider, error) in
                    
                    if let imageURL = (provider as? URL)?.imageURL {
                        
                        url = imageURL
                        
                        if url.isFileURL {
                            if let localUrl = self?.addFileToLocalStore(for: imageForLocallyStore) {
                                url = localUrl
                            } else {
                                aspectRatio = 2.0
                            }
                            self?.commitPlaceholder(placeHolderContext: placeHolderContext, with: url, with: aspectRatio)
                        } else if aspectRatio != nil {
                            self?.commitPlaceholder(placeHolderContext: placeHolderContext, with: url, with: aspectRatio)
                        }
                                                                        
                    } else {
                        placeHolderContext.deletePlaceholder()
                    }
                }
            }
        }
    }
        
    // MARK: - Navigation

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        switch identifier {
            case "showSingleImage":
                if isItLocalPath(for: sender) {
                    return false
                } else {
                    return true
                }
            default: return false
            }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if let identifier = segue.identifier {
            switch identifier {
            case "showSingleImage":
                if let cell = sender as? imageGalleryCollectionViewCell {
                    if let imageVC = segue.destination as? imageViewController,
                        let indexPath = imageGalleryCollectionView.indexPath(for: cell),
                        let url = imageGallery?.images[indexPath.item].url {
                        imageVC.imageURL = url.isFileURL ? makeRelativePath(with: url.lastPathComponent) : url
                        imageVC.title = imageGallery?.name
                    }
                }
            default:
                break
            }
        }
    }
    
    //MARK: - Garbage view delegate methods
    
    func didChangeDocument() {
        saveChanges()
    }
    
    func didUrlDelete(_ urls: [URL]) {
        urls.forEach { deleteFileFromLocalStore(for: $0) }
    }
    
    //MARK: - Private implementation
      
    private var firstImage: UIImageView? {
        (imageGalleryCollectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? imageGalleryCollectionViewCell)?.imageView
    }
    
    private func saveChanges() {
        guard let gallery = imageGallery else {return}
        
        document?.imageGallery = gallery
        document?.updateChangeCount(.done)
        
//        if let jsonData = gallery.json {
//            do {
//                try? jsonData.write(to: FileManager.default.url(for: .documentDirectory,
//                                                                in: .userDomainMask,
//                                                                appropriateFor: nil,
//                                                                create: true).appendingPathComponent("Untitled.json"))
//            } catch let error {
//                print("error: \(error)")
//            }
//        }
    }
    
    private lazy var garbageView: GarbageView = {
        let garbageView = GarbageView()
        garbageView.delegate = self
        return garbageView
    }()
    
    private func deleteFileFromLocalStore(for url: URL) {
        if let urlToDelete = makeRelativePath(with: url.lastPathComponent) {
            try? FileManager.default.removeItem(at: urlToDelete)
        }
    }
    
    private func addFileToLocalStore(for image: UIImage) -> URL? {
        
        let fileName = UUID().uuidString + ".jpg"
                
        let localUrl = makeRelativePath(with: fileName)

        if let url = localUrl, let data = image.jpegData(compressionQuality: 1) {
            let imageDidCreate = FileManager.default.createFile(atPath: url.path,
                                                               contents: data)
            return imageDidCreate ? url : nil
        } else {
            return nil
        }
        
    }
    
    private func makeRelativePath(with fileName: String) -> URL? {
        return try? FileManager.default.url(for: .documentDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil,
                                               create: true).appendingPathComponent(fileName)
            

    }
    
    private func getDragItems(at indexPath: IndexPath) -> [UIDragItem] {
        
        if let image = (imageGalleryCollectionView.cellForItem(at: indexPath) as? imageGalleryCollectionViewCell)?.imageView.image {
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: image))
            dragItem.localObject = indexPath//imageGallery?.images[indexPath.item]
            return [dragItem]
        } else {
            return []
        }
    }
    
    private var scaleFactor: CGFloat = 1
    
    private func isItLocalPath(for sender: Any?) -> Bool {
        if let cell = sender as? imageGalleryCollectionViewCell, let indexPath = imageGalleryCollectionView.indexPath(for: cell), let url = imageGallery?.images[indexPath.item].url, let _ = UIImage.urlToStoreLocallyAsJPEG(named: url.path) {
            return true
        }
        return false
    }
    
    private func commitPlaceholder(placeHolderContext: UICollectionViewDropPlaceholderContext, with url: URL, with aspectRatio: Double) {
        DispatchQueue.main.async { [weak self] in
            placeHolderContext.commitInsertion(dataSourceUpdates: {
                insertionIndexPath in
                let newImageModel = ImageGallery.ImageModel(url: url, aspecrRatio: aspectRatio)
                self?.imageGallery?.images.insert(newImageModel, at: insertionIndexPath.item)
                self?.saveChanges()
            })
        }
    }
    
    private var widthCollectionView: CGFloat {
        return imageGalleryCollectionView?.bounds.width ?? CGFloat.zero
    }
    
    private var gapBetweenCells: CGFloat {
        return (flowLayout?.minimumInteritemSpacing ?? CGFloat.zero) * CGFloat(2.0)
    }
    
    private var gapBetweenLines: CGFloat {
        return (flowLayout?.minimumLineSpacing ?? CGFloat.zero) * CGFloat(2.0)
    }
    
    private func getAspectRatio(at indexPath: IndexPath) -> CGFloat {
        CGFloat(imageGallery?.images[indexPath.item].aspecrRatio ?? 0)
    }
    
    private func getUrl(at indexPath: IndexPath) -> URL {
        imageGallery?.images[indexPath.item].url ?? URL(string: "")!
    }
    
    private var flowLayout: UICollectionViewFlowLayout? {
        return imageGalleryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    private struct Constants {
        static let columnCount:CGFloat = 2
    }
    
}
