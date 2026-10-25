import { Android, Apple, type HybridView } from 'react-native-nitro-modules'
import type { FrameRenderer } from '../FrameRenderer.nitro'

/**
 * The {@linkcode FrameRendererView} Hybrid View.
 *
 * A {@linkcode FrameRendererView} can be rendered via the
 * {@linkcode NativeFrameRendererView} component.
 *
 * @see {@linkcode FrameRendererViewProps}
 * @see {@linkcode FrameRendererViewMethods}
 * @see {@linkcode NativeFrameRendererView}
 */
@Apple({ language: 'swift', implementation: { className: 'HybridFrameRendererView' } })
@Android({ language: 'kotlin', implementation: { className: 'HybridFrameRendererView' } })
export declare class FrameRendererView extends HybridView {
  renderer?: FrameRenderer
}

export * from '#nitro/FrameRendererView'

/** The {@linkcode FrameRendererView} has no methods besides the HybridObject base. */
export type FrameRendererViewMethods = Record<string, never>
