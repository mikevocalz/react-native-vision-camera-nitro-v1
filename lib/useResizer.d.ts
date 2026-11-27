import type { Resizer } from './specs/Resizer.nitro';
import type { ResizerOptions } from './specs/ResizerFactory.nitro';
/**
 * The current state of the {@linkcode useResizer} hook.
 * - `'loading'`: The {@linkcode Resizer} is still being created.
 * - `'ready'`: The {@linkcode Resizer} has been created successfully and is ready to use.
 * - `'error'`: Creating the {@linkcode Resizer} failed. Inspect `error` for details.
 */
export type ResizerState = {
    state: 'loading';
    resizer: undefined;
    error: undefined;
} | {
    state: 'ready';
    resizer: Resizer;
    error: undefined;
} | {
    state: 'error';
    resizer: undefined;
    error: Error;
};
/**
 * Use a {@linkcode Resizer} with the given options.
 *
 * The {@linkcode Resizer} can be used to resize and convert
 * {@linkcode Frame}s for ML processing.
 *
 * @discussion
 * Inspect the returned `error` if the {@linkcode Resizer}
 * couldn't be created successfully.
 *
 * @example
 * ```ts
 * function App() {
 *   const { resizer } = useResizer({
 *     width: 192,
 *     height: 192,
 *     channelOrder: 'rgb',
 *     dataType: 'float32',
 *     scaleMode: 'cover',
 *     pixelLayout: 'planar',
 *   })
 *
 *   const frameOutput = useFrameOutput({
 *     pixelFormat: 'yuv',
 *     onFrame(frame) {
 *       'worklet'
 *       if (resizer != null) {
 *         const resized = resizer.resize(frame)
 *         const buffer = resized.getPixelBuffer()
 *         resized.dispose()
 *       }
 *       frame.dispose()
 *     }
 *   })
 * }
 * ```
 */
export declare function useResizer({ height, width, channelOrder, dataType, scaleMode, pixelLayout, }: ResizerOptions): ResizerState;
