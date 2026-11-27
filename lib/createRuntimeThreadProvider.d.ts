import type { RuntimeThreadProvider } from 'react-native-vision-camera';
/**
 * Creates the default {@linkcode RuntimeThreadProvider} implementation that
 * bridges `react-native-vision-camera` with
 * [react-native-worklets](https://docs.swmansion.com/react-native-worklets/docs/).
 *
 * `react-native-vision-camera` lazily requires this provider through its module
 * proxy, so installing `react-native-vision-camera-worklets` is usually all that
 * is needed to enable Worklet-based Frame Processors.
 *
 * @see {@linkcode RuntimeThreadProvider}
 */
export declare function createRuntimeThreadProvider(): RuntimeThreadProvider;
