///
/// HybridCameraPhotoOutput.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import UIKit
import Foundation
import NitroImage
import NitroModules

final class HybridCameraPhotoOutput: HybridCameraPhotoOutputSpec, NativeCameraOutput {
  private let options: PhotoOutputOptions
  let mediaType: MediaType = .video
  let requiresAudioInput: Bool = false
  // TODO: If depth data delivery is configured, we probably should return `true` here
  let requiresDepthFormat: Bool = false
  let output: AVCapturePhotoOutput

  var supportsDepthDataDelivery: Bool {
    return output.isDepthDataDeliverySupported
  }

  var supportsCameraCalibrationDataDelivery: Bool {
    return output.isCameraCalibrationDataDeliverySupported
  }
  var outputOrientation: CameraOrientation = .up {
    didSet {
      guard let connection = output.connection(with: .video) else { return }
      // TODO: Should we apply that within the CameraSession's DispatchQueue? Batch it?
      try? connection.setOrientation(outputOrientation)
    }
  }
  var currentResolution: Size? {
    // Reads back what `configure(config:)` pinned via
    // `output.maxPhotoDimensions = format.supportedMaxPhotoDimensions.nearest(...)`.
    if #available(iOS 16.0, *) {
      let dims = output.maxPhotoDimensions
      return Size(width: Double(dims.width), height: Double(dims.height))
    }
    guard let device = output.connections.first?.deviceInput?.device else {
      return nil
    }
    let dims = device.activeFormat.highResolutionStillImageDimensions
    return Size(width: Double(dims.width), height: Double(dims.height))
  }

  var streamType: StreamType = .photo
  var targetResolution: ResolutionRule {
    return .closestTo(options.targetResolution)
  }

  init(options: PhotoOutputOptions) throws {
    self.output = AVCapturePhotoOutput()
    self.options = options
    try super.init()

    output.maxPhotoQualityPrioritization = options.qualityPrioritization.toAVQualityPrioritization()

    if options.containerFormat == .dng {
      // If we capture RAW photos, try using Apple ProRAW. If not, Bayer14 RAW will be used.
      output.isAppleProRAWEnabled = output.isAppleProRAWSupported
    }

    if #available(iOS 26, *),
      output.isCameraSensorOrientationCompensationSupported
    {
      // Don't rotate Photo buffers - we handle orientation later on in file capture or toImage().
      output.isCameraSensorOrientationCompensationEnabled = false
    }

    // Prepare the default Photo Settings to make the pipeline ready - some things (like flashMode)
    // might change on a per-capture basis, but containerFormat and preview size is already known
    // and can be prepared already.
    try? prepareDefaultPhotoSettings()
  }

  func configure(config: OutputConfiguration) {
    guard let connection = output.connection(with: .video) else {
      return
    }
    try? connection.setOrientation(outputOrientation)
    try? connection.setMirrorMode(config.mirrorMode)

    if #available(iOS 16.0, *) {
      // Configure PhotoOutput to the currently selected Format's max photo size
      if let nativeDevice = connection.deviceInput {
        let format = nativeDevice.device.activeFormat
        let targetResolution = options.targetResolution.toCMVideoDimensions()
        let nearestPhotoDimension = format.supportedMaxPhotoDimensions.nearest(to: targetResolution)
        if let nearestPhotoDimension,
          output.maxPhotoDimensions != nearestPhotoDimension
        {
          // Target max photo dimensions have changed, re-configure
          output.maxPhotoDimensions = nearestPhotoDimension
          try? prepareDefaultPhotoSettings()
        }
      }
    }
  }

  private func prepareDefaultPhotoSettings() throws {
    // Create default capture settings
    let settings = CapturePhotoSettings(
      flashMode: .off,
      enableShutterSound: true,
      enableDepthData: false,
      enableRedEyeReduction: true,
      enableCameraCalibrationDataDelivery: false,
      enableDistortionCorrection: false,
      enableVirtualDeviceFusion: true,
      location: nil)
    let avSettings = try settings.toAVCapturePhotoSettings(for: output, withOptions: options)
    // Prepare the AVCapturePhotoOutput for those settings so coming up captures are faster
    self.output.setPreparedPhotoSettingsArray([avSettings])
  }

  func capturePhoto(
    settings: CapturePhotoSettings,
    callbacks: CapturePhotoCallbacks
  ) -> any Promise<any HybridPhotoSpec> {
    guard output.connection(with: .video) != nil else {
      let error = RuntimeError("PhotoOutput is not yet connected to the CameraSession!")
      return .rejected(with: error)
    }

    // 1. Prepare delegate that will resolve/reject Promise
    let promise = Promise___VisionCamera__HybridPhotoSpec_cxx.pending()
    let resultingFormat = PhotoContainerFormat(targetFormat: self.options.containerFormat)
    let delegate = CapturePhotoDelegate(
      onCaptured: { photo, metadata in
        // We received a Photo!
        // 1. Check if we have a Preview Image (if it was requested)
        if self.options.previewImageTargetSize != nil,
          let onPreviewImageAvailable = callbacks.onPreviewImageAvailable
        {
          // AVCapturePhoto is immutable once delivered, so decoding it on another thread is safe.
          nonisolated(unsafe) let photo = photo
          DispatchQueue.global(qos: .userInitiated).async {
            // On a separate Thread, start decoding the Preview Image Data
            guard let cgPreviewImage = photo.previewCGImageRepresentation() else {
              return
            }
            // Wrap the `CGImage` in a `HybridUIImage` and notify the callback
            let uiImage = UIImage(
              cgImage: cgPreviewImage, scale: 1.0, orientation: metadata.uiImageOrientation)
            do {
              let image = try HybridUIImage(uiImage: uiImage)
              onPreviewImageAvailable(image)
            } catch {
              logger.error("Failed to wrap the preview image: \(error)")
            }
          }
        }
        // 2. Wrap the `AVCapturePhoto` in a `HybridPhoto` and resolve the Promise
        do {
          let image = try HybridPhoto(
            photo: photo,
            metadata: metadata,
            containerFormat: resultingFormat)
          promise.resolve(result: image)
        } catch {
          promise.reject(error: error)
        }
      },
      onError: { error in
        promise.reject(error: error)
      },
      callbacks: callbacks)

    do {
      // 2. Prepare Photo settings
      let captureSettings = try settings.toAVCapturePhotoSettings(
        for: self.output, withOptions: self.options)
      // 3. Perform capture
      output.capturePhoto(with: captureSettings, delegate: delegate)
      return promise
    } catch {
      // Something failed - e.g. creating Photo settings!
      return .rejected(with: error)
    }
  }

  func capturePhotoToFile(settings: CapturePhotoSettings, callbacks: CapturePhotoCallbacks) throws
    -> any Promise<PhotoFile>
  {
    // `HybridPhotoSpec` is not `Sendable`, so chain the two Promises with listeners instead of `await()`.
    let promise = Promise___VisionCamera__PhotoFile.pending()
    let photoPromise = try self.capturePhoto(settings: settings, callbacks: callbacks)
    photoPromise.addOnResolvedListener { photo in
      do {
        let filePromise = try photo.saveToTemporaryFileAsync()
        filePromise.addOnResolvedListener { filePath in
          promise.resolve(result: PhotoFile(filePath: filePath))
        }
        filePromise.addOnRejectedListener { error in
          promise.reject(error: error)
        }
      } catch {
        promise.reject(error: error)
      }
    }
    photoPromise.addOnRejectedListener { error in
      promise.reject(error: error)
    }
    return promise
  }

  func prepareSettings(settings: [CapturePhotoSettings]) throws -> any Promise<Void> {
    let promise = Promise_void.pending()
    let captureSettings = try settings.map {
      try $0.toAVCapturePhotoSettings(for: self.output, withOptions: self.options)
    }
    self.output.setPreparedPhotoSettingsArray(captureSettings) { prepared, error in
      if let error {
        promise.reject(error: error)
      } else {
        if prepared {
          promise.resolve()
        } else {
          promise.reject(error: RuntimeError("Settings preparation has been canceled!"))
        }
      }
    }
    return promise
  }
}
