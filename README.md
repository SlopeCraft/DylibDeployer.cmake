# `DylibDeployer.cmake` & `Codesigner.cmake`
`DylibDeployer.cmake` deploys dylibs automatically for macOS bundles.

`Codesigner.cmake` runs `codesign` to resign macOS bundles.

Actions above are executed during installation.

## Usage:

Minimal example without Qt:
```cmake
add_exectuable(test main.cpp)
set_target_properties(test PROPERTIES 
    MACOSX_BUNDLE ON)
install(TARGETS test
    BUNDLE DESTINATION bin)

include(DylibDeployer.cmake)
# Deploy required dylibs for the executable
DylibD_add_deploy(test 
    INSTALL_DESTINATION bin)
# The step above will break code signing of the bundle, so we need to resign it.
RCS_add_codesign(test
    INSTALL_DESTINATION bin)
```

Another example with Qt:
```cmake
add_exectuable(test ...)
set_target_properties(test PROPERTIES 
    MACOSX_BUNDLE ON)
find_package(Qt6 COMPONENTS Widgets
    REQUIRED)
target_link_libraries(test PRIVATE Qt6::Widgets)
install(TARGETS test
    BUNDLE DESTINATION bin)

include(QtDeployer.cmake)
# Run macdeployqt during installation. For qt apps, DylibDeployer can't take the place of `macdeployqt` because some plugins are linked conditionally after the program starts.
QD_add_deploy(test
    INSTALL_MODE
    INSTALL_DESTINATION bin)
include(DylibDeployer.cmake)
DylibD_add_deploy(test 
    INSTALL_DESTINATION bin
    PLUGIN_DIRS "Contents/PlugIns/platforms;Contents/PlugIns/imageformats" 
                # ↑Some qt plugin dirs
    )
RCS_add_codesign(test
    INSTALL_DESTINATION bin)
```

`RCS_add_codesign` should be runned at last, and you shouldn't install any other executions to the install bundle after code signing.

## Documentation
### `DylibDeployer.cmake`
#### Function prototype of:
```cmake
DylibD_add_deploy(<target> 
    # ↓single value, required item
    INSTALL_DESTINATION <where-you-install-target>
    # ↓single value, can be missing
    [RPATH_POLICY <KEEP|CHECK_ONLY|REPLACE>]
    [RPATH <rpath>]
    [PATH_TO_EXEC <path to executable in bundle>]
    # ↓can be list
    [PLUGIN_DIRS <path to plugin dirs in bundle>])
```

#### Parameters:
|       Parameter       |  Type  |        Default value         | Detail                                                                                                                                    |
| :-------------------: | :----: | :--------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------- |
|      `<target>`       | string |              -               | The executable(must be a cmake target)                                                                                                    |
| `INSTALL_DESTINATION` | string |              -               | Where you install  `<target>`, can't be absolute path.                                                                                    |
|    `RPATH_POLICY`     | string |           REPLACE            | How to process `@rpath` in isntall names.                                                                                                 |
|        `RPATH`        | string |      \<framework dir\>       | The value of `@rpath`                                                                                                                     |
|    `PATH_TO_EXEC`     | string | \<decuced from bundle name\> | The relative path to the executable in the bundle, for example: `Contents/MacOS/test`                                                     |
|     `PLUGIN_DIRS`     |  list  |            Empty             | The directory of extra dylibs in the bundle that need to be deployed. Example: `Contents/PlugIns/platforms;Contents/PlugIns/imageformats` |

#### `@rpath` policies:

|    Value     | Explain                                                                                |
| :----------: | :------------------------------------------------------------------------------------- |
| `CHECK_ONLY` | Check for dependencies with `rpath=<framework dir>`,but don't change the install name. |
|    `KEEP`    | Keep `@rpath`, deploy dylibs and fix install names with `rpath=<framework dir>`.       |
|  `REPLACE`   | Rewrite the install name with a new one started with `@loader_path``                   |

### `Codesigner.cmake`
#### Function prototype:
```cmake
RCS_add_codesign(<target>
    # ↓single value, required item
    INSTALL_DESTINATION <where-you-install-target>)
```
#### Parameters:
|       Parameter       |  Type  | Default value | Detail                                                 |
| :-------------------: | :----: | :-----------: | :----------------------------------------------------- |
|      `<target>`       | string |       -       | The executable(must be a cmake target)                 |
| `INSTALL_DESTINATION` | string |       -       | Where you install  `<target>`, can't be absolute path. |