#!/bin/bash
# LM Studio launcher script with AMD GPU support
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"
export VULKAN_SDK="/usr/"
export AMD_VULKAN_ICD_FILENAMES="/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"
export LIBVA_DRIVER_NAME=radeon
export VK_DRIVER_FILES="/usr/lib/x86_64-linux-gnu/vulkan/drivers/radeon_icd.x86_64.json"
export HSA_OVERRIDE_GFX_VERSION="11.0.0"
# Launch LM Studio with AMD GPU forced
/usr/bin/lm-studio "$@"
