//
// runtime_versions.h — the header upstream's CMake generates from
// cmake/runtime_versions.h.in.
//
// CMake reads each bundled language runtime's own version header and writes
// the resulting strings out; the console prints them for `version`. This build
// does not run CMake, so the strings are written down here.
//
// Only Lua is compiled into this port, so it is the only entry with a version:
// TIC_BUILD_WITH_LUA is the only language define this build sets, and the
// console never prints a string for a language that is not in the binary.
// "unknown" is what upstream's CMake itself leaves for a runtime it cannot
// find a version for.
//
#pragma once

#define TIC_RUNTIME_VERSION_LUA "Lua 5.3.6"
#define TIC_RUNTIME_VERSION_RUBY "unknown"
#define TIC_RUNTIME_VERSION_JS "unknown"
#define TIC_RUNTIME_VERSION_MOON "unknown"
#define TIC_RUNTIME_VERSION_YUE "unknown"
#define TIC_RUNTIME_VERSION_FENNEL "unknown"
#define TIC_RUNTIME_VERSION_SCHEME "unknown"
#define TIC_RUNTIME_VERSION_SQUIRREL "unknown"
#define TIC_RUNTIME_VERSION_WREN "unknown"
#define TIC_RUNTIME_VERSION_WASM "unknown"
#define TIC_RUNTIME_VERSION_JANET "unknown"
#define TIC_RUNTIME_VERSION_PYTHON "unknown"
