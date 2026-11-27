import { useEffect, useState } from 'react';
import { createResizer } from './createResizer';
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
export function useResizer({ height, width, channelOrder, dataType, scaleMode, pixelLayout, }) {
    const [state, setState] = useState({
        state: 'loading',
        resizer: undefined,
        error: undefined,
    });
    useEffect(() => {
        let isCanceled = false;
        const load = async () => {
            try {
                const resizer = await createResizer({
                    width: width,
                    height: height,
                    channelOrder: channelOrder,
                    dataType: dataType,
                    scaleMode: scaleMode,
                    pixelLayout: pixelLayout,
                });
                if (isCanceled)
                    return;
                setState({ state: 'ready', resizer: resizer, error: undefined });
            }
            catch (error) {
                setState({ state: 'error', resizer: undefined, error: error });
            }
        };
        load();
        return () => {
            isCanceled = true;
        };
    }, [channelOrder, dataType, height, pixelLayout, scaleMode, width]);
    return state;
}
