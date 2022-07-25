#################################################################

function (test_func name)
    set (test_dir "${CMAKE_CURRENT_SOURCE_DIR}/${name}")
    set (asn1_schema ${PROJECT_SOURCE_DIR}/dsl/schema.xml)
    file (GLOB test_schema_files ${test_dir}/TestSchema*.xml)
    set (schema_files ${asn1_schema} ${test_schema_files})
    set (output_dir ${CMAKE_CURRENT_BINARY_DIR}/${name})
    set (asn1_code_input_dir "${PROJECT_SOURCE_DIR}/dsl_src")
    set (test_code_input_dir "${test_dir}/src")
    set (code_input_param)
    if (EXISTS "${test_code_input_dir}/")
        set (combined_code_input_dir ${CMAKE_CURRENT_BINARY_DIR}/${name}_src)
        execute_process (
            COMMAND ${CMAKE_COMMAND} -E make_directory ${combined_code_input_dir})

        execute_process (
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${asn1_code_input_dir}/ ${test_code_input_dir}/ ${combined_code_input_dir}/)
                    
        set (code_input_param -c ${combined_code_input_dir})
    else ()
        set (code_input_param -c ${asn1_code_input_dir})
    endif()

    set (rm_tmp_tgt ${name}_rm_tmp_tgt)
    add_custom_target(${rm_tmp_tgt}
        COMMAND ${CMAKE_COMMAND} -E remove_directory ${output_dir}.tmp
    )

    add_custom_command(
        OUTPUT ${output_dir}.tmp
        DEPENDS ${schema_files} ${rm_tmp_tgt}
        COMMAND ${COMMSDSL2COMMS_EXE} -d -s --warn-as-err -o ${output_dir}.tmp ${code_input_param} ${schema_files}
    )

    set (output_tgt ${name}_output_tgt)
    add_custom_target(${output_tgt} ALL
        COMMAND ${CMAKE_COMMAND}
            -DGENERATED="${output_dir}.tmp" -DOUTPUT="${output_dir}" -DCLEANUP_DIRS="doc;include" 
            -P "${PROJECT_SOURCE_DIR}/cmake/CopyGenerated.cmake"
        DEPENDS ${output_dir}.tmp "${PROJECT_SOURCE_DIR}/cmake/CopyGenerated.cmake" ${schema_files})


    set (build_tgt ${name}_build_tgt)
    set (build_dir ${output_dir}/build)
    set (install_dir ${build_dir}/install)

    execute_process (
        COMMAND ${CMAKE_COMMAND} -E make_directory "${build_dir}")

    add_custom_target(${build_tgt} ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory "${build_dir}"
        COMMAND 
            ${CMAKE_COMMAND} 
                ${output_dir}
                -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
                -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} 
                -DCMAKE_CXX_STANDARD=${CC_ASN1_TESTS_CXX_STANDARD}
                -DCMAKE_INSTALL_PREFIX=${install_dir}
                -DOPT_REQUIRE_COMMS_LIB=OFF
        COMMAND
            ${CMAKE_COMMAND} --build ${build_dir} --config ${CMAKE_BUILD_TYPE} --target install
        WORKING_DIRECTORY ${build_dir}
        DEPENDS ${output_tgt})    

    set (tests "${test_dir}/${name}Test.th")

    set (testName "${name}Test")

    set (valgrand_opt)
    if (CC_ASN1_VALGRIND_TESTS AND VALGRIND_EXECUTABLE)
        set (valgrand_opt VALGRIND_EXECUTABLE ${VALGRIND_EXECUTABLE})
    endif ()

    cc_cxxtest_add_test(NAME ${testName} SRC ${tests} ${valgrand_opt})

    add_dependencies(${testName} ${build_tgt})
    target_include_directories (${testName} PRIVATE "${install_dir}/include")

    target_compile_options(${testName} PRIVATE
        $<$<CXX_COMPILER_ID:MSVC>:/bigobj>
        $<$<CXX_COMPILER_ID:GNU>:-Wno-old-style-cast -ftemplate-depth=2048 ${CC_ASN1_SANITIZER_OPTS}>
        $<$<CXX_COMPILER_ID:Clang>:-Wno-old-style-cast -ftemplate-depth=2048 ${CC_ASN1_SANITIZER_OPTS}>
    )    

    if (NOT "${CC_ASN1_SANITIZER_OPTS}" STREQUAL "")
        target_link_options(${testName} PRIVATE
            $<$<CXX_COMPILER_ID:GNU>:${CC_ASN1_SANITIZER_OPTS}>
            $<$<CXX_COMPILER_ID:Clang>:${CC_ASN1_SANITIZER_OPTS}>
        ) 
    endif ()    

    if (CC_ASN1_TEST_BUILD_DOC AND DOXYGEN_FOUND)
        add_custom_target(doc_${name} ALL
            COMMAND COMMAND ${CMAKE_COMMAND} --build ${build_dir} --target doc_${name}
            DEPENDS ${build_tgt} 
        )
    endif ()
        
endfunction ()

#################################################################

if (NOT BUILD_TESTING)
    return ()
endif () 

if (NOT TARGET cc::comms)
    message (FATAL_ERROR "cc::comms target is not present")
endif ()

find_program(COMMSDSL2COMMS_EXE "commsdsl2comms" PATH_SUFFIXES bin REQUIRED)

if ((NOT "${CC_ASN1_SANITIZER_OPTS}" STREQUAL "") AND (NOT "${VALGRIND_EXECUTABLE}" STREQUAL ""))
    message (WARNING "Cannot run valgrind when tests compiled with sanitizers")
    set (VALGRIND_EXECUTABLE) # Disable valgrind tests
endif ()

find_package (Doxygen)

if (CMAKE_COMPILER_IS_GNUCC AND (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "7.9"))
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-ignored-qualifiers")
endif ()

test_func (test1)
