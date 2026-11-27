import type { NativeThread } from 'react-native-vision-camera';
import { type WorkletRuntime } from 'react-native-worklets';
/**
 * Creates a new `WorkletRuntime` that schedules its work on the given
 * {@linkcode NativeThread}.
 *
 * This wraps a Camera-owned {@linkcode NativeThread} in a
 * [react-native-worklets](https://docs.swmansion.com/react-native-worklets/docs/)
 * `WorkletRuntime` so that Worklets (such as Frame Processors) can run directly
 * on the Camera pipeline's thread without context switching.
 */
export declare function createWorkletRuntimeForThread(thread: NativeThread): WorkletRuntime;
