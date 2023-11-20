if (DEFINED CMAKE_GENERATOR)
    #message(STATUS "Codesigner running at configuration time")
    option(RCS_configure_time "Whether this script is running at configuration time" ON)
else ()
    # Otherwise we guess that it's running at build or installation time.
    #message(STATUS "Codesigner running at build/install time")
    option(RCS_configure_time "Whether this script is running at configuration time" OFF)
endif ()

if(RCS_configure_time)
    set(RCS_source_file ${CMAKE_CURRENT_LIST_FILE})
else()
    set(RCS_this_file      @rcs_this_file@)
    set(RCS_bundle_name    @rcs_bundle_name@)
    set(RCS_bundle_version @rcs_bundle_version@)
    set(RCS_working_dir    .                    CACHE FILEPATH "")
    set(RCS_install_dest   @rcs_install_dest@)
    if(NOT CMAKE_INSTALL_PREFIX)
        set(CMAKE_INSTALL_PREFIX @CMAKE_INSTALL_PREFIX@)
    endif()
    option(RCS_run_directly "" OFF)
endif()


function(RCS_add_codesign target)
    cmake_parse_arguments(RCSac "" "INSTALL_DESTINATION" "" ${ARGN})

    if(NOT RCSac_INSTALL_DESTINATION)
        set(RCSac_INSTALL_DESTINATION .)
    endif()
    
    set(rcs_install_dest ${RCSac_INSTALL_DESTINATION})

    set(rcs_this_file "${CMAKE_CURRENT_BINARY_DIR}/Codesigner_${target}.cmake")
    set(rcs_bundle_name ${target})
    get_target_property(rcs_bundle_version ${target} VERSION)

    configure_file(${RCS_source_file}
        ${rcs_this_file}
        @ONLY)

    install(SCRIPT ${rcs_this_file}
        DESTINATION .)
endfunction()

function(RCS_sign_configtime bundle working_dir)
    message(STATUS "Signning \"${bundle}.app\"")

    execute_process(COMMAND codesign --force --deep --sign=- "${bundle}.app"
        WORKING_DIRECTORY "${working_dir}"
        COMMAND_ERROR_IS_FATAL ANY)
endfunction()

if(NOT RCS_configure_time)
    #message(STATUS "RCS_working_dir = \"${RCS_working_dir}\"")
    if(NOT RCS_run_directly)


        execute_process(COMMAND ${CMAKE_COMMAND} -DRCS_run_directly:BOOL=ON -DRCS_working_dir=${CMAKE_INSTALL_PREFIX}/${RCS_install_dest} -P ${RCS_this_file}
            WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX}/${RCS_install_dest}
            COMMAND_ERROR_IS_FATAL ANY)
        return()
    endif()

    set(bundle_prefix "${RCS_working_dir}/${RCS_bundle_name}.app/Contents/MacOS")

    if(IS_SYMLINK "${bundle_prefix}/${RCS_bundle_name}")
        message(STATUS "Found symlink file ${bundle_prefix}/${RCS_bundle_name}")

        file(REMOVE "${bundle_prefix}/${RCS_bundle_name}")
        file(RENAME "${bundle_prefix}/${RCS_bundle_name}-${RCS_bundle_version}" "${bundle_prefix}/${RCS_bundle_name}")
    endif ()

    if(IS_SYMLINK "${bundle_prefix}/${RCS_bundle_name}")
        message(WARNING "\"${bundle_prefix}/${RCS_bundle_name}\" is a symlink, but it should be regular file.")
    endif ()

    execute_process(COMMAND codesign --force --deep --sign=- "${RCS_bundle_name}.app"
        WORKING_DIRECTORY ${RCS_working_dir}
        COMMAND_ERROR_IS_FATAL ANY)
endif()