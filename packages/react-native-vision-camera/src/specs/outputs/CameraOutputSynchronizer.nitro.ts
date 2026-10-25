import { Android, Apple, type HybridObject } from 'react-native-nitro-modules'
import type { FrameDroppedReason } from '../common-types/FrameDroppedReason'
import type { MediaType } from '../common-types/MediaType'
import type { NativeThread } from '../frame-processors/NativeThread.nitro'
import type { Depth } from '../instances/Depth.nitro'
import type { Frame } from '../instances/Frame.nitro'
import type { CameraDepthFrameOutput } from './CameraDepthFrameOutput.nitro'
import type { CameraFrameOutput } from './CameraFrameOutput.nitro'
import { CameraOutput } from './CameraOutput.nitro'

/**
 * A {@linkcode CameraOutputSynchronizer} synchronizes 2 or more
 * {@linkcode CameraOutput}s to align their timestamps.
 *
 * The most common use-case is to synchronize a
 * {@linkcode CameraFrameOutput} and a {@linkcode CameraDepthFrameOutput}
 * to ensure the delivered {@linkcode Frame} and {@linkcode Depth}
 * are synchronized.
 *
 * When an output is connected to the {@linkcode CameraOutputSynchronizer}
 * you should no longer use its own frame callback, but instead
 * use the {@linkcode setOnFramesCallback} provided here.
 *
 * @platform iOS
 */
@Apple({ language: 'swift', allowMultipleImplementations: true })
@Android({ language: 'kotlin', allowMultipleImplementations: true })
export declare class CameraOutputSynchronizer extends HybridObject {
  /**
   * The {@linkcode NativeThread} this
   * {@linkcode CameraOutputSynchronizer} is running on.
   */
  readonly thread: NativeThread
  /**
   * The list of {@linkcode CameraOutput}s that are connected to this
   * {@linkcode CameraOutputSynchronizer}.
   */
  readonly outputs: CameraOutput[]
  /**
   * Set the callback to be called when a new set of synchronized
   * Frames arrive.
   * @note This method has to be called on a Worklet running on this {@linkcode thread}.
   */
  setOnFramesCallback(
    onFrames: ((frames: (Frame | Depth)[]) => boolean) | undefined,
  ): void
  /**
   * Sets the callback that gets called when a {@linkcode Frame} or
   * {@linkcode Depth}-frame has been dropped, possibly due to a long
   * drift in timelines.
   */
  setOnFrameDroppedCallback(
    onFrameDropped:
      | ((frameType: MediaType, reason: FrameDroppedReason) => void)
      | undefined,
  ): void
}

export * from '#nitro/CameraOutputSynchronizer'
