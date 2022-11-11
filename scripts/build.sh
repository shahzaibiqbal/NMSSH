#!/usr/bin/env bash

set -e
# set -x


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BASE_PWD=$(dirname -- ${SCRIPT_DIR})

build_openssl()
{
    if [ ! -d "${BASE_PWD}/OpenSSL" ]; then
            (cd ${BASE_PWD} ; git clone https://github.com/krzyzanowskim/OpenSSL.git)
    fi
    
    OPENSSL_VERSION=1.1.1s sh "${SCRIPT_DIR}/../OpenSSL/scripts/build.sh"
}

build_libssh2()
{
    LIBSSH2_VERSION=$(git ls-remote --sort="version:refname" --tags --refs https://github.com/libssh2/libssh2.git | awk '{print $2}' | grep -v '{}' | awk -F"/" '{print $3}' | tail -n 2 | head -n 1)
    
    if [ ! -d "${SCRIPT_DIR}/../${LIBSSH2_VERSION}" ]; then
        curl -fL "https://github.com/libssh2/libssh2/releases/download/${LIBSSH2_VERSION}/${LIBSSH2_VERSION}.tar.gz" -o "${SCRIPT_DIR}/../${LIBSSH2_VERSION}.tar.gz"
        
        tar -xvf "${SCRIPT_DIR}/../${LIBSSH2_VERSION}.tar.gz"
    fi

    echo "copying things"
    ditto "${SCRIPT_DIR}/libssh2_build.sh" "${SCRIPT_DIR}/../${LIBSSH2_VERSION}/script/libssh2_build.sh"
    ditto "${SCRIPT_DIR}/xcode_templates" "${SCRIPT_DIR}/../${LIBSSH2_VERSION}/xcode_templates"
    ditto "${SCRIPT_DIR}/XCLIBSSH2.xcodeproj" "${SCRIPT_DIR}/../${LIBSSH2_VERSION}/XCLIBSSH2.xcodeproj"
    ditto "${SCRIPT_DIR}/libssh2.xcconfig" "${SCRIPT_DIR}/../${LIBSSH2_VERSION}/libssh2.xcconfig"
    (cd ${SCRIPT_DIR}/../${LIBSSH2_VERSION}/ ; sh script/libssh2_build.sh)
    
    ditto "${BASE_PWD}/${LIBSSH2_VERSION}/framework/Frameworks/XCLIBSSH2.xcframework" "${BASE_PWD}/NMSSH-iOS/XCLIBSSH2.xcframework"

}

build_openssl
build_libssh2

