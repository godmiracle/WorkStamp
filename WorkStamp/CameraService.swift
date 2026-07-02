//
//  CameraService.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import AVFoundation
import Combine
import UIKit

final class CameraService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isConfigured = false
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var activePosition: AVCaptureDevice.Position = .back
    @Published private(set) var isFlashAvailable = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "WorkStamp.CameraSession")
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    var canSwitchCamera: Bool {
        authorizationStatus == .authorized && isConfigured && !isCapturing
    }

    func start() {
        requestAccessIfNeeded()
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func capturePhoto(
        flashMode: AVCaptureDevice.FlashMode = .off,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CameraError.cameraPermissionDenied))
            return
        }

        guard isConfigured else {
            completion(.failure(CameraError.sessionNotReady))
            return
        }

        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flashMode),
               self.isFlashAvailable {
                settings.flashMode = flashMode
            } else {
                settings.flashMode = .off
            }
            self.captureCompletion = completion

            DispatchQueue.main.async {
                self.isCapturing = true
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func switchCamera() {
        guard authorizationStatus == .authorized else {
            errorMessage = CameraError.cameraPermissionDenied.errorDescription
            return
        }

        sessionQueue.async {
            do {
                try self.replaceCameraInput()
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func requestAccessIfNeeded() {
        switch authorizationStatus {
        case .authorized:
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }

                if granted {
                    self.configureAndStartSessionIfNeeded()
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = CameraError.cameraPermissionDenied.errorDescription
                    }
                }
            }
        default:
            errorMessage = CameraError.cameraPermissionDenied.errorDescription
        }
    }

    private func configureAndStartSessionIfNeeded() {
        sessionQueue.async {
            guard !self.isConfigured else {
                self.startRunningSessionIfNeeded()
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            do {
                let input = try self.makeInput(for: .back)

                guard self.session.canAddInput(input) else {
                    throw CameraError.cannotAddCameraInput
                }

                self.session.addInput(input)

                guard self.session.canAddOutput(self.photoOutput) else {
                    throw CameraError.cannotAddPhotoOutput
                }

                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.isConfigured = true
                    self.activePosition = .back
                    self.isFlashAvailable = input.device.hasFlash
                    self.errorMessage = nil
                }

                self.startRunningSessionIfNeeded()
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func startRunningSessionIfNeeded() {
        guard !session.isRunning else {
            DispatchQueue.main.async {
                self.isRunning = true
            }
            return
        }

        session.startRunning()
        DispatchQueue.main.async {
            self.isRunning = true
        }
    }

    private func replaceCameraInput() throws {
        guard let currentInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first else {
            throw CameraError.sessionNotReady
        }

        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        let newInput = try makeInput(for: newPosition)

        session.beginConfiguration()
        session.removeInput(currentInput)

        guard session.canAddInput(newInput) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            throw CameraError.cannotAddCameraInput
        }

        session.addInput(newInput)
        session.commitConfiguration()

        DispatchQueue.main.async {
            self.activePosition = newPosition
            self.isFlashAvailable = newInput.device.hasFlash
            self.errorMessage = nil
        }
    }

    private func makeInput(for position: AVCaptureDevice.Position) throws -> AVCaptureDeviceInput {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            switch position {
            case .front:
                throw CameraError.noFrontCamera
            case .back:
                throw CameraError.noBackCamera
            default:
                throw CameraError.noBackCamera
            }
        }

        return try AVCaptureDeviceInput(device: camera)
    }
}

extension CameraService: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            DispatchQueue.main.async {
                self.isCapturing = false
            }
        }

        if let error {
            captureCompletion?(.failure(error))
            captureCompletion = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureCompletion?(.failure(CameraError.cannotDecodePhoto))
            captureCompletion = nil
            return
        }

        captureCompletion?(.success(image))
        captureCompletion = nil
    }
}

enum CameraError: LocalizedError {
    case cameraPermissionDenied
    case noBackCamera
    case noFrontCamera
    case cannotAddCameraInput
    case cannotAddPhotoOutput
    case sessionNotReady
    case cannotDecodePhoto

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "没有相机权限，请到系统设置中允许 WorkStamp 使用相机。"
        case .noBackCamera:
            return "未找到后置相机。"
        case .noFrontCamera:
            return "未找到前置相机。"
        case .cannotAddCameraInput:
            return "无法把相机输入加入会话。"
        case .cannotAddPhotoOutput:
            return "无法把拍照输出加入会话。"
        case .sessionNotReady:
            return "相机会话还没准备好，请稍后再试。"
        case .cannotDecodePhoto:
            return "拍照完成，但无法解析照片数据。"
        }
    }
}
