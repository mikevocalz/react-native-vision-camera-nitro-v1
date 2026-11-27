import { type AsyncRunner } from 'react-native-vision-camera';
/**
 * Creates a new {@linkcode AsyncRunner} backed by a dedicated {@linkcode NativeThread}.
 *
 * An {@linkcode AsyncRunner} can be used inside a Frame Processor to offload
 * work to a separate thread without blocking the Camera pipeline.
 *
 * @discussion
 * This is the Worklets-based implementation used by the default
 * {@linkcode RuntimeThreadProvider}. Most users should use
 * {@linkcode useAsyncRunner | useAsyncRunner()} instead.
 *
 * @see {@linkcode useAsyncRunner}
 */
export declare function createAsyncRunner(): AsyncRunner;
