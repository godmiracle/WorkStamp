//
//  PhotoLibrarySaver.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import Photos
import CoreLocation
import UIKit

enum PhotoLibrarySaver {
    static func save(
        _ image: UIImage,
        captureDate: Date,
        location: CLLocation?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        requestAuthorizationIfNeeded { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(PhotoSaveError.permissionDenied))
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = captureDate
                request.location = location
            }, completionHandler: { success, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(PhotoSaveError.saveFailed))
                }
            })
        }
    }

    private static func requestAuthorizationIfNeeded(
        completion: @escaping (PHAuthorizationStatus) -> Void
    ) {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else {
            completion(current)
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: completion)
    }
}

enum PhotoSaveError: LocalizedError {
    case permissionDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有相册写入权限，无法保存带水印照片。"
        case .saveFailed:
            return "照片保存失败，请稍后重试。"
        }
    }
}
