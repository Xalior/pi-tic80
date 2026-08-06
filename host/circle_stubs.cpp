//
// circle_stubs.cpp — the non-SDL entry points TIC-80 references that a
// bare-metal newlib does not provide.
//
// Nothing named SDL_ belongs here. SDL2 is circle-libsdl2's job, and a
// missing SDL function is reported to that library rather than written into
// this port, where only this port would ever reach it. What is here is
// POSIX-shaped: calls TIC-80 and its vendored libraries make that a desktop C
// library answers and this one does not.
//
#include <cstdio>

extern "C"
{

}
