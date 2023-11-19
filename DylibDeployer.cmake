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

function(DylibD_is_framework bin_location out_var_name)
    if(${bin_location} MATCHES ".framework/Versions/")
        set(${out_var_name} ON PARENT_SCOPE)
        return()
    endif()

    set(${out_var_name} OFF PARENT_SCOPE)
endfunction()

function(DylibD_is_dylib library_file out_var_name)
    
    cmake_path(GET library_file EXTENSION extension)
    string(TOLOWER "${extension}" extension)
    if(extension MATCHES .dylib)
        set(${out_var_name} ON PARENT_SCOPE)
        return()
    endif()

    DylibD_is_framework(${library_file} is_framework)
    if(${is_framework})
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
        /var/lib/
        /System/Library
        )

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
        #message(STATUS "Link resolved to \"${lib_location}\"")
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
    cmake_parse_arguments(DDrin "" "EXEC_PATH;LOADER_PATH;RPATH" "" ${ARGN})

    string(REPLACE "@executable_path" ${DDrin_EXEC_PATH} install_name ${install_name})
    string(REPLACE "@loader_path" ${DDrin_LOADER_PATH} install_name ${install_name})
    string(REPLACE "@rpath" ${DDrin_RPATH} install_name ${install_name})

    set(${out_var} ${install_name} PARENT_SCOPE)
endfunction()


function(DylibD_deploy_libs bin_location)
    cmake_parse_arguments(DDdl "RPATH_POLICY"
     "FRAMEWORK_DIR;EXEC_PATH"
      ""
      ${ARGN})

    # RPATH_POLICY: KEEP REPLACE
    # EXEC_PATH should not be set if binary is an executable

    DylibD_is_dylib(${bin_location} is_dylib)

    if(${is_dylib})
    else()
        if(DDdl_EXEC_PATH)
            message(FATAL_ERROR "You should not set EXEC_PATH when given binary(${bin_location}) is an executable.")
        endif()
        cmake_path(GET bin_location PARENT_PATH DDdl_EXEC_PATH)
    endif()

    cmake_path(GET bin_location PARENT_PATH loader_path)

    if(NOT DDdl_RPATH_POLICY)
        set(DDdl_RPATH_POLICY KEEP)
    endif()


    #message(STATUS "DDdl_EXEC_PATH = \"${DDdl_EXEC_PATH}\"")
    #message(STATUS "DDdl_FRAMEWORK_DIR = \"${DDdl_FRAMEWORK_DIR}\"")

    DylibD_get_install_names(${bin_location} install_names)
    #message(STATUS "install names:\n${install_names}")

    cmake_path(GET bin_location FILENAME bin_filename)

    foreach(iname ${install_names})
        DylibD_resolve_install_name(${iname} resolved 
            EXEC_PATH ${DDdl_EXEC_PATH}
            LOADER_PATH ${loader_path}
            RPATH "@rpath")

        DylibD_is_system_dylib(${resolved} is_sys)
        if(${is_sys})
            # Do not check system libs, many system libs are not found in filesystem but program can still launch.
            # This can be explained by some mechanics like vDSO
            continue()
        endif()

        if(NOT EXISTS ${resolved})
            message(STATUS "\"${bin_filename}\" depends on \"${iname}\" which resolves to \"${resolved}\" but it doesn't exist.")
            continue()
        endif()


        DylibD_deploy_libs(${resolved}
            RPATH_POLICY ${DDdl_RPATH_POLICY}
            FRAMEWORK_DIR ${DDdl_FRAMEWORK_DIR}
            EXEC_PATH ${DDdl_EXEC_PATH})
    endforeach()
    

    
endfunction()




# function(DylibD_add_deploy target)
#     cmake_parse_arguments(DDad "" "INSTALL_PREFIX" "" ${ARGN})
    
#     if(NOT TARGET ${target})
#         message(FATAL_ERROR "${target} is not an target")
#     endif()

#     DylibD_get_install_names()
# endfunction()
