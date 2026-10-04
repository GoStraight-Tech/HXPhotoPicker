//
//  PhotoPreviewSelectedView.swift
//  HXPhotoPicker
//
//  Created by Slience on 2020/12/29.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit

protocol PhotoPreviewSelectedViewDelegate: AnyObject {
    func selectedView(_ selectedView: PhotoPreviewSelectedView, didSelectItemAt photoAsset: PhotoAsset)
    func selectedView(_ selectedView: PhotoPreviewSelectedView, moveItemAt fromIndex: Int, toIndex: Int)
    func selectedView(_ selectedView: PhotoPreviewSelectedView, didDeleteItemAt photoAsset: PhotoAsset)
}

class PhotoPreviewSelectedView: UIView,
                                UICollectionViewDataSource,
                                UICollectionViewDelegate,
                                UICollectionViewDelegateFlowLayout {
    
    weak var delegate: PhotoPreviewSelectedViewDelegate?
    
    var collectionViewLayout: UICollectionViewFlowLayout!
    var collectionView: UICollectionView!
    var tickColor: UIColor?
    var shadeView: UIView!
    var shadeMaskLayer: CAGradientLayer!
    
    var contentOffset: CGPoint {
        get {
            collectionView.contentOffset
        }
        set {
            let minOffsetX: CGFloat = 0
            let maxOffsetX = max(0, collectionView.contentSize.width - collectionView.width)
            collectionView.contentOffset = .init(x: min(maxOffsetX, max(minOffsetX, newValue.x)), y: newValue.y)
        }
    }
    
    var isPhotoList: Bool = false
    var allowDrop: Bool = true
    var assetCount: Int { photoAssetArray.count }
    
    var photoAssetArray: [PhotoAsset] = []
    private var currentSelectedIndexPath: IndexPath?
    private let lock = NSLock()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumLineSpacing = 5
        collectionViewLayout.minimumInteritemSpacing = 5
        collectionView = HXCollectionView(frame: bounds, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            collectionView.dragDelegate = self
            collectionView.dropDelegate = self
            collectionView.dragInteractionEnabled = true
        }
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        }
        reloadSectionInset()
        
        shadeView = UIView()
        shadeView.addSubview(collectionView)
        shadeMaskLayer = CAGradientLayer()
        if #available(iOS 26.0, *), !PhotoManager.isIos26Compatibility  {
            shadeMaskLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
            shadeMaskLayer.locations = [0.0, 0.075, 0.925, 1.0]
            shadeView.layer.mask = shadeMaskLayer
        }
        addSubview(shadeView)
    }
    
    var leftMargin: CGFloat {
        if let splitViewController = viewController?.splitViewController as? PhotoSplitViewController,
           !UIDevice.isPortrait,
           !UIDevice.isPad {
            if !splitViewController.isSplitShowColumn {
                return UIDevice.leftMargin
            }else {
                return 0
            }
        }else {
            return UIDevice.leftMargin
        }
    }
        
    func reloadSectionInset() {
        if x == 0 {
            collectionViewLayout.sectionInset.top = 10
            collectionViewLayout.sectionInset.bottom = 5
            var leftInset: CGFloat
            var rightInset: CGFloat
            if leftMargin > 0 {
                leftInset = leftMargin
            }else {
                leftInset = 12
            }
            if UIDevice.rightMargin > 0 {
                rightInset = UIDevice.rightMargin
            }else {
                rightInset = 12
            }
            if #available(iOS 26.0, *), !PhotoManager.isIos26Compatibility {
                if leftMargin > 0 {
                    leftInset += 12
                }else {
                    leftInset += 8
                }
                if UIDevice.rightMargin > 0 {
                    rightInset += 12
                }else {
                    rightInset += 8
                }
            }
            collectionViewLayout.sectionInset.left = leftInset
            collectionViewLayout.sectionInset.right = rightInset
        }
    }
    func reloadData(photoAssets: [PhotoAsset]) {
        isHidden = photoAssets.isEmpty
        photoAssetArray = photoAssets
        collectionView.reloadData()
    }
    func reloadData(photoAsset: PhotoAsset) {
        guard let index = photoAssetArray.firstIndex(of: photoAsset) else {
            return
        }
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        if isPhotoList {
           return
        }
        collectionView.selectItem(
            at: currentSelectedIndexPath,
            animated: false,
            scrollPosition: .centeredHorizontally
        )
    }
    
    func insertPhotoAsset(
        photoAsset: PhotoAsset,
        animations: (() -> Void)? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        let beforeIsEmpty = photoAssetArray.isEmpty
        let item = photoAssetArray.count
        let indexPath = IndexPath(item: item, section: 0)
        if beforeIsEmpty {
            photoAssetArray.append(photoAsset)
            collectionView.reloadData()
        }else {
            collectionView.performBatchUpdates {
                self.photoAssetArray.append(photoAsset)
                self.collectionView.insertItems(at: [indexPath])
            }
        }
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
        currentSelectedIndexPath = indexPath
        if beforeIsEmpty {
            alpha = 0
            isHidden = false
            UIView.animate(withDuration: 0.25) {
                self.alpha = 1
                animations?()
            }
        }
    }
    
    func removePhotoAssets(
        _ photoAssets: [PhotoAsset],
        animations: (() -> Void)? = nil
    ) {
        if photoAssets.isEmpty {
            return
        }
        var removedIndices = IndexSet()
        for photoAsset in photoAssets {
            if let item = photoAssetArray.firstIndex(of: photoAsset) {
                removedIndices.insert(item)
            }
        }
        guard !removedIndices.isEmpty else { return }
        let indexPaths = removedIndices.map { IndexPath(item: $0, section: 0) }
        // UIKit 可能先查询删除前的布局；数据必须在更新批次内同步修改。
        collectionView.performBatchUpdates {
            for item in removedIndices.reversed() {
                self.photoAssetArray.remove(at: item)
            }
            if let indexPath = self.currentSelectedIndexPath {
                if removedIndices.contains(indexPath.item) {
                    self.currentSelectedIndexPath = nil
                }else {
                    let shift = removedIndices.count(in: 0..<indexPath.item)
                    self.currentSelectedIndexPath = IndexPath(item: indexPath.item - shift, section: indexPath.section)
                }
            }
            self.collectionView.deleteItems(at: indexPaths)
        }
        if photoAssetArray.isEmpty {
            UIView.animate(withDuration: 0.25) {
                self.alpha = 0
                animations?()
            } completion: { (isFinish) in
                if isFinish && self.photoAssetArray.isEmpty {
                    self.isHidden = true
                }
            }
        }
    }
    
    func replacePhotoAsset(at index: Int, with photoAsset: PhotoAsset) {
        photoAssetArray[index] = photoAsset
        collectionView.reloadItems(at: [IndexPath.init(item: index, section: 0)])
    }
    func scrollTo(photoAsset: PhotoAsset?, isAnimated: Bool = true) {
        guard let photoAsset = photoAsset else {
            deselectedCurrentIndexPath()
            return
        }
        if let item = photoAssetArray.firstIndex(of: photoAsset) {
            if let indexPath = currentSelectedIndexPath, item == indexPath.item {
                return
            }
            let indexPath = IndexPath(item: item, section: 0)
            collectionView.selectItem(at: indexPath, animated: isAnimated, scrollPosition: .centeredHorizontally)
            currentSelectedIndexPath = indexPath
        }else {
            deselectedCurrentIndexPath()
        }
    }
    func deselectedCurrentIndexPath() {
        if let indexPath = currentSelectedIndexPath {
            collectionView.deselectItem(at: indexPath, animated: true)
            currentSelectedIndexPath = nil
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photoAssetArray.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell: PhotoPreviewSelectedViewCell = collectionView.dequeueReusableCell(for: indexPath)
        cell.delegate = self
        cell.isPhotoList = isPhotoList
        cell.tickColor = tickColor
        cell.photoAsset = photoAssetArray[indexPath.item]
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isPhotoList {
            collectionView.deselectItem(at: indexPath, animated: false)
        }else {
            currentSelectedIndexPath = indexPath
        }
        delegate?.selectedView(self, didSelectItemAt: photoAssetArray[indexPath.item])
    }
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return getItemSize()
    }
    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        let myCell = cell as! PhotoPreviewSelectedViewCell
        myCell.cancelRequest()
    }
    func getItemSize() -> CGSize {
        let side: CGFloat = 70 - collectionViewLayout.sectionInset.top - collectionViewLayout.sectionInset.bottom
        return CGSize(width: side, height: side)
    }
    
    func collectionView(_ collectionView: UICollectionView, canEditItemAt indexPath: IndexPath) -> Bool {
        true
    }
    
    override func layoutSubviews() {
        shadeMaskLayer.startPoint = CGPoint(x: 0, y: 1)
        shadeMaskLayer.endPoint = CGPoint(x: 1, y: 1)
        shadeView.frame = bounds
        shadeMaskLayer.frame = bounds
        
        shadeView.frame = bounds
        if !collectionView.frame.equalTo(bounds) {
            reloadSectionInset()
        }
        collectionView.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PhotoPreviewSelectedView: PhotoPreviewSelectedViewCellDelegate {
    func selectedViewCell(didDelete cell: PhotoPreviewSelectedViewCell) {
        delegate?.selectedView(self, didDeleteItemAt: cell.photoAsset)
    }
}

@available(iOS 11.0, *)
extension PhotoPreviewSelectedView: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    
    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        if !allowDrop {
            return []
        }
        let itemProvider = NSItemProvider.init()
        let dragItem = UIDragItem.init(itemProvider: itemProvider)
        dragItem.localObject = indexPath
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        allowDrop
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath
            destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        var dropProposal: UICollectionViewDropProposal
        if session.localDragSession != nil {
            dropProposal = UICollectionViewDropProposal.init(operation: .move, intent: .insertAtDestinationIndexPath)
        }else {
            dropProposal = UICollectionViewDropProposal.init(operation: .copy, intent: .insertAtDestinationIndexPath)
        }
        return dropProposal
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        if let destinationIndexPath = coordinator.destinationIndexPath,
           let sourceIndexPath = coordinator.items.first?.sourceIndexPath {
            collectionView.isUserInteractionEnabled = false
            deselectedCurrentIndexPath()
            collectionView.performBatchUpdates {
                let sourceAsset = photoAssetArray[sourceIndexPath.item]
                photoAssetArray.remove(at: sourceIndexPath.item)
                photoAssetArray.insert(sourceAsset, at: destinationIndexPath.item)
                collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
                delegate?.selectedView(self, moveItemAt: sourceIndexPath.item, toIndex: destinationIndexPath.item)
            } completion: { _ in
                collectionView.isUserInteractionEnabled = true
            }
            if let dragItem = coordinator.items.first?.dragItem {
                coordinator.drop(dragItem, toItemAt: destinationIndexPath)
            }
        }
    }
}
