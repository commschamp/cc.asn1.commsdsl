cmake_minimum_required (VERSION 3.1)
project ("cc_asn1")

option (CC_ASN1_WARN_AS_ERR "Treat warning as error" ON)
option (CC_ASN1_USE_CCACHE "Use ccache" OFF)
option (CC_ASN1_BUILD_APPS "Build applications." OFF)
option (CC_ASN1_BUILD_UNIT_TESTS "Build unittests." OFF)
option (CC_ASN1_VALGRIND_TESTS "Enable testing with valgrind (applicable when CC_ASN1_BUILD_UNIT_TESTS is on)" OFF)
option (CC_ASN1_USE_SANITIZERS "Build unittiests/apps with sanitizers" OFF)
option (CC_ASN1_TEST_BUILD_DOC "Build documentation target in generated projects (applicable when CC_ASN1_BUILD_UNIT_TESTS is on)" OFF)

# Additional variables to be used if needed
# ---------------------------
# CC_ASN1_EXTERNALS_DIR - Directory to contain sources for external projects, defaults to ${PROJECT_SOURCE_DIR}/externals.
# CC_ASN1_CCACHE_EXECUTABLE - Custom ccache executable

# Other built-in CMake variables that can be used
# ---------------------------
# CMAKE_CXX_STANDARD - C++ standard to be used for built applications
# CMAKE_PREFIX_PATH - Path(s) to find externals like COMMS library
# CMAKE_PROGRAM_PATH - Path(s) to find programs like commsdsl2comms to parse the schema files(s)

################################################

set (CC_ASN1_VERSION "0.3.2")
set (CC_ASN1_MIN_COMMSDSL_VERSION "6.3.4")

if ("${CMAKE_CXX_STANDARD}" STREQUAL "")
    set(CMAKE_CXX_STANDARD 17)
endif ()

if (NOT CC_ASN1_EXTERNALS_DIR)
    set (CC_ASN1_EXTERNALS_DIR "${PROJECT_SOURCE_DIR}/externals")
endif ()

################################################

set (CMAKE_SCIPTS_DIR "${PROJECT_SOURCE_DIR}/cmake")
include (${CMAKE_SCIPTS_DIR}/Asn1Compile.cmake)

# Compiler options
set (extra_opts)
if (CC_ASN1_WARN_AS_ERR)
    list (APPEND extra_opts WARN_AS_ERR)
endif ()

if (CC_ASN1_USE_CCACHE)
    list (APPEND extra_opts USE_CCACHE)
    if (NOT "${CC_ASN1_CCACHE_EXECUTABLE}" STREQUAL "")
        list (APPEND extra_opts CCACHE_EXECTUABLE "${CC_ASN1_CCACHE_EXECUTABLE}")
    endif ()  
endif ()

cc_asn1_compile(${extra_opts})
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

add_subdirectory (cc_asn1)
add_subdirectory (app)
add_subdirectory (test)

