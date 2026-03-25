#!/bin/bash

if [[ -z "${CUDA_HOME+x}" ]]; then
  # `$CUDA_HOME` was set for CUDA 11.x and earlier.
  # Must be using CUDA 12.0+. So set to `$BUILD_PREFIX`.
  # This is needed to find `nvcc` and `cudart`.
  export CUDA_HOME="${BUILD_PREFIX}"
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" ]]; then
    if [[ "${target_platform}" == "linux-aarch64" ]]; then
        export CUDA_LIB="${CUDA_HOME}/targets/sbsa-linux/lib/"
    elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
        export CUDA_LIB="${CUDA_HOME}/targets/ppc64le-linux/lib/"
    else
        echo "not supported"
        exit 1
    fi
fi

# Why NVCC_APPEND_FLAGS?
#
#  NVCC resolves conflicting flags by using the last value. We use NVCC_APPEND_FLAGS
#  to ensure our flags come after those set in NCCL's Makefile.
#
# Added flags:
#
#  -std=c++17: GCC 14's libstdc++ headers use C++17 inline variables and built-in traits
#    that NVCC's EDG frontend cannot parse unless host compilation is also C++17.
#    NCCL's Makefile hardcodes -std=c++11, so addition of this flag produces a harmless warning:
#    "nvcc warning : incompatible redefinition for option 'std', the last value of this option was used"
#    Reference: https://github.com/NVIDIA/nccl/blob/v2.25.1-1/makefiles/common.mk
#
#  -Wno-deprecated-gpu-targets: Suppress warnings about deprecated GPU targets
#    (sm_50, sm_52, etc.) included in NVCC_GENCODE for broad compatibility.
export NVCC_APPEND_FLAGS="${NVCC_APPEND_FLAGS} -std=c++17 -Wno-deprecated-gpu-targets"

# Additional flags to make command:
#  -j${CPU_COUNT}: Build with the number of CPUs specified by the CPU_COUNT environment variable.
make -j${CPU_COUNT} src.lib

make install PREFIX="${PREFIX}"

# Delete static library
rm "${PREFIX}/lib/libnccl_static.a"
