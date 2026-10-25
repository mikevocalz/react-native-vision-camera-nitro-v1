import { Android, Apple } from 'react-native-nitro-modules'
import type { CameraController } from '../CameraController.nitro'
import { GestureController } from './GestureController.nitro'

/**
 * A {@linkcode TapToFocusGestureController} is a {@linkcode GestureController}
 * that can trigger a {@linkcode CameraController}'s
 * {@linkcode CameraController.focusTo | focusTo(...)}
 * action via a native tap to focus gesture.
 */
@Apple({ language: 'swift', allowMultipleImplementations: true })
@Android({ language: 'kotlin', allowMultipleImplementations: true })
export declare class TapToFocusGestureController extends GestureController {}

export * from '#nitro/TapToFocusGestureController'
