package com.margelo.nitro.camera.hybrids.gestures

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import androidx.camera.core.Camera
import androidx.camera.core.FocusMeteringAction
import androidx.camera.view.PreviewView
import com.margelo.nitro.NitroModules
import com.margelo.nitro.camera.FocusOptions
import com.margelo.nitro.camera.HybridCameraControllerSpec
import com.margelo.nitro.camera.HybridMeteringPointSpec
import com.margelo.nitro.camera.HybridTapToFocusGestureControllerSpec
import com.margelo.nitro.camera.ListenerSubscription
import com.margelo.nitro.camera.hybrids.HybridCameraController
import com.margelo.nitro.camera.hybrids.metering.HybridMeteringPoint
import com.margelo.nitro.camera.public.NativeGestureController
import com.margelo.nitro.core.Callback
import java.util.concurrent.CopyOnWriteArraySet

class HybridTapToFocusGestureController :
  HybridTapToFocusGestureControllerSpec(),
  NativeGestureController {
  override var controller: HybridCameraControllerSpec? = null

  private var previewView: PreviewView? = null
  // Added/removed on the JS thread, emitted on the main thread.
  private val onTapListeners = CopyOnWriteArraySet<Callback<(point: HybridMeteringPointSpec) -> Unit>>()
  private val onFocusCompletedListeners = CopyOnWriteArraySet<Callback<(point: HybridMeteringPointSpec) -> Unit>>()
  private val context: Context
    get() = NitroModules.applicationContext ?: throw Error("Context not available!")
  private val mainHandler = Handler(Looper.getMainLooper())
  private var isTracking = false
  private val gestureDetector =
    GestureDetector(
      context,
      object : GestureDetector.SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean {
          return true
        }

        override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
          val previewView =
            previewView
              ?: return false
          val controller = controller ?: return false

          val point = previewView.meteringPointFactory.createPoint(e.x, e.y)
          val density = context.resources.displayMetrics.density
          val meteringPoint = HybridMeteringPoint((e.x / density).toDouble(), (e.y / density).toDouble(), null, point)
          onTapListeners.forEach { it(meteringPoint) }
          controller
            .focusTo(meteringPoint, FocusOptions(null, null, null, null))
            .then {
              mainHandler.post {
                onFocusCompletedListeners.forEach { it(meteringPoint) }
              }
            }.catch { error ->
              Log.e(TAG, "Failed to focus!", error)
            }
          return true
        }
      },
      mainHandler,
    )

  override fun onTouchEvent(
    view: View,
    event: MotionEvent,
  ): Boolean {
    if (controller == null) {
      // No controller available
      return false
    }
    if (view !is PreviewView) {
      Log.e(TAG, "Received a tap on a View that is not a PreviewView! Tap To Focus cannot handle this.")
      return false
    }
    previewView = view

    if (event.pointerCount > 1) {
      // It's a multi-touch, ignore it
      isTracking = false
      return false
    }

    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        // Finger down
        isTracking = true
        gestureDetector.onTouchEvent(event)
        return true
      }
      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
        // Finger up again
        gestureDetector.onTouchEvent(event)
        isTracking = false
        return true
      }
      else -> {
        if (isTracking) {
          // continue tracking this event - whatever it is
          gestureDetector.onTouchEvent(event)
          return true
        }
        return false
      }
    }
  }

  override fun addOnTapListener(onTap: Callback<(point: HybridMeteringPointSpec) -> Unit>): ListenerSubscription {
    onTapListeners.add(onTap)
    return ListenerSubscription(
      Callback.Arity0<Unit> {
        onTapListeners.remove(onTap)
      },
    )
  }

  override fun addOnFocusCompletedListener(
    onFocusCompleted: Callback<(point: HybridMeteringPointSpec) -> Unit>,
  ): ListenerSubscription {
    onFocusCompletedListeners.add(onFocusCompleted)
    return ListenerSubscription(
      Callback.Arity0<Unit> {
        onFocusCompletedListeners.remove(onFocusCompleted)
      },
    )
  }
}
