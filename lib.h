#ifndef DylibD_LIB_H
#define DylibD_LIB_H

#include <stdint.h>
#include <shared_lib_export.h>

#ifdef __cplusplus
extern "C" {
#endif

SHARED_LIB_EXPORT const char* SH_libzip_version();

#ifdef __cplusplus
}
#endif

#endif