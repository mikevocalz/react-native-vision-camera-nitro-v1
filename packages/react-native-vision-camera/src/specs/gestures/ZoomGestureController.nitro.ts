import { Android, Apple } from 'react-native-nitro-modules'
import type { CameraController } from '../CameraController.nitro'
import { GestureController } from './GestureController.nitro'

/**
 * A {@linkcode ZoomGestureController} is a {@linkcode GestureController}
 * that can modify a {@linkcode CameraController}'s
 * {@linkcode CameraController.zoom | zoom} via a
 * native pinch-to-zoom gesture.
 */
@Apple({ language: 'swift', allowMultipleImplementations: true })
@Android({ language: 'kotlin', allowMultipleImplementations: true })
export declare class ZoomGestureController extends GestureController {}

export * from '#nitro/ZoomGestureController'
