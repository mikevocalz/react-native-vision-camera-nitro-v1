///
/// HybridResizerFactory.hpp
/// VisionCamera
/// Copyright © 2026 Marc Rousavy @ Margelo
///

#pragma once

#include "HybridResizer.hpp"
#include <VisionCameraResizer/HybridResizerFactorySpec.hpp>
#include <VisionCameraResizer/HybridResizerSpecCxx.hpp>

namespace margelo::nitro::camera::resizer {

class HybridResizerFactory : public HybridResizerFactorySpec {
public:
  HybridResizerFactory();

  bool isAvailable() override;
  Promise<HybridResizerSpecCxx> createResizer(const ResizerOptions& options) override;
};

} // namespace margelo::nitro::camera::resizer
