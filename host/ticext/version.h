//
// version.h — the header upstream's CMake generates from version.h.in.
//
// CMake fills the placeholders in TIC-80/version.h.in from cmake/version.cmake
// and from `git rev-list HEAD --count` / `git log -1 --format=%H` in the
// upstream checkout. This build does not run CMake, so the same values are
// written down here, matching the pinned upstream commit.
//
// TIC_VERSION_BUILD is the marker CMake leaves empty for a release build and
// sets to ".dbg" for a debug one. This build is a release one.
//
#pragma once

#define TIC_VERSION_MAJOR       1
#define TIC_VERSION_MINOR       2
#define TIC_VERSION_REVISION    3083
#define TIC_VERSION_STATUS      "-dev"
#define TIC_VERSION_BUILD       ""
#define TIC_VERSION_YEAR        "2026"
#define TIC_VERSION_HASH        "4aba09c"
