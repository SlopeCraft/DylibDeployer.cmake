# DylibDeployer.cmake
Deploy dylibs automatically on macOS

## rpath policies:

|    Value     | Explain                                                                                |
| :----------: | :------------------------------------------------------------------------------------- |
| `CHECK_ONLY` | Check for dependencies with `rpath=<framework dir>`,but don't change the install name. |
|    `KEEP`    | Keep `@rpath`, deploy dylibs and fix install names with `rpath=<framework dir>`.       |
|  `REPLACE`   | Rewrite the install name with a new one started with `@loader_path``                   |