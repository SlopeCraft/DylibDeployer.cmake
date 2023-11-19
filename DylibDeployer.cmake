cmake_minimum_required(VERSION 3.20)

if (DEFINED CMAKE_GENERATOR)
    message(STATUS "Running at configuration time")
    option(DylibD_configure_time "Whether this script is running at configuration time" ON)
else ()
    # Otherwise we guess that it's running at build or installation time.
    message(STATUS "Running at build/install time")
    option(DylibD_configure_time "Whether this script is running at configuration time" OFF)
endif ()

if (NOT ${APPLE})
    message(FATAL_ERROR "This project is designed to deploy dll on windows.")
    return()
endif ()


if(${DylibD_configure_time})
else()
    set(DylibD_bundle_name      @DDad_target_name@    CACHE STRING "")
    set(DylibD_this_script_file @configured_file@     CACHE STRING "")
    set(DylibD_rpath_policy     @DDad_RPATH_POLICY@   CACHE STRING "")
    set(DylibD_rpath            @DDad_RPATH@          CACHE STRING "")
    set(CMAKE_PREFIX_PATH       "@CMAKE_PREFIX_PATH@" CACHE STRING "")

endif()

function(DylibD_is_framework bin_location out_var_name)
    if(${bin_location} MATCHES ".framework/Versions/")
        set(${out_var_name} ON PARENT_SCOPE)
        return()
    endif()
    if(${bin_location} MATCHES "/Versions/[A-Z]/")
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
        /Library
        )

    foreach (system_prefix ${DLLD_system_prefixes})
        if(${lib_location} MATCHES ${system_prefix})
            set(${out_var_name} ON PARENT_SCOPE)
            return()
        endif()
    endforeach ()

endfunction()


function(DylibD_get_install_names lib_location out_list_name)
    if(NOT EXISTS ${lib_location})
        message(FATAL_ERROR "dylib/executable file \"${lib_location}\" doesn't exists, or is a broken symlink.")
    endif()
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
        if(dep_stem STREQUAL ${given_lib_stem})
            continue()
        endif()

        list(APPEND result ${substr})

    endforeach()
    
    set(${out_list_name} ${result} PARENT_SCOPE)
    
endfunction()

function(DylibD_resolve_install_name install_name out_var)
    cmake_parse_arguments(DDrin "" "EXEC_PATH;LOADER_PATH;RPATH" "" ${ARGN})

    string(REPLACE "@executable_path" "${DDrin_EXEC_PATH}" install_name ${install_name})
    string(REPLACE "@loader_path" "${DDrin_LOADER_PATH}" install_name ${install_name})
    string(REPLACE "@rpath" "${DDrin_RPATH}" install_name ${install_name})

    set(${out_var} ${install_name} PARENT_SCOPE)
endfunction()

function(DylibD_check_rpath_option) # DDcr
    cmake_parse_arguments(DDcr "" "RPATH_POLICY;RPATH" "" ${ARGN})

    if(${DDcr_RPATH_POLICY} STREQUAL "KEEP")

    elseif(${DDcr_RPATH_POLICY} STREQUAL "REPLACE")
        if(NOT IS_DIRECTORY ${DDcr_RPATH})
            message(FATAL_ERROR "The rpath policy is \"${DDcr_RPATH_POLICY}\", but given rpath value is \"${DDcr_RPATH}\" which is not a directory.")
        endif()
    elseif()
        message(FATAL_ERROR "Invalid value \"${DDcr_RPATH_POLICY}\" for RPATH policy. Valid values: KEEP;REPLACE")
    endif()

endfunction()

function(DylibD_find_framework fw_name out_var)
    if(NOT fw_name)
        message(FATAL_ERROR "Invalid framework name \"${fw_name}\"")
    endif()

    find_path(fw_loc
        NAMES "${fw_name}.framework/${fw_name}"
        PATHS ${CMAKE_PREFIX_PATH}
        PATH_SUFFIXES lib
        REQUIRED
        DOC "Searching for framework \"${fw_name}.framework\"")

    set(${out_var} "${fw_loc}/${fw_name}.framework" PARENT_SCOPE)
endfunction()


# match framename name froim install nanme. 
# Ex: "@rpath/QtDBus.framework/Versions/A/QtDBus" -> QtDBus
#     "@loader_path/../../../Versions/A/QtDBus" -> QtDBus
function(DylibD_parse_framework_name install_name out_fw_name out_path_to_dylib out_version_letter)
    unset(${out_fw_name} PARENT_SCOPE)
    unset(${out_path_to_dylib} PARENT_SCOPE)
    unset(${out_version_letter} PARENT_SCOPE)
    message(STATUS "Parsing framework name from install name ${install_name}")

    string(REGEX MATCH "/Versions/[A-Z]/[A-Za-z0-9_]+$" version_letter ${install_name})
    string(SUBSTRING ${version_letter} 10 1 version_letter)
    if(NOT ${version_letter} MATCHES "[A-Z]")
        message(FATAL_ERROR "Failed to parse version letter from \"${install_name}\"")
    endif()
    set(${out_version_letter} ${version_letter} PARENT_SCOPE)

    # Type 1: "@rpath/QtDBus.framework/Versions/A/QtDBus" -> QtDBus and Versions/A/QtDBus
    string(REGEX MATCH "/[A-Za-z0-9_]+\.framework/" fw_name ${install_name})
    if(fw_name)
        string(REPLACE "/" "" fw_name ${fw_name})
        string(REPLACE ".framework" "" fw_name ${fw_name})
        
        string(FIND ${install_name} ".framework/" index REVERSE)
        math(EXPR index "${index}+11")
        string(SUBSTRING ${install_name} ${index} -1 path_to_dylib)
        #message(STATUS "Dylib file in the bundle is \"${path_to_dylib}\"")
        if((NOT fw_name) OR (NOT path_to_dylib))
            message(FATAL_ERROR "Failed to parse framework name from install name \"${install_name}\", fw_name = \"${fw_name}\", path_to_dylib = \"${path_to_dylib}\"")
        endif()
        set(${out_fw_name} ${fw_name} PARENT_SCOPE)
        set(${out_path_to_dylib} ${path_to_dylib} PARENT_SCOPE)

        return()
    endif()

    # Type 2: "@loader_path/../../../Versions/A/QtDBus" -> QtDBus and Versions/A/QtDBus
    string(REGEX MATCH "/Versions/[A-Z]/.+" fw_name ${install_name})
    if(fw_name)
        string(SUBSTRING ${fw_name} 12 -1 fw_name)
        #message(STATUS "line 202: fw_name = \"${fw_name}\"")
        set(path_to_dylib "Versions/${version_letter}/${fw_name}")
        #message(STATUS "version_letter is \"${version_letter}\"")

        if((NOT fw_name) OR (NOT path_to_dylib))
            message(FATAL_ERROR "Failed to parse framework name from install name \"${install_name}\", fw_name = \"${fw_name}\", path_to_dylib = \"${path_to_dylib}\"")
        endif()
        set(${out_fw_name} ${fw_name} PARENT_SCOPE)
        set(${out_path_to_dylib} ${path_to_dylib} PARENT_SCOPE)
        return()
    endif()

    message(FATAL_ERROR "Failed to parse framework name from install name \"${install_name}\"")
        
endfunction()

function(DylibD_copy_framework)
    cmake_parse_arguments(DDcf "" "NAME;LOCATION;VERSION_LETTER;DESTINATION" "" ${ARGN})
    file(REAL_PATH ${DDcf_LOCATION} DDcf_LOCATION)

    set(fw_dir "${DDcf_DESTINATION}/${DDcf_NAME}.framework")
    file(MAKE_DIRECTORY ${fw_dir})
    file(MAKE_DIRECTORY "${fw_dir}/Versions")
    file(MAKE_DIRECTORY "${fw_dir}/Versions/${DDcf_VERSION_LETTER}")

    # QtGui.framework/Versions/A/QtGui (a dylib)
    file(COPY "${DDcf_LOCATION}/Versions/${DDcf_VERSION_LETTER}/${DDcf_NAME}" 
        DESTINATION "${fw_dir}/Versions/${DDcf_VERSION_LETTER}" USE_SOURCE_PERMISSIONS)
    # QtGui.framework/Versions/A/Resources (dir)
    file(COPY "${DDcf_LOCATION}/Versions/${DDcf_VERSION_LETTER}/Resources" 
        DESTINATION "${fw_dir}/Versions/${DDcf_VERSION_LETTER}" USE_SOURCE_PERMISSIONS)
    # QtGui.framework/Versions/Current -> A (symlink)
    file(CREATE_LINK "${DDcf_VERSION_LETTER}" "${fw_dir}/Versions/Current" SYMBOLIC)
    # QtGui.framework/QtGui -> Versions/Current/QtGui (symlink)
    file(CREATE_LINK "Versions/Current/${DDcf_NAME}" "${fw_dir}/${DDcf_NAME}" SYMBOLIC)
    # QtGui.framework/Resources -> Versions/Current/Resources (symlink)
    file(CREATE_LINK "Versions/Current/Resources" "${fw_dir}/Resources" SYMBOLIC)

endfunction()

function(DylibD_search_file_advanced filename search_dirs out_var)
    cmake_parse_arguments(DDsfa "RETURN_ALL" "" "" ${ARGN})
    unset(${out_var} PARENT_SCOPE)

    set(searched )
    foreach(dir ${search_dirs})
        execute_process(COMMAND find ${dir} -name ${filename} #2>/dev/null
            OUTPUT_VARIABLE output
            ERROR_VARIABLE err)
        string(REPLACE "\n" ";" cur_list "${output}")
        list(APPEND searched ${cur_list})

        list(LENGTH searched len)

        if((${len} GREATER 0) AND (NOT DDsfa_RETURN_ALL))
            list(GET searched 0 first_result)
            set(${out_var} ${first_result} PARENT_SCOPE)
            return()
        endif()
    endforeach()
    
    if(DDsfa_RETURN_ALL)
        set(${out_var} ${searched} PARENT_SCOPE)
    endif()

endfunction()


function(DylibD_fix_install_name bin_location)
    cmake_parse_arguments(DDfin "DRY_RUN" "INSTALL_NAME;RPATH_POLICY;RPATH;FRAMEWORK_DIR;OUT_DEPLOYED_FILE;OUT_NEW_INSTALL_NAME" "" ${ARGN})

    if(DDfin_OUT_DEPLOYED_FILE)
        unset(${DDfin_OUT_DEPLOYED_FILE} PARENT_SCOPE)
    endif()
    if(DDfin_OUT_NEW_INSTALL_NAME)
        unset(${DDfin_OUT_NEW_INSTALL_NAME} PARENT_SCOPE)
    endif()

    cmake_path(GET bin_location PARENT_PATH loader_path)
    set(is_rpath OFF)
    if(${DDfin_INSTALL_NAME} MATCHES "@rpath/")
        set(is_rpath ON)
    endif()

    DylibD_is_framework(${DDfin_INSTALL_NAME} is_framework)
    #message(STATUS "iname = ${DDfin_INSTALL_NAME}, is_framework = ${is_framework}")
    # message(STATUS "Install name: ${DDfin_INSTALL_NAME}")

    if(NOT ${is_framework})
        # Deploy simple dylib
        cmake_path(GET DDfin_INSTALL_NAME FILENAME dep_name)
        if(NOT dep_name)
            message(FATAL_ERROR "Failed to parse dep filename \"${dep_name}\" with given install name ${DDfin_INSTALL_NAME}")
        endif()

        set(deployed_dep_loc "${DDfin_FRAMEWORK_DIR}/${dep_name}")
        if((NOT DDfin_DRY_RUN) AND (NOT EXISTS ${deployed_dep_loc}))
            # The dependency doesn't exist in bundle, search for it.
            #message(STATUS "Finding dylib \"${dep_name}\"")
            find_file(dep_loc 
                NAMES ${dep_name} 
                PATHS ${CMAKE_PREFIX_PATH} /opt/homebrew /usr/local/Cellar
                PATH_SUFFIXES lib bin lib-exec
                NO_CACHE
                DOC "Find dependency \"${dep_name}\"")
            if(NOT dep_loc)
                message(STATUS "Failed to find dependency \"${dep_name}\" with cmake find_file call. Try find command...")

                DylibD_search_file_advanced(${dep_name} "/opt/homebrew;/usr/local/Cellar;/usr" dep_loc)
                if(NOT dep_loc)
                    message(STATUS "Failed to find dependency \"${dep_name}\".")
                endif()
            endif()

            message(STATUS "Found ${dep_loc}")
            file(COPY ${dep_loc} DESTINATION ${DDfin_FRAMEWORK_DIR} FOLLOW_SYMLINK_CHAIN)
        endif()
    else()
        # Deploy framework
        # deployed_dep_loc must be set to the dep file
        
        # match framename name froim install nanme. 
        # Ex: "@rpath/QtDBus.framework/Versions/A/QtDBus" -> QtDBus
        #     "@loader_path/../../../Versions/A/QtDBus" -> QtDBus
        DylibD_parse_framework_name(${DDfin_INSTALL_NAME} fw_name path_to_dylib version_letter)
        if(NOT fw_name)
            message(FATAL_ERROR "Invalid framework name \"${fw_name}\"")
        endif()
        message(STATUS "Matched framework name \"${fw_name}\"")

        if((NOT DDfin_DRY_RUN) AND (NOT IS_DIRECTORY ${deployed_dep_loc}))
            # The required framework doesn't exist, search for it.
            # Find the framework
            DylibD_find_framework(${fw_name} fw_loc)
            if(NOT EXISTS "${fw_loc}/${path_to_dylib}")
                message(FATAL_ERROR "Found framework ${fw_loc}, but dep file \"${fw_loc}/${path_to_dylib}\" doesn't exist.")
            endif()
            message(STATUS "Found framework \"${fw_name}\" at \"${fw_loc}\"")
            message(STATUS "Copying ${fw_loc} to ${DDfin_FRAMEWORK_DIR}")
            DylibD_copy_framework(NAME ${fw_name} 
                LOCATION ${fw_loc} 
                VERSION_LETTER ${version_letter} 
                DESTINATION ${DDfin_FRAMEWORK_DIR})
        endif()
        #message(STATUS "path_to_dylib = ${path_to_dylib}")
        set(deployed_dep_loc "${DDfin_FRAMEWORK_DIR}/${fw_name}.framework/${path_to_dylib}")
    endif()

    if(DDfin_OUT_DEPLOYED_FILE)
        set(${DDfin_OUT_DEPLOYED_FILE} ${deployed_dep_loc} PARENT_SCOPE)
    endif()

    # Change the install name
    set(new_iname ${deployed_dep_loc})
    if((NOT ${is_rpath}) OR (${DDfin_RPATH_POLICY} STREQUAL "REPLACE"))
        cmake_path(RELATIVE_PATH new_iname BASE_DIRECTORY ${loader_path})
        #message(STATUS "The computed relative path is: \"${new_iname}\"")
        set(new_iname "@loader_path/${new_iname}")
        #message(STATUS "New install name: \"${new_iname}\"")
    elseif(${DDfin_RPATH_POLICY} STREQUAL "KEEP")
        cmake_path(RELATIVE_PATH new_iname BASE_DIRECTORY ${DDfin_FRAMEWORK_DIR})
        #message(STATUS "The computed relative path is: \"${new_iname}\"")
        set(new_iname "@rpath/${new_iname}")
        #message(STATUS "New install name: \"${new_iname}\"")
    else()
        message(FATAL_ERROR "Invalid rpath policy. DylibD_fix_install_name doesn't accept ${DDfin_RPATH_POLICY}")
    endif()

    if(NOT DDfin_DRY_RUN)
        message(STATUS "Change install name with: \n  install_name_tool \"${bin_location}\" -change \"${DDfin_INSTALL_NAME}\" \"${new_iname}\"")
        #Example:
        #install_name_tool libzip.5.dylib -change @loader_path/../../../../opt/xz/lib/libzstd.1.dylib @loader_path/libzstd.1.dylib
        execute_process(COMMAND install_name_tool "${bin_location}" -change "${DDfin_INSTALL_NAME}" "${new_iname}"
            COMMAND_ERROR_IS_FATAL ANY)
    endif()
    if(DDfin_OUT_NEW_INSTALL_NAME)
        set(${DDfin_OUT_NEW_INSTALL_NAME} ${new_iname} PARENT_SCOPE)
    endif()

endfunction()

function(DylibD_deploy_libs bin_location)
    #message(STATUS "Deploying dependency for ${bin_location}")
    cmake_parse_arguments(DDdl ""
      "RPATH_POLICY;FRAMEWORK_DIR;EXEC_PATH;RPATH"
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
    if(NOT DDdl_RPATH)
        set(DDdl_RPATH ${DDdl_FRAMEWORK_DIR})
    endif()

    DylibD_check_rpath_option(RPATH_POLICY ${DDdl_RPATH_POLICY} RPATH ${DDdl_RPATH})

    #message(STATUS "DDdl_EXEC_PATH = \"${DDdl_EXEC_PATH}\"")
    #message(STATUS "DDdl_FRAMEWORK_DIR = \"${DDdl_FRAMEWORK_DIR}\"")

    DylibD_get_install_names(${bin_location} install_names)
    #message(STATUS "install names:\n${install_names}")

    cmake_path(GET bin_location FILENAME bin_filename)

    foreach(iname ${install_names})
        DylibD_resolve_install_name(${iname} resolved 
            EXEC_PATH "${DDdl_EXEC_PATH}"
            LOADER_PATH "${loader_path}"
            RPATH "${DDdl_RPATH}")

        DylibD_is_system_dylib(${resolved} is_sys)
        if(${is_sys})
            # Do not check system libs, many system libs are not found in filesystem but program can still launch.
            # This can be explained by some mechanism like vDSO
            continue()
        endif()

        if(NOT EXISTS ${resolved})
            # The dependency doesn't exist. Try deploying it.

            DylibD_fix_install_name(${bin_location}
                INSTALL_NAME ${iname}
                FRAMEWORK_DIR ${DDdl_FRAMEWORK_DIR}
                RPATH_POLICY ${DDdl_RPATH_POLICY}
                RPATH ${DDdl_RPATH}
                OUT_DEPLOYED_FILE deployed_file
                )
            if(NOT EXISTS ${deployed_file})
                message(FATAL_ERROR "${bin_filename} requires \"${deployed_file}\" but it is not deployed. iname = \"${iname}\"")
                continue()
            endif()

            set(resolved ${deployed_file})
            #message(STATUS "\"${bin_filename}\" depends on \"${iname}\" which resolves to \"${resolved}\" but it doesn't exist.")
            #continue()
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
