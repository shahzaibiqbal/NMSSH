#!/usr/bin/env bash

# Yay shell scripting! This script builds a static version of
# libssh2 for iOS and OSX that contains code for armv6, armv7, armv7s, arm64, x86_64.

set -e
# set -x

BASE_PWD="$PWD"
OPENSSL_ROOT="${PWD%/*}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Setup paths to stuff we need


DEVELOPER=$(xcode-select --print-path)

export IPHONEOS_DEPLOYMENT_VERSION="7.0"
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONEOS_SDK_ROOT=$(xcrun --sdk iphoneos --show-sdk-platform-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
IPHONESIMULATOR_SDK_ROOT=$(xcrun --sdk iphonesimulator --show-sdk-platform-path)
GCC=$(xcrun --find clang)

# Turn versions like 1.2.3 into numbers that can be compare by bash.
version()
{
   printf "%03d%03d%03d%03d" $(tr '.' ' ' <<<"$1");
}

build()
{
   local ARCH=$1
   local OS=$2
   local BUILD_DIR=$3
   local TYPE=$4 # iphoneos/iphonesimulator/macosx/macosx_catalyst
   local SDKPATH=$5
   local ROOTPATH=$6

   local PREFIX="/tmp/libssh2${OS}-${ARCH}"
   local SSLROOT="${OPENSSL_ROOT}/OpenSSL/${TYPE}"
   local OPENSSL_CRYPTO_LIBRARY="${OPENSSL_ROOT}/OpenSSL/${TYPE}/lib/libcrypto.a"
   local OPENSSL_SSL_LIBRARY="${OPENSSL_ROOT}/OpenSSL/${TYPE}/lib/libssl.a"
   local OPENSSL_INCLUDE_DIR="${OPENSSL_ROOT}/OpenSSL/${TYPE}/include"
   mkdir -p "${SCRIPT_DIR}/../bin"
   rm -rf "${PREFIX}"
#   cd bin
   echo "--------------Build Info-------------"
   
   echo ${BASE_PWD}
   echo ${OPENSSL_CRYPTO_LIBRARY}
   echo ${OPENSSL_SSL_LIBRARY}
   echo ${OPENSSL_INCLUDE_DIR}
   echo ${SSLROOT}
   echo ${SDKPATH}
   echo ${ROOTPATH}
   echo "Building for ${OS} ${ARCH}"

   echo "Building ${PREFIX}"
   if [ -f "${BASE_PWD}/CMakeCache.txt" ]; then
    echo "cleaning old files"
    make clean
   fi
   
   cmake \
   -DCMAKE_OSX_DEPLOYMENT_TARGET=10.0 \
   -DCMAKE_C_COMPILER=${GCC} \
   -DONLY_ACTIVE_ARCH=YES \
   -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
   -DCMAKE_IOS_DEVELOPER_ROOT="${ROOTPATH}/Developer" \
   -DCMAKE_OSX_SYSROOT=${SDKPATH} \
   -DCMAKE_INSTALL_PREFIX=${PREFIX} \
   -DCRYPTO_BACKEND=OpenSSL \
   -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_CRYPTO_LIBRARY} \
   -DOPENSSL_SSL_LIBRARY=${OPENSSL_SSL_LIBRARY} \
   -DOPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR}
   
   echo "--------------------cmake Build---------------------"
   cmake --build . --target install
   
   echo "--------------------Building lipo---------------------"
   # Add arch to library
   if [ -f "${SCRIPT_DIR}/../${TYPE}/lib/libssh2.a" ]; then
      xcrun lipo "${SCRIPT_DIR}/../${TYPE}/lib/libssh2.a" "${PREFIX}/lib/libssh2.a" -create -output "${SCRIPT_DIR}/../${TYPE}/lib/libssh2.a"
   else
      cp -f "${PREFIX}/lib/libssh2.a" "${SCRIPT_DIR}/../${TYPE}/lib/libssh2.a"
   fi
   
    cp -R "${PREFIX}/include/" "${SCRIPT_DIR}/../${TYPE}/include/"
    cp -f "${OPENSSL_CRYPTO_LIBRARY}" "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a"
    cp -f "${OPENSSL_SSL_LIBRARY}" "${SCRIPT_DIR}/../${TYPE}/lib/libssl.a"
   
#   cd ..
   rm -rf "${SCRIPT_DIR}/../bin"
}

build_ios() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}

   build "i386" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator" ${IPHONESIMULATOR_SDK} ${IPHONESIMULATOR_SDK_ROOT} NO
   build "x86_64" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator" ${IPHONESIMULATOR_SDK} ${IPHONESIMULATOR_SDK_ROOT}
   build "arm64" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator" ${IPHONESIMULATOR_SDK} ${IPHONESIMULATOR_SDK_ROOT}
#
#   # The World is not ready for arm64e!
#   # build "arm64e" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
#
   rm -rf "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}

   build "armv7" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos" ${IPHONEOS_SDK} ${IPHONEOS_SDK_ROOT}
   build "armv7s" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos" ${IPHONEOS_SDK} ${IPHONEOS_SDK_ROOT}
   build "arm64" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos" ${IPHONEOS_SDK} ${IPHONEOS_SDK_ROOT}

  

   rm -rf ${TMP_BUILD_DIR}
}

generate_framwork() {
   local FRAMEWORK_PATH="${SCRIPT_DIR}/../framework"
   local PROJECT_PATH="${SCRIPT_DIR}/../"
   rm -rf ${FRAMEWORK_PATH}
   mkdir -p ${FRAMEWORK_PATH}
   
   XC_USER_DEFINED_VARS=""
   while getopts ":s" option; do
      case $option in
         s) # Build XCFramework as static instead of dynamic
            XC_USER_DEFINED_VARS="MACH_O_TYPE=staticlib"
      esac
   done
   
   FWNAME="XCLIBSSH2"
   COMMON_SETUP=" -project ${PROJECT_PATH}/${FWNAME}.xcodeproj -configuration Release -quiet BUILD_LIBRARY_FOR_DISTRIBUTION=YES $XC_USER_DEFINED_VARS"
   
   DERIVED_DATA_PATH=$( mktemp -d )
   
   xcrun xcodebuild build \
        $COMMON_SETUP \
        -scheme "${FWNAME} (iOS Simulator)" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -destination 'generic/platform=iOS Simulator'

    ditto "${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/${FWNAME}.framework" "${FRAMEWORK_PATH}/iphonesimulator/${FWNAME}.framework"
    rm -rf "${DERIVED_DATA_PATH}"
    
    
    DERIVED_DATA_PATH=$( mktemp -d )
    xcrun xcodebuild build \
        $COMMON_SETUP \
        -scheme "${FWNAME} (iOS)" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -destination 'generic/platform=iOS'
    
    ditto "${DERIVED_DATA_PATH}/Build/Products/Release-iphoneos/${FWNAME}.framework" "${FRAMEWORK_PATH}/iphoneos/${FWNAME}.framework"
    rm -rf "${DERIVED_DATA_PATH}"
    
    
    xcrun xcodebuild -quiet -create-xcframework \
        -framework "${FRAMEWORK_PATH}/iphoneos/${FWNAME}.framework" \
        -framework "${FRAMEWORK_PATH}/iphonesimulator/${FWNAME}.framework" \
        -output "${FRAMEWORK_PATH}/Frameworks/${FWNAME}.xcframework"
}

# Start

build_ios
generate_framwork

