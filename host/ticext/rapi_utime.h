//
// rapi_utime.h — the utime() declaration newlib's own <utime.h> omits.
//
// newlib ships <utime.h> and a dummy <sys/utime.h> that defines struct
// utimbuf and nothing else: the prototype is left to whichever port supplies
// the function, and this target supplies none. miniz — the zip reader inside
// TIC-80's vendored kubazip — calls utime() while extracting, so without a
// declaration in scope that call is an error.
//
// This is forced into the zip translation unit from the makefile rather than
// included by anything, because the file that ought to declare it is a
// vendored header this project does not modify. The function itself is in
// circle_stubs.cpp.
//
#ifndef _rapi_utime_h
#define _rapi_utime_h

#include <time.h>
#include <utime.h>

#ifdef __cplusplus
extern "C" {
#endif

int utime(const char *path, const struct utimbuf *times);

#ifdef __cplusplus
}
#endif

#endif
