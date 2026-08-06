//
// circle_stubs.cpp — the non-SDL entry points TIC-80 references that a
// bare-metal newlib does not provide.
//
// Nothing named SDL_ belongs here. SDL2 is circle-libsdl2's job, and a
// missing SDL function is reported to that library rather than written into
// this port, where only this port would ever reach it. What is here is
// POSIX-shaped, or an upstream symbol this build's configuration leaves
// undefined.
//
#include "ticext/rapi_utime.h"

#include <sys/stat.h>

extern "C"
{

// TIC-80's own header, and it carries no extern "C" guard of its own — so it
// is included here, inside the block, or the declarations it makes would not
// match the definitions below.
#include <fftdata.h>

// Set a file's access and modification times.
//
// newlib declares utime in <utime.h> and defines struct utimbuf, but ships no
// implementation, and the shim's any-core I/O service has no operation behind
// it. miniz — the zip reader inside TIC-80's vendored kubazip — calls it once
// per extracted member to restore the member's recorded timestamps, and reads
// a non-zero return as the extraction having failed.
//
// So this accepts the call and leaves the timestamps as the filesystem wrote
// them. The board has no battery-backed clock, its wall clock is seeded from
// the build time, and a FAT timestamp here carries no information anybody can
// use — while refusing would turn every cartridge unpacked from a zip into a
// failed extraction.
int utime(const char *, const struct utimbuf *)
{
    return 0;
}

// Set a file's permission bits.
//
// The studio's console calls this once, on a cartridge it has just exported,
// to make the exported file executable. FAT has no permission bits to set and
// the card is the only filesystem here, so there is nothing to do and nothing
// that could have gone wrong. The caller discards the result.
int chmod(const char *, mode_t)
{
    return 0;
}

// ---------------------------------------------------------------------------
// The spectrum API's data, which this configuration leaves undefined
// ---------------------------------------------------------------------------
//
// TIC-80's fft() and ffts() APIs read a captured audio spectrum.
// circle-libsdl2 opens audio OUTPUT devices only, so this build defines
// TIC80_FFT_UNSUPPORTED — upstream's own switch for a target with no capture
// device, which compiles every FFT function into a form that reports nothing
// is there.
//
// That switch also compiles the whole of upstream's fftdata.c away, including
// these variables, and upstream's core.c and studio.c go on referencing them
// unguarded. They are read in one place (core.c, behind `if (fftEnabled)`)
// and written in one other (studio.c, clearing the buffer when a cartridge
// starts), so the storage is all this configuration is short of.
//
// The values are upstream's own initialisers from fftdata.c. fftEnabled is
// false and nothing in this build ever sets it, which is what keeps the read
// path from asking a capture device that does not exist.
float fPeakMinValue    = 0.01f;
float fPeakSmoothing   = 0.995f;
float fPeakSmoothValue = 0.0f;
float fAmplification   = 1.0f;

float fftData[FFT_SIZE]              = {0};
float fftSmoothingData[FFT_SIZE]     = {0};
float fftNormalizedData[FFT_SIZE]    = {0};
float fftNormalizedMaxData[FFT_SIZE] = {0};

bool fftEnabled = false;

} // extern "C"
