import type { Image } from 'react-native-nitro-image'
import 'react-native-nitro-modules'
import type { Depth } from '../specs/instances/Depth.nitro'
import type { Frame } from '../specs/instances/Frame.nitro'
import { FrameConverter } from '../specs/utils/FrameConverter.nitro'

/**
 * The {@linkcode HybridFrameConverter} can be used to convert
 * {@linkcode Frame}s and {@linkcode Depth} frames to
 * {@linkcode Image}s.
 */
export const HybridFrameConverter: FrameConverter = new FrameConverter()
