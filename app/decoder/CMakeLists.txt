if (NOT TARGET cc::comms)
    message (FATAL_ERROR "cc::comms target is not present")
endif ()

find_program(COMMSDSL2COMMS_EXE "commsdsl2comms" PATH_SUFFIXES bin REQUIRED)

execute_process(COMMAND "${COMMSDSL2COMMS_EXE}" --version OUTPUT_VARIABLE commsdsl2comms_version)
if ("${commsdsl2comms_version}" VERSION_LESS "${CC_ASN1_MIN_COMMSDSL_VERSION}")
    message (FATAL_ERROR "Version of commsdsl2comms is too old, required minimum is v${CC_ASN1_MIN_COMMSDSL_VERSION}.")
endif ()

set (name "cc_asn1_decoder")
set (asn1_schema ${PROJECT_SOURCE_DIR}/cc_asn1/dsl/schema.xml)
file (GLOB app_schema_files dsl/*.xml)
set (schema_files ${asn1_schema} ${app_schema_files})
set (output_dir ${CMAKE_CURRENT_BINARY_DIR}/protocol)
set (asn1_code_input_dir "${PROJECT_SOURCE_DIR}/cc_asn1/dsl_src")
set (app_code_input_dir "${CMAKE_CURRENT_SOURCE_DIR}/dsl_src")
set (code_input_param)
if (EXISTS "${app_code_input_dir}/")
    set (combined_code_input_dir ${CMAKE_CURRENT_BINARY_DIR}/${name}_src)
    execute_process (
        COMMAND ${CMAKE_COMMAND} -E make_directory ${combined_code_input_dir})

    execute_process (
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${asn1_code_input_dir}/ ${app_code_input_dir}/ ${combined_code_input_dir}/)
                
    set (code_input_param -c ${combined_code_input_dir})
else ()
    set (code_input_param -c ${asn1_code_input_dir})
endif()

set (output_tgt ${name}_output_tgt)
add_custom_target(${output_tgt} ALL
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${output_dir}.tmp
    COMMAND ${COMMSDSL2COMMS_EXE} -V ${CC_ASN1_VERSION} -d -s --warn-as-err 
        -o ${output_dir}.tmp ${code_input_param} ${schema_files}    
    COMMAND ${CMAKE_COMMAND}
        -DGENERATED="${output_dir}.tmp" -DOUTPUT="${output_dir}" -DCLEANUP_DIRS="doc;include" 
        -P "${PROJECT_SOURCE_DIR}/cmake/CopyGenerated.cmake"
    DEPENDS "${PROJECT_SOURCE_DIR}/cmake/CopyGenerated.cmake" ${schema_files})


set (build_dir ${CMAKE_CURRENT_BINARY_DIR}/protocol_build)
set (install_dir ${CMAKE_CURRENT_BINARY_DIR}/protocol_install)

execute_process (
    COMMAND ${CMAKE_COMMAND} -E make_directory "${build_dir}")

add_custom_target(${name}_build_tgt ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory "${build_dir}"
    COMMAND 
        ${CMAKE_COMMAND} 
            ${output_dir}
            -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} 
            -DCMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD}
            -DCMAKE_INSTALL_PREFIX=${install_dir}
            -DOPT_REQUIRE_COMMS_LIB=OFF
    COMMAND
        ${CMAKE_COMMAND} --build ${build_dir} --config ${CMAKE_BUILD_TYPE} --target install
    WORKING_DIRECTORY ${build_dir}
    DEPENDS ${output_tgt})

#############################################################################

set (src
    src/decoder.cpp
)

add_executable(${name} ${src})
target_link_libraries(${name} cc::comms)
target_include_directories(${name} PRIVATE ${install_dir}/include)
target_compile_options(${name} PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:-D_CRT_SECURE_NO_WARNINGS>
)       

add_dependencies(${name} ${name}_build_tgt)

install (
    TARGETS ${name}
    DESTINATION ${CMAKE_INSTALL_FULL_BINDIR}
)