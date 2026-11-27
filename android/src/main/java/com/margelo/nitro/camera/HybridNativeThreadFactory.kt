package com.margelo.nitro.camera

import androidx.annotation.Keep
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.camera.hybrids.HybridNativeThread
import com.margelo.nitro.camera.utils.IdentifiableExecutor

@Keep
@DoNotStrip
class HybridNativeThreadFactory : HybridNativeThreadFactorySpec() {
  companion object : HybridNativeThreadFactorySpec.Companion {
    override fun constructor(): HybridNativeThreadFactory = HybridNativeThreadFactory()
  }

  override fun createNativeThread(name: String): HybridNativeThreadSpec {
    val executor = IdentifiableExecutor(name)
    return HybridNativeThread(executor)
  }
}
