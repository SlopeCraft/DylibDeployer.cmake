cmake_minimum_required(VERSION 3.20)
project(DylibDeployer.cmake LANGUAGES C CXX)

set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install)
#set(CMAKE_INSTALL_PREFIX install)

find_package(Qt6 
    COMPONENTS Widgets
    REQUIRED)
find_package(libzip REQUIRED)
add_executable(test main.cpp)
target_link_libraries(test PRIVATE Qt6::Widgets libzip::zip)
target_compile_features(test PRIVATE cxx_std_20)
set_target_properties(test PROPERTIES
    MACOSX_BUNDLE ON)
install(TARGETS test
    BUNDLE DESTINATION bin)

include(DylibDeployer.cmake)
include(3rdParty/DLLDeployer/QtDeployer.cmake)
include(Codesigner.cmake)

# DylibD_parse_framework_name("@loader_path/../../../Versions/A/QtDBus" fw_name path_to_dylib ver_letter)
# message(STATUS "Parse result: fw_name = \"${fw_name}\", path_to_dylib = \"${path_to_dylib}\", ver_letter = ${ver_letter}")

# DylibD_parse_framework_name("@rpath/QtDBus.framework/Versions/T/QtDBus" fw_name path_to_dylib ver_letter)
# message(STATUS "Parse result: fw_name = \"${fw_name}\", path_to_dylib = \"${path_to_dylib}\", ver_letter = ${ver_letter}")

# QD_add_deployqt(test INSTALL_MODE 
#     INSTALL_DESTINATION bin)

DylibD_add_deploy(test 
    INSTALL_DESTINATION bin)
# RCS_add_codesign(test
#     INSTALL_DESTINATION bin)

#set(bundle ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_PREFIX}/test.app)
#set(bundle "/System/Applications/Utilities/Activity Monitor.app")

# DylibD_deploy_libs("${bundle}/Contents/MacOS/test"
#     FRAMEWORK_DIR "${bundle}/Contents/Frameworks"
#     RPATH_POLICY REPLACE)
# RCS_sign_configtime(test ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_PREFIX})

include(CPack)