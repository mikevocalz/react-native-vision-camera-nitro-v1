import type { RuntimeThreadProvider } from 'react-native-vision-camera';
export * from './createAsyncRunner';
export * from './createRuntimeThreadProvider';
export * from './createWorkletRuntimeForThread';
export * from './getCurrentThreadMarker';
export * from './specs/WorkletQueueFactory.nitro';
/**
 * The default {@linkcode RuntimeThreadProvider} instance that
 * `react-native-vision-camera` lazily requires through its module proxy.
 */
export declare const provider: RuntimeThreadProvider;
