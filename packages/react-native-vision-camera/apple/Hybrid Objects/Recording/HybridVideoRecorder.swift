///
/// HybridVideoRecorder.swift
/// VisionCamera
/// Copyright © 2025 Marc Rousavy @ Margelo
///

import AVFoundation
import Foundation
import NitroModules

// `@unchecked Sendable`: V1 Promise closures are `@Sendable`; recorder state is only mutated on its serial `queue`.
final class HybridVideoRecorder: HybridRecorderSpec, @unchecked Sendable {
  private let videoOutput: AVCaptureMovieFileOutput
  private let queue: DispatchQueue
  private let fileURL: URL
  private let settings: RecorderSettings
  private var isCancelled = false

  init(
    videoOutput: AVCaptureMovieFileOutput,
    queue: DispatchQueue,
    fileType: RecorderFileType,
    settings: RecorderSettings
  ) throws {
    self.videoOutput = videoOutput
    self.queue = queue
    if let customFilePath = settings.filePath {
      self.fileURL = URL(fileURLWithPath: customFilePath)
    } else {
      self.fileURL = try URL.createTempURL(fileType: fileType.toUTType())
    }
    // Create all parent directories if they don't exist yet.
    try FileManager.default.createDirectory(
      at: self.fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    self.settings = settings
    try super.init()
  }

  var isRecording: Bool {
    return videoOutput.isRecording
  }
  var isPaused: Bool {
    guard #available(iOS 18.0, *) else {
      return false
    }
    return videoOutput.isRecordingPaused
  }
  var recordedDuration: Double {
    return videoOutput.recordedDuration.seconds
  }
  var recordedFileSize: Double {
    return Double(videoOutput.recordedFileSize)
  }
  var filePath: String {
    return fileURL.path
  }

  func startRecording(
    onRecordingFinished: any Callback<(String, RecordingFinishedReason), Void>,
    onRecordingError: any Callback<any Error, Void>,
    onRecordingPaused: (any Callback<(), Void>)?,
    onRecordingResumed: (any Callback<(), Void>)?
  ) throws -> any Promise<Void> {
    let promise = Promise_void.pending()
    // Only touched from the AVCaptureFileOutput delegate callbacks, which AVFoundation serializes.
    nonisolated(unsafe) var isResolved = false

    queue.async {
      // On our serial queue, make sure we are connected to the Camera
      guard self.videoOutput.connection(with: .video) != nil else {
        let error = RuntimeError("VideoOutput is not yet connected to the CameraSession!")
        promise.reject(error: error)
        return
      }
      // On our serial queue, make sure we are currently not recoring
      guard !self.videoOutput.isRecording else {
        let error = RuntimeError("Active recording already in progress!")
        promise.reject(error: error)
        return
      }

      // Prepare the delegate to resolve the Promise and notify listeners
      let delegate = VideoDelegate(
        onRecordingStarted: {
          // Recording started!
          promise.resolve()
          isResolved = true
        },
        onRecordingPaused: onRecordingPaused.map { callback in { callback() } },
        onRecordingResumed: onRecordingResumed.map { callback in { callback() } },
        onRecordingFinished: { url, reason in
          if self.isCancelled {
            // Recording was cancelled - delete the file
            try? FileManager.default.removeItem(at: url)
            return
          }
          // Recording finished!
          onRecordingFinished(url.path, reason)
        },
        onRecordingError: { error in
          if !isResolved {
            // We failed to even start the video recording!
            promise.reject(error: error)
            isResolved = true
          } else {
            // An error occurred later on
            onRecordingError(error)
          }
        })

      // Apply recording limits. `AVCaptureMovieFileOutput` delivers the file
      // via the success path when either limit is reached (see `VideoDelegate`).
      if let maxDuration = self.settings.maxDuration {
        self.videoOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 600)
      } else {
        self.videoOutput.maxRecordedDuration = .invalid
      }
      if let maxFileSize = self.settings.maxFileSize {
        self.videoOutput.maxRecordedFileSize = Int64(maxFileSize)
      } else {
        self.videoOutput.maxRecordedFileSize = 0
      }

      // Start recording!
      self.videoOutput.startRecording(to: self.fileURL, recordingDelegate: delegate)
    }
    return promise
  }

  func stopRecording() throws -> any Promise<Void> {
    return .parallel(queue) {
      self.videoOutput.stopRecording()
    }
  }

  func pauseRecording() throws -> any Promise<Void> {
    return .parallel(queue) {
      guard #available(iOS 18.0, *) else {
        throw RuntimeError("`pauseRecording()` is only available on iOS 18 or above!")
      }
      self.videoOutput.pauseRecording()
    }
  }

  func resumeRecording() throws -> any Promise<Void> {
    return .parallel(queue) {
      guard #available(iOS 18.0, *) else {
        throw RuntimeError("`resumeRecording()` is only available on iOS 18 or above!")
      }
      self.videoOutput.resumeRecording()
    }
  }

  func cancelRecording() throws -> any Promise<Void> {
    return .parallel(queue) {
      guard self.videoOutput.isRecording else {
        throw RuntimeError("Not currently recording!")
      }
      // Mark as cancelled so the onRecordingFinished callback
      // deletes the file instead of notifying the caller
      self.isCancelled = true
      self.videoOutput.stopRecording()
    }
  }
}
