#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR=$( dirname ${SCRIPT_DIR} )
BUILD_DIR="${ROOT_DIR}/build.clang"
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

CC=clang CXX=clang++ cmake .. -DCMAKE_INSTALL_PREFIX=install -DCMAKE_BUILD_TYPE=Debug -DCC_ASN1_BUILD_UNIT_TESTS=ON -DCC_ASN1_TEST_BUILD_DOC=ON "$@"
