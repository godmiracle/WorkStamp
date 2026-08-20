//
//  CameraService.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import AVFoundation
import Combine
import UIKit

private struct CameraConfiguration: Sendable {
    let position: AVCaptureDevice.Position
    let isFlashAvailable: Bool
}

private final class CameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "WorkStamp.CameraSession")
    private let photoOutput = AVCapturePhotoOutput()

    func configure(completion: @escaping @Sendable (Result<CameraConfiguration, CameraError>) -> Void) {
        sessionQueue.async { [self] in
            guard !session.inputs.contains(where: { $0 is AVCaptureDeviceInput }) else {
                startRunning()
                let camera = currentCamera()
                completion(.success(CameraConfiguration(
                    position: camera?.position ?? .back,
                    isFlashAvailable: camera?.hasFlash == true
                )))
                return
            }

            session.beginConfiguration()
            session.sessionPreset = .photo

            do {
                let input = try makeInput(for: .back)

                guard session.canAddInput(input) else {
                    throw CameraError.cannotAddCameraInput
                }

                session.addInput(input)

                guard session.canAddOutput(photoOutput) else {
                    throw CameraError.cannotAddPhotoOutput
                }

                session.addOutput(photoOutput)
                photoOutput.maxPhotoQualityPrioritization = .quality
                session.commitConfiguration()
                startRunning()
                completion(.success(CameraConfiguration(position: .back, isFlashAvailable: input.device.hasFlash)))
            } catch let error as CameraError {
                session.commitConfiguration()
                completion(.failure(error))
            } catch {
                session.commitConfiguration()
                completion(.failure(.sessionConfigurationFailed(error.localizedDescription)))
            }
        }
    }

    func start(completion: (@Sendable () -> Void)? = nil) {
        sessionQueue.async { [self] in
            startRunning()
            completion?()
        }
    }

    func stop(completion: (@Sendable () -> Void)? = nil) {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
            completion?()
        }
    }

    func capture(
        flashMode: AVCaptureDevice.FlashMode,
        isFlashAvailable: Bool,
        delegate: CaptureDelegateProxy
    ) {
        sessionQueue.async { [self] in
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(flashMode), isFlashAvailable {
                settings.flashMode = flashMode
            } else {
                settings.flashMode = .off
            }

            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func switchCamera(completion: @escaping @Sendable (Result<CameraConfiguration, CameraError>) -> Void) {
        sessionQueue.async { [self] in
            do {
                let currentInput = try currentCameraInput()
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
                completion(.success(CameraConfiguration(position: newPosition, isFlashAvailable: newInput.device.hasFlash)))
            } catch let error as CameraError {
                completion(.failure(error))
            } catch {
                completion(.failure(.sessionConfigurationFailed(error.localizedDescription)))
            }
        }
    }

    private func startRunning() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    private func currentCamera() -> AVCaptureDevice? {
        session.inputs
            .compactMap { ($0 as? AVCaptureDeviceInput)?.device }
            .first
    }

    private func currentCameraInput() throws -> AVCaptureDeviceInput {
        guard let input = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first else {
            throw CameraError.sessionNotReady
        }

        return input
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

@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isConfigured = false
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var activePosition: AVCaptureDevice.Position = .back
    @Published private(set) var isFlashAvailable = false
    @Published var errorMessage: String?

    var session: AVCaptureSession {
        sessionController.session
    }

    private let sessionController = CameraSessionController()
    private var captureGate = CaptureFlightGate()
    private var captureCompletion: (@MainActor (Result<UIImage, Error>) -> Void)?
    private var captureDelegate: CaptureDelegateProxy?

    var canSwitchCamera: Bool {
        authorizationStatus == .authorized && isConfigured && !isCapturing
    }

    func start() {
        requestAccessIfNeeded()
    }

    func stop() {
        cancelCapture()
        sessionController.stop { [weak self] in
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    func capturePhoto(
        flashMode: AVCaptureDevice.FlashMode = .off,
        completion: @escaping @MainActor (Result<UIImage, Error>) -> Void
    ) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CameraError.cameraPermissionDenied))
            return
        }

        guard isConfigured else {
            completion(.failure(CameraError.sessionNotReady))
            return
        }

        guard captureGate.activeID == nil else {
            completion(.failure(CameraError.captureInProgress))
            return
        }

        guard let captureID = captureGate.begin() else {
            completion(.failure(CameraError.captureInProgress))
            return
        }
        let delegate = CaptureDelegateProxy(captureID: captureID, owner: self)

        captureDelegate = delegate
        captureCompletion = completion
        isCapturing = true

        sessionController.capture(
            flashMode: flashMode,
            isFlashAvailable: isFlashAvailable,
            delegate: delegate
        )
    }

    func cancelCapture() {
        guard let captureID = captureGate.activeID else {
            return
        }

        finishCapture(
            captureID: captureID,
            result: .failure(CameraError.captureCancelled)
        )
    }

    func switchCamera() {
        guard authorizationStatus == .authorized else {
            errorMessage = CameraError.cameraPermissionDenied.errorDescription
            return
        }

        guard !isCapturing else {
            errorMessage = CameraError.captureInProgress.errorDescription
            return
        }

        sessionController.switchCamera { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case let .success(configuration):
                    activePosition = configuration.position
                    isFlashAvailable = configuration.isFlashAvailable
                    errorMessage = nil
                case let .failure(error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }

    private func requestAccessIfNeeded() {
        switch authorizationStatus {
        case .authorized:
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

                    if granted {
                        configureAndStartSessionIfNeeded()
                    } else {
                        errorMessage = CameraError.cameraPermissionDenied.errorDescription
                    }
                }
            }
        default:
            errorMessage = CameraError.cameraPermissionDenied.errorDescription
        }
    }

    private func configureAndStartSessionIfNeeded() {
        guard !isConfigured else {
            sessionController.start { [weak self] in
                Task { @MainActor [weak self] in
                    self?.isRunning = true
                }
            }
            return
        }

        sessionController.configure { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case let .success(configuration):
                    isConfigured = true
                    isRunning = true
                    activePosition = configuration.position
                    isFlashAvailable = configuration.isFlashAvailable
                    errorMessage = nil
                case let .failure(error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }

    fileprivate func handleCaptureCallback(
        captureID: UInt64,
        data: Data?,
        errorMessage: String?
    ) {
        if let errorMessage {
            finishCapture(
                captureID: captureID,
                result: .failure(CameraError.captureFailed(errorMessage))
            )
            return
        }

        guard let data, let image = UIImage(data: data) else {
            finishCapture(
                captureID: captureID,
                result: .failure(CameraError.cannotDecodePhoto)
            )
            return
        }

        finishCapture(captureID: captureID, result: .success(image))
    }

    private func finishCapture(
        captureID: UInt64,
        result: Result<UIImage, Error>
    ) {
        guard captureGate.finish(id: captureID) else {
            return
        }

        let completion = captureCompletion
        captureCompletion = nil
        captureDelegate = nil
        isCapturing = false
        completion?(result)
    }
}

private nonisolated final class CaptureDelegateProxy: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let captureID: UInt64
    weak var owner: CameraService?

    init(captureID: UInt64, owner: CameraService) {
        self.captureID = captureID
        self.owner = owner
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        let errorMessage = error?.localizedDescription

        Task { @MainActor [weak self] in
            self?.owner?.handleCaptureCallback(
                captureID: self?.captureID ?? 0,
                data: data,
                errorMessage: errorMessage
            )
        }
    }
}

enum CameraError: LocalizedError, Sendable {
    case cameraPermissionDenied
    case noBackCamera
    case noFrontCamera
    case cannotAddCameraInput
    case cannotAddPhotoOutput
    case sessionNotReady
    case sessionConfigurationFailed(String)
    case captureInProgress
    case captureCancelled
    case captureFailed(String)
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
        case let .sessionConfigurationFailed(message):
            return "相机会话配置失败：\(message)"
        case .captureInProgress:
            return "正在拍照，请等待当前照片完成。"
        case .captureCancelled:
            return "拍照已取消。"
        case let .captureFailed(message):
            return "拍照失败：\(message)"
        case .cannotDecodePhoto:
            return "拍照完成，但无法解析照片数据。"
        }
    }
}
