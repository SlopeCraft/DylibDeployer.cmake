cmake_minimum_required(VERSION 3.20)
project(DylibDeployer.cmake LANGUAGES C CXX)

set(CMAKE_INSTALL_PREFIX install)
#set(CMAKE_INSTALL_PREFIX "install" CACHE STRING "")

find_package(Qt6 
    COMPONENTS Widgets
    REQUIRED)
add_executable(test main.cpp)
target_link_libraries(test PRIVATE Qt6::Widgets)
target_compile_features(test PRIVATE cxx_std_20)
set_target_properties(test PROPERTIES
    MACOSX_BUNDLE ON)
install(TARGETS test
    BUNDLE DESTINATION .)

include(DylibDeployer.cmake)

set(bundle ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_PREFIX}/test.app)
DylibD_deploy_libs(${bundle}/Contents/MacOS/test
    FRAMEWORK_DIR ${bundle}/Contents/Frameworks)

# set(lib_name "/opt/homebrew/lib/libzip.5.dylib")
# DylibD_get_install_names(${lib_name} install_names)
# message(STATUS "install_names = ${install_names}")

# foreach(iname ${install_names})
    
# DylibD_resolve_install_name(
#     ${iname}
#     out
#     EXE_PATH "/exe"
#     LOADER_PATH "/opt/homebrew/Cellar/libzip/1.10.1/lib"
#     RPATH "/rpath")

# message(STATUS "${iname} resolved to : \"${out}\"")
# endforeach(iname ${install_names})

