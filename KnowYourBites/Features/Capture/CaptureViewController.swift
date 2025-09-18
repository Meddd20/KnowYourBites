//
//  CaptureViewController.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 10/09/25.
//

import UIKit
import Vision
import AVFoundation
import Photos
import PhotosUI

enum TorchState { case off, on }

enum ScanFinishedState {
    case nutrition
    case ingredients
    case product
    
    var progress: Float {
        switch self {
        case .nutrition: return 0.66
        case .ingredients: return 1.0
        case .product: return 1
        }
    }
}

final class CaptureViewController: UIViewController {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let shutter = ShutterButton()
    private let previewContainer = UIView()
    private let progressView = UIProgressView()
    private let commandToAction = UILabel()
    private let instructionBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let thinTrack = UIView()
    private let thinFill  = UIView()
    
    private let ocrService = OCRService()
    private let blurDetector = BlurDetector()
    private let glareDetector = GlareDetector()
    private let geminiService = GeminiService()
    private let captureFlow = CaptureFlow()
    var loadingVC: LoadingViewController?
    
    private var frozenPreview = false
    
    private let torch = UIButton(type: .system)
    private var torchState: TorchState = .off { didSet { updateTorchUI() } }
    
    private let gallery = UIButton(type: .system)
    
    private var thinFillWidthConstraint: NSLayoutConstraint!
    
    private var compositionResult: Composition?
    private var nutritionResult: Nutrition?
    
    let encoder = JSONEncoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setUpPreviewContainer()
        setUpPreviewLayer()
        setUpShutter()
        setUpTorch()
        setUpGallery()
        setUpInstructionPill()
        setUpProgressBar()
        setProgress(0)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
                
        checkCameraPermission()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewContainer.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
        
    private func setUpPreviewContainer() {
        view.addSubview(previewContainer)
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            previewContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            previewContainer.widthAnchor.constraint(equalTo: view.widthAnchor),
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 4.0/3.0)
        ])
    }
    
    private func setUpPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewContainer.layer.addSublayer(previewLayer)
        previewLayer.cornerRadius = 20
    }
    
    private func setUpShutter() {
        shutter.diameter = 90
        shutter.ringWidth = 3
        shutter.ringGap = 2
        shutter.coreGap = 3
        
        shutter.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        view.addSubview(shutter)
        shutter.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shutter.widthAnchor.constraint(equalToConstant: 70),
            shutter.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    private func setUpProgressBar() {
        thinTrack.backgroundColor = .systemGray4
        thinTrack.layer.cornerRadius = 2
        thinTrack.clipsToBounds = true
        
        thinFill.backgroundColor = .systemGreen
        thinFill.layer.cornerRadius = 2
        thinFill.clipsToBounds = true
        
        view.addSubview(thinTrack)
        thinTrack.addSubview(thinFill)
        
        thinTrack.translatesAutoresizingMaskIntoConstraints = false
        thinFill.translatesAutoresizingMaskIntoConstraints = false
        
        thinFillWidthConstraint = thinFill.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            thinTrack.bottomAnchor.constraint(equalTo: instructionBlur.topAnchor, constant: -12),
            thinTrack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            thinTrack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.35),
            thinTrack.heightAnchor.constraint(equalToConstant: 4),
            
            thinFill.leadingAnchor.constraint(equalTo: thinTrack.leadingAnchor),
            thinFill.topAnchor.constraint(equalTo: thinTrack.topAnchor),
            thinFill.bottomAnchor.constraint(equalTo: thinTrack.bottomAnchor),
            thinFillWidthConstraint
        ])
    }
    
    private func setProgress(_ value: CGFloat) {
        let clamped = max(0, min(1, value))
        thinTrack.layoutIfNeeded() // memastikan agar layout selesai dan mendapatkan nilai aktualnya
        
        let targetWidth = thinTrack.bounds.width * clamped
        
        let apply = {
            // mencari semua constrain thinfill, mencari attribute width (widthAnchor) dan mengubah valuenya
            self.thinFillWidthConstraint.constant = targetWidth
            self.thinTrack.layoutIfNeeded()
        }
        
        UIView.animate(withDuration: 0.25, animations: apply)
    }
    
    private func setStepProgress(currentStep: Int) {
        let value = CGFloat(currentStep) / CGFloat(3)
        setProgress(value)
    }
                    
    private func setUpInstructionPill() {
        instructionBlur.layer.cornerRadius = 12
        instructionBlur.clipsToBounds = true
        
        commandToAction.text = "Take a picture of the composition and/or nutrition facts"
        commandToAction.numberOfLines = 2
        commandToAction.font = .systemFont(ofSize: 14, weight: .semibold)
        commandToAction.textAlignment = .center
        commandToAction.textColor = .label
        commandToAction.backgroundColor = .clear
        
        view.addSubview(instructionBlur)
        instructionBlur.contentView.addSubview(commandToAction)
        
        instructionBlur.translatesAutoresizingMaskIntoConstraints = false
        commandToAction.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            instructionBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            instructionBlur.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionBlur.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            
            commandToAction.topAnchor.constraint(equalTo: instructionBlur.contentView.topAnchor, constant: 8),
            commandToAction.bottomAnchor.constraint(equalTo: instructionBlur.contentView.bottomAnchor, constant: -8),
            commandToAction.leadingAnchor.constraint(equalTo: instructionBlur.contentView.leadingAnchor, constant: 12),
            commandToAction.trailingAnchor.constraint(equalTo: instructionBlur.contentView.trailingAnchor, constant: -12)
        ])
    }
    
    private func setUpTorch() {
        torch.tintColor = .white
        torch.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        view.addSubview(torch)
        torch.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            torch.trailingAnchor.constraint(equalTo: shutter.trailingAnchor, constant: 120),
            torch.bottomAnchor.constraint(equalTo: shutter.topAnchor, constant: 55),
            torch.widthAnchor.constraint(equalToConstant: 36),
            torch.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        torchState = .off
    }
    
    private func setUpGallery() {
        gallery.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        gallery.tintColor = .white
        gallery.addTarget(self, action: #selector(openGallery), for: .touchUpInside)
        
        view.addSubview(gallery)
        gallery.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gallery.leadingAnchor.constraint(equalTo: shutter.leadingAnchor, constant: -120),
            gallery.centerYAnchor.constraint(equalTo: shutter.centerYAnchor),
            gallery.widthAnchor.constraint(equalToConstant: 45),
            gallery.heightAnchor.constraint(equalToConstant: 45)
        ])
    }
    
    @objc private func openGallery() {
        presentPhotoPicker()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUpSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.setUpSession() }
            }
        default:
            print("Camera permission not granted")
        }
    }
    
    private func setUpSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if #available(iOS 13.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    @objc private func sessionInterrupted(_ notification: Notification) {
        torchState = .off
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        torchState = .off
    }
    
    private func updateTorchUI() {
        let name = (torchState == .on) ? "bolt.fill" : "bolt.slash.fill"
        let image = UIImage(systemName: name)
        torch.setImage(image, for: .normal)
        torch.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular, scale: .large), forImageIn: .normal)
        
        setTorch(enable: torchState == .on)
    }
    
    private func setTorch(enable: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if enable {
                try device.setTorchModeOn(level: 0.7)
            } else {
                device.torchMode = .off
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch control failed: \(error.localizedDescription)")
        }
    }
    
    @objc private func toggleTorch() {
        torchState = (torchState == .off) ? .on : .off
    }
    
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }
        
        if #available(iOS 13.0, *) {
            let maxQ = photoOutput.maxPhotoQualityPrioritization
            let desired: AVCapturePhotoOutput.QualityPrioritization = .quality
            settings.photoQualityPrioritization = (desired.rawValue <= maxQ.rawValue) ? desired : maxQ
        }
        self.showLoading()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func focusAndExposeTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        if let hit = view.hitTest(location, with: nil), hit is UIControl { return }
        
        let locationInContainer = gesture.location(in: previewContainer)
        guard previewContainer.bounds.contains(locationInContainer) else { return }
                
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: locationInContainer)
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
                
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .continuousAutoExposure
            }
            
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
            
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            showFocusIndicator(at: previewContainer.convert(locationInContainer, to: view))
        } catch {
            print("Focus config failed \(error.localizedDescription)")
        }
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        indicator.center = point
        indicator.layer.borderColor = UIColor.yellow.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 6
        view.addSubview(indicator)
        
        view.insertSubview(indicator, belowSubview: shutter)

        UIView.animate(withDuration: 0.5, animations: {
            indicator.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            indicator.alpha = 0
        }) { _ in
            indicator.removeFromSuperview()
        }
    }
        
    private func saveToPhotos(data: Data, fallbackImage: UIImage? = nil) {
        func performSave() {
            PHPhotoLibrary.shared().performChanges {
                if #available(iOS 11.0, *) {
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, data: data, options: nil)
                } else if let image = fallbackImage {
                    // Fallback for very old iOS
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            } completionHandler: { success, error in
                if let error = error {
                    print("Save failed:", error.localizedDescription)
                } else {
                    print("Saved to Photos ✓")
                }
            }
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited: performSave()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited { performSave() }
                else { print("Photo Library permission denied") }
            }
        default:
            print("Photo Library permission denied")
        }
    }
    
    func showLoading() {
        let vc = LoadingViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true, completion: nil)
        loadingVC = vc
    }

    func hideLoading(completion: (() -> Void)? = nil) {
        guard let loadingVC = loadingVC else { completion?(); return }
        loadingVC.dismiss(animated: true) { [weak self] in
            self?.loadingVC = nil
            completion?()
        }
    }
    
//    func freezePreview() {
//        guard !frozenPreview else { return }
//        DispatchQueue.main.async {
//            self.previewLayer.connection?.isEnabled = false
//            self.frozenPreview = true
//        }
//    }
//    
//    func unfreezePreview() {
//        guard !frozenPreview else { return }
//        DispatchQueue.main.async {
//            self.previewLayer.connection?.isEnabled = true
//            self.frozenPreview = false
//        }
//    }
    
//    func pauseSession() {
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            self?.session.stopRunning()
//        }
//    }
//
//    func resumeSession() {
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            self?.session.startRunning()
//        }
//    }
}

extension CaptureViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Failed to capture photo: \(error.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            print("No image data")
            return
        }
        
        let orientation = CGImagePropertyOrientation(from: image.imageOrientation)
        
        if let step = captureFlow.nextStep(), step != .product {
            ocrService.recognizeText(
                cgImage: cgImage,
                orientation: orientation,
                language: ["id-ID","en-US"],
                fast: false
            ) { [weak self] text, observations in
                if observations.isEmpty {
                    DispatchQueue.main.async {
                        self?.showPictureIssueAllert(message: "Can't detect any text, please retake")
                        return
                    }
                } else {
                    let joined = self?.ocrService.makeJoinedLines(from: observations, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
                    
                    Task { [weak self] in
                        guard let self = self else { return }
                        
                        let ocrText = (joined ?? []).joined(separator: "\n")
                        let result = await self.geminiService.validateOCRText(ocrText)
                        
                        if let result = result {
                            print(result)
                        }
                        
                        if result?.composition != nil {
                            compositionResult = result?.composition
                            captureFlow.complete(.compositions)
                        }
                        
                        if result?.nutrition != nil {
                            nutritionResult = result?.nutrition
                            captureFlow.complete(.nutritionFacts)
                        }
                        
                        DispatchQueue.main.async {
                            self.setStepProgress(currentStep: self.captureFlow.completed.count)
                            self.hideLoading()
                        }
                    }
                }
            }
        } else {
            let composition = (try? encoder.encode(compositionResult)).flatMap { String(data: $0, encoding: .utf8)} ?? ""
            let nutrition = (try? encoder.encode(nutritionResult)).flatMap { String(data: $0, encoding: .utf8)} ?? ""
            
            Task { [weak self] in
                guard let self = self else { return }
                
                if let summary = await self.geminiService.generateSummary(composition, nutrition, productImage: image) {
                    
                    await MainActor.run {
                        let viewController = SummaryViewController(result: summary, productImage: image)

                        self.captureFlow.complete(.product)
                        self.setStepProgress(currentStep: self.captureFlow.completed.count)
                        self.hideLoading {
                            if let nav = self.navigationController {
                                nav.pushViewController(viewController, animated: true)
                            } else {
                                // fallback if not embedded in a nav controller
                                viewController.modalPresentationStyle = .fullScreen
                                self.present(viewController, animated: true)
                            }
                        }
                    }
                } else {
                    showPictureIssueAllert(message: "Failed to generate summary, please try again.")
                }
            }
        }
    }
}

extension CaptureViewController: PHPickerViewControllerDelegate {
    func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider else { return }
        
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                guard let self, let image = object as? UIImage, let cgImage = image.cgImage else { return }
                
                DispatchQueue.main.async {
                    self.showLoading()
                    let orientation = CGImagePropertyOrientation(from: image.imageOrientation)
                    
                    if let step = self.captureFlow.nextStep(), step != .product {
                        self.ocrService.recognizeText(cgImage: cgImage, orientation: orientation, language: ["en-US", "id-ID"], fast: false) { text, observations in
                            if observations.isEmpty {
                                self.showPictureIssueAllert(message: "Can't detect any text, please retake")
                                return
                            } else {
                                let joined = self.ocrService.makeJoinedLines(from: observations, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
                                
                                Task { [weak self] in
                                    guard let self = self else { return }
                                    
                                    let ocrText = (joined).joined(separator: "\n")
                                    let result = await self.geminiService.validateOCRText(ocrText)
                                    
                                    if result?.composition != nil {
                                        captureFlow.complete(.compositions)
                                    }
                                    
                                    if result?.nutrition != nil {
                                        captureFlow.complete(.nutritionFacts)
                                    }
                                    
                                    DispatchQueue.main.async {
                                        self.setStepProgress(currentStep: self.captureFlow.completed.count)
                                        self.hideLoading()
                                    }
                                }
                            }
                        }
                    } else {
                        let composition = (try? self.encoder.encode(self.compositionResult)).flatMap { String(data: $0, encoding: .utf8)} ?? ""
                        
                        let nutrition = (try? self.encoder.encode(self.compositionResult)).flatMap {
                            String(data: $0, encoding: .utf8)} ?? ""
                        
                        Task { [weak self] in
                            guard let self = self else { return }
                            
                            if let summary = await self.geminiService.generateSummary(composition, nutrition, productImage: image) {
                                
                                await MainActor.run {
                                    let viewController = SummaryViewController(result: summary, productImage: image)
                                    
                                    self.captureFlow.complete(.product)
                                    self.setStepProgress(currentStep: self.captureFlow.completed.count)
                                    self.hideLoading {
                                        if let nav = self.navigationController {
                                            nav.pushViewController(viewController, animated: true)
                                        } else {
                                            viewController.modalPresentationStyle = .fullScreen
                                            self.present(viewController, animated: true)
                                        }
                                    }
                                }
                            } else {
                                showPictureIssueAllert(message: "Failed to generate summary, please try again.")
                            }
                        }
                    }
                }
            }
        }
    }
}

extension UIViewController {
    func showPictureIssueAllert(message: String) {
        let alertController = UIAlertController(
            title: "Hmm, fotonya kurang pas",
            message: message,
            preferredStyle: .alert
        )
        let dismissAction = UIAlertAction(title: "Yes", style: .default)
        alertController.addAction(dismissAction)
        present(alertController, animated: true)
    }
}
