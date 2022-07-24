cmake_minimum_required (VERSION 3.1)
project ("cc_asn1")

option (CC_ASN1_WARN_AS_ERR "Treat warning as error" ON)
option (CC_ASN1_USE_CCACHE "Use ccache on UNIX systems if it's available" ON)
option (CC_ASN1_BUILD_APPS "Build applications." OFF)
option (CC_ASN1_BUILD_UNIT_TESTS "Build unittests." OFF)
option (CC_ASN1_VALGRIND_TESTS "Enable testing with valgrind (applicable when CC_ASN1_BUILD_UNIT_TESTS is on)" OFF)
option (CC_ASN1_USE_SANITIZERS "Build unittiests/apps with sanitizers" OFF)
option (CC_ASN1_TEST_BUILD_DOC "Build documentation target in generated projects (applicable when CC_ASN1_BUILD_UNIT_TESTS is on)" OFF)
#option (CC_ASN1_EXTERNAL_COMMS "COMMS library is external, don't pull it it when needed" OFF)
#option (CC_ASN1_EXTERNAL_COMMSDSL2COMMS "commsdsl2comms code generator is external, don't build it when needed" OFF)

# Additional variables to be used if needed
# ---------------------------
# CC_ASN1_TESTS_CXX_STANDARD - C++ standard to use in unittests
# CC_ASN1_EXTERNALS_DIR - Directory to contain sources for external projects, defaults to ${PROJECT_SOURCE_DIR}/externals.

################################################

if (NOT CC_ASN1_EXTERNALS_DIR)
    set (CC_ASN1_EXTERNALS_DIR "${PROJECT_SOURCE_DIR}/externals")
endif ()

if (NOT CC_ASN1_TESTS_CXX_STANDARD)
    set (CC_ASN1_TESTS_CXX_STANDARD 11)
endif ()

################################################

set (CMAKE_SCIPTS_DIR "${PROJECT_SOURCE_DIR}/cmake")
include (${CMAKE_SCIPTS_DIR}/Asn1Funcs.cmake)
include (${CMAKE_SCIPTS_DIR}/Asn1Compile.cmake)

# Compiler options
set (warn_opt)
if (CC_ASN1_WARN_AS_ERR)
    set (warn_opt WARN_AS_ERR)
endif ()

set (ccache_opt)
if ((UNIX) AND (CC_ASN1_USE_CCACHE))
    set (ccache_opt USE_CCACHE)
endif ()

cc_asn1_compile(${warn_opt} ${ccache_opt})
cc_asn1_msvc_force_warn_opt("/W4")

set (CC_ASN1_FOUND_COMMS_INTERNAL OFF CACHE INTERNAL "Mark COMMS library found" FORCE)
function (cc_asn1_mark_comms_found)
    set (CC_ASN1_FOUND_COMMS_INTERNAL ON CACHE INTERNAL "Mark COMMS library found" FORCE)
endfunction ()

################################################


if (CC_ASN1_BUILD_UNIT_TESTS)
    find_package(LibComms REQUIRED)
    if ("${LibComms_DIR}" STREQUAL "")
        message (FATAL_ERROR "The comms library found but the directory is not known")
    endif ()        
    set (CC_CMAKE_DIR ${LibComms_DIR})

    include (${CC_CMAKE_DIR}/CC_CxxtestFuncs.cmake)
    cc_get_cxxtest(INSTALL_PREFIX ${CC_ASN1_EXTERNALS_DIR})

    if (CC_ASN1_VALGRIND_TESTS)
        find_program(VALGRIND_EXECUTABLE NAMES "valgrind")
    endif ()    

    enable_testing()
endif ()   

################################################

include (GNUInstallDirs)
install(
    DIRECTORY dsl src DESTINATION ${CMAKE_INSTALL_FULL_DATADIR}/${PROJECT_NAME}
)

add_subdirectory (app)
add_subdirectory (test)

