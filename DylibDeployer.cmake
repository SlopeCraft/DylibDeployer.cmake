cmake_minimum_required(VERSION 3.20)

if (DEFINED CMAKE_GENERATOR)
    message(STATUS "Running at configuration time")
    option(DLLD_configure_time "Whether this script is running at configuration time" ON)
else ()
    # Otherwise we guess that it's running at build or installation time.
    message(STATUS "Running at build/install time")
    option(DLLD_configure_time "Whether this script is running at configuration time" OFF)
endif ()

if (NOT ${APPLE})
    message(FATAL_ERROR "This project is designed to deploy dll on windows.")
    return()
endif ()

function(DylibD_is_dylib library_file out_var_name)
    
    cmake_path(GET library_file EXTENSION extension)
    string(TOLOWER ${extension} extension)
    if(extension MATCHES .dylib)
        set(${out_var_name} ON PARENT_SCOPE)
        return()
    endif()
    set(${out_var_name} OFF PARENT_SCOPE)
endfunction()

function(DylibD_is_system_dylib lib_location out_var_name)
    DylibD_is_dylib(${lib_location} is_dylib)
    if(NOT ${is_dylib})
        message(WARNING "The given file \"${lib_location}\" is not an dynamic library.")
        set(${out_var_name} OFF PARENT_SCOPE)
        return()
    endif()

    set(${out_var_name} OFF PARENT_SCOPE)

    set(DLLD_system_prefixes
        /usr/lib/
        /usr/lib/system/
        /usr/local/lib/
        /var/lib/)

    foreach (system_prefix ${DLLD_system_prefixes})
        if(${lib_location} MATCHES ${system_prefix})
            set(${out_var_name} ON PARENT_SCOPE)
            return()
        endif()
    endforeach ()

endfunction()


function(DylibD_get_install_names lib_location out_list_name)

    if(IS_SYMLINK ${lib_location})
        file(REAL_PATH ${lib_location} lib_location)
        message(STATUS "Link resolved to \"${lib_location}\"")
    endif()

    cmake_path(GET lib_location STEM given_lib_stem)

    execute_process(COMMAND otool -L "${lib_location}"
        OUTPUT_VARIABLE output
        OUTPUT_STRIP_TRAILING_WHITESPACE
        COMMAND_ERROR_IS_FATAL ANY
    )
    #message(STATUS "Original output: \n${output}")

    string(REPLACE "\n" ";" output ${output})
    #message(STATUS "output: \n${output}")

    
    list(POP_FRONT output)
    #message(STATUS "Processed output: \n${output}")

    set(result)
    foreach(str ${output})
        string(LENGTH ${str} len)
        if(${len} LESS_EQUAL 0)
            continue()
        endif()

        string(FIND ${str} "(compatibility" index REVERSE)
        if(${index} LESS 0)
            message(FATAL_ERROR "Failed to parse otool -L output: \nstring \"${str}\" should contain substring \"(compatibility\", but not found.")
        endif()

        #message(STATUS "dep: \"${str}\"  len = ${len}, index = ${index}")

        string(SUBSTRING ${str} 0 ${index} substr)
        string(STRIP ${substr} substr)
        #message(STATUS "substr: \"${substr}\"")

        cmake_path(GET substr STEM dep_stem)
        #message(STATUS "stem = \"${dep_stem}\"")
        if(${dep_stem} STREQUAL ${given_lib_stem})
            continue()
        endif()

        list(APPEND result ${substr})

    endforeach()
    
    set(${out_list_name} ${result} PARENT_SCOPE)
    
endfunction()

function(DylibD_resolve_install_name install_name out_var)
    cmake_parse_arguments(DDrin "" "EXE_PATH;LOADER_PATH;RPATH" "" ${ARGN})

    string(REPLACE "@executable_path" ${DDrin_EXE_PATH} install_name ${install_name})
    string(REPLACE "@loader_path" ${DDrin_LOADER_PATH} install_name ${install_name})
    string(REPLACE "@rpath" ${DDrin_RPATH} install_name ${install_name})

    set(${out_var} ${install_name} PARENT_SCOPE)
endfunction()


function(DylibD_deploy_libs bin_location)
    cmake_parse_arguments(DDdl "" "FRAMEWORK_DIR;EXEC_PATH" "" ${ARGN})

    if(${bin_location} MATCHES ".dylib")
        if(DDdl_EXEC_PATH)
            message(WARNING "You should not set EXEC_PATH when given binary is an executable. The given value will be overwritten.")
        endif()
        cmake_path(GET bin_location PARENT_DIRECTORY DDdl_EXEC_PATH)
    endif()

    message(STATUS "DDdl_EXEC_PATH = \"${DDdl_EXEC_PATH}\"")
    message(STATUS "DDdl_RAMEWORK_DIR = \"${DDdl_RAMEWORK_DIR}\"")

    DylibD_get_install_names(${bin_location} install_names)
    message(STATUS "install names:\n${install_names}")

    
endfunction()




# function(DylibD_add_deploy target)
#     cmake_parse_arguments(DDad "" "INSTALL_PREFIX" "" ${ARGN})
    
#     if(NOT TARGET ${target})
#         message(FATAL_ERROR "${target} is not an target")
#     endif()

#     DylibD_get_install_names()
# endfunction()
