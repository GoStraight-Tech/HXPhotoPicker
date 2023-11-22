//
//  Picker+PhotoManager.swift
//  HXPhotoPicker
//
//  Created by Slience on 2020/12/29.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

extension PhotoManager {
    
    func registerPhotoChangeObserver() {
        let status = AssetManager.authorizationStatus()
        if status == .notDetermined || status == .denied {
            return
        }
        if isCacheCameraAlbum {
            if didRegisterObserver {
                return
            }
#if !targetEnvironment(macCatalyst)
            PHPhotoLibrary.shared().register(self)
#endif
            didRegisterObserver = true
        }else {
            if !didRegisterObserver {
                return
            }
#if !targetEnvironment(macCatalyst)
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
#endif
            cameraAlbumResult = nil
            cameraAlbumResultOptions = nil
            didRegisterObserver = false
        }
    }
}

extension PhotoManager: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult = cameraAlbumResult,
              let changeResult = changeInstance.changeDetails(for: fetchResult) else {
            return
        }
        let result = changeResult.fetchResultAfterChanges
        cameraAlbumResult = result
        PhotoManager.shared.firstLoadAssets = true
    }
}
