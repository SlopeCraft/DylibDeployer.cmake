#include "lib.h"
#include <zip.h>

SHARED_LIB_EXPORT const char* SH_libzip_version() {
    return zip_libzip_version();
}