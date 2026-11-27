import { Android, Apple } from 'react-native-nitro-modules'
import type { CameraController } from '../CameraController.nitro'
import type { ListenerSubscription } from '../common-types/ListenerSubscription'
import { GestureController } from './GestureController.nitro'

/**
 * A {@linkcode ZoomGestureController} is a {@linkcode GestureController}
 * that can modify a {@linkcode CameraController}'s
 * {@linkcode CameraController.zoom | zoom} via a
 * native pinch-to-zoom gesture.
 */
@Apple({ language: 'swift', allowMultipleImplementations: true })
@Android({ language: 'kotlin', allowMultipleImplementations: true })
export declare class ZoomGestureController extends GestureController {
  /**
   * Adds a listener that is called whenever this native pinch gesture
   * changes the target zoom factor.
   *
   * The listener can be called many times during one pinch gesture.
   * Call {@linkcode ListenerSubscription.remove | remove()} on the returned
   * subscription to stop receiving updates.
   */
  addOnZoomChangedListener(
    onZoomChanged: (zoom: number) => void,
  ): ListenerSubscription
}

export * from '#nitro/ZoomGestureController'
