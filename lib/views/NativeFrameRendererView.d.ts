import { type FrameRendererView } from '../specs/views/FrameRendererView.nitro';
/**
 * The `<NativeFrameRendererView />` component.
 *
 * @see {@linkcode FrameRendererView}
 * @see {@linkcode FrameRendererViewProps}
 * @see {@linkcode FrameRendererViewMethods}
 */
export declare const NativeFrameRendererView: import("react-native").HostComponent<import("react-native").ViewProps & Pick<FrameRendererView, "renderer"> & {
    hybridRef?: (view: import("..").FrameRendererViewRef) => void;
}>;
