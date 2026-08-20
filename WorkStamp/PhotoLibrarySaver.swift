//
//  PhotoLibrarySaver.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import CoreLocation
import Foundation
import Photos
import UIKit

final class PhotoLibraryCancellationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var resolvedResult: Result<Value, Error>?
    private var isResolved = false

    @discardableResult
    func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
        let result: Result<Value, Error>?

        lock.lock()
        if isResolved {
            result = resolvedResult ?? .failure(CancellationError())
        } else {
            self.continuation = continuation
            result = nil
        }
        lock.unlock()

        guard let result else {
            return true
        }

        continuation.resume(with: result)
        return false
    }

    func cancel() {
        resolve(.failure(CancellationError()))
    }

    func resolve(_ result: Result<Value, Error>) {
        let continuation: CheckedContinuation<Value, Error>?

        lock.lock()
        guard !isResolved else {
            lock.unlock()
            return
        }

        isResolved = true
        continuation = self.continuation
        self.continuation = nil
        if continuation == nil {
            resolvedResult = result
        }
        lock.unlock()

        continuation?.resume(with: result)
    }
}

@MainActor
enum PhotoLibrarySaver {
    static func save(
        _ image: UIImage,
        captureDate: Date,
        location: PhotoAssetLocationMetadata?
    ) async throws {
        try Task.checkCancellation()

        guard let imageData = image.jpegData(compressionQuality: 1) else {
            throw PhotoSaveError.imageEncodingFailed
        }

        let status = try await requestAuthorizationIfNeeded()
        try Task.checkCancellation()
        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.permissionDenied
        }

        try await performChanges(
            imageData: imageData,
            captureDate: captureDate,
            location: location
        )
        try Task.checkCancellation()
    }

    private static func performChanges(
        imageData: Data,
        captureDate: Date,
        location: PhotoAssetLocationMetadata?
    ) async throws {
        let gate = PhotoLibraryCancellationGate<Void>()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard gate.install(continuation) else {
                    return
                }

                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: imageData, options: nil)
                    request.creationDate = captureDate
                    request.location = location?.location
                }, completionHandler: { success, error in
                    if let error {
                        gate.resolve(.failure(error))
                    } else if success {
                        gate.resolve(.success(()))
                    } else {
                        gate.resolve(.failure(PhotoSaveError.saveFailed))
                    }
                })
            }
        }, onCancel: {
            gate.cancel()
        })

        try Task.checkCancellation()
    }

    private static func requestAuthorizationIfNeeded() async throws -> PHAuthorizationStatus {
        try Task.checkCancellation()

        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else {
            return current
        }

        let gate = PhotoLibraryCancellationGate<PHAuthorizationStatus>()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Error>) in
                guard gate.install(continuation) else {
                    return
                }

                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    gate.resolve(.success(status))
                }
            }
        }, onCancel: {
            gate.cancel()
        })
    }
}

enum PhotoSaveError: LocalizedError, Sendable {
    case permissionDenied
    case imageEncodingFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有相册写入权限，无法保存带水印照片。"
        case .imageEncodingFailed:
            return "照片编码失败，无法保存带水印照片。"
        case .saveFailed:
            return "照片保存失败，请稍后重试。"
        }
    }
}
