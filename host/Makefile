#
# TIC-80 as a bootable Raspberry Pi kernel image.
#
# One board per invocation (RAPI_BOARD, default rpi5). The board selects
# three things at once: the circle-stdlib world the kernel is compiled and
# linked against, the shim archive built against that world, and — through
# the world's Config.mk — the CPU tuning and RASPPI value. Each board's
# newlib and libc++ are built for its own architecture, so an image is
# never portable between boards.
#
#   make                     the default board's image
#   make RAPI_BOARD=rpi3     that board's image
#   make clean-board         drop just this board's build/<board>/ tree
#
# Everything this invocation generates lands under build/<board>/: the
# kernel's own objects, every TIC-80 and vendor object, and the final
# .elf/.map/.lst/.img. The object names are shared across boards but their
# contents are not (different -mcpu, different -DRASPPI, different world),
# so a flat build directory would silently relink one board's objects into
# another board's kernel — a corrupt image with no build error. A directory
# per board keeps all three isolated: no `make clean` between boards, and
# three boards can build at the same time without touching each other.
#
# TIC-80's own source tree (../TIC-80) is never written into: it is
# read-only input, and every object it produces is redirected here.
#
# Prerequisite: the board's world and shim archive exist —
# `make -C ../circle-libsdl2 deps`, or `make deps` at the repository root.
#

include ../mk/toolchain.mk

RAPI_BOARD ?= rpi5

# WHERE THE BUILT WORLD COMES FROM.
#
# The default is this game's own nested shim, so a clone of this repository
# alone builds and uses its own worlds and nothing needs setting. A parent
# that keeps ONE set of built worlds for several games — they are gigabytes
# each, and identical when the pin and the configuration match — points
# CIRCLE_WORLDS at them.
#
# Named before the include below rather than beside SHIM further down,
# because make reads an include when it reaches it.
CIRCLE_WORLDS ?= ../circle-libsdl2
WORLD = $(CIRCLE_WORLDS)/circle-stdlib-$(RAPI_BOARD)

include $(WORLD)/Config.mk

ROOT = ..
# WHERE THE SHIM COMES FROM.
#
# Unset, this repository's own pinned copy — what a clone of this repository
# gets, and what CI builds. A parent proving one shim across several games
# points SHIM at the single checkout it is proving, so the library is built
# once rather than once per game.
SHIM ?= $(ROOT)/circle-libsdl2
TIC  = $(ROOT)/TIC-80

OBJDIR = build/$(RAPI_BOARD)

# Circle's own image names, which the Raspberry Pi firmware selects between
# from the model sections of config.txt: the Pi 3 world boots kernel8.img,
# the Pi 4 world kernel8-rpi4.img, the Pi 5 world kernel_2712.img.
IMAGE_rpi3 = kernel8
IMAGE_rpi4 = kernel8-rpi4
IMAGE_rpi5 = kernel_2712
IMAGE = $(IMAGE_$(RAPI_BOARD))
ifeq ($(IMAGE),)
$(error unknown RAPI_BOARD '$(RAPI_BOARD)' — expected rpi3, rpi4 or rpi5)
endif

TARGET = $(OBJDIR)/$(IMAGE)

# Stated explicitly because the first rule this file sees comes from an
# included makefile, and that would otherwise decide the default goal.
.DEFAULT_GOAL := image

# ---------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------

# The kernel wrapper, the syscall layer and this port's non-SDL shims: C++,
# and this project's own code.
HOST_SRCS = main.cpp kernel.cpp defaults.cpp circle_syscalls.cpp \
	circle_stubs.cpp
HOST_OBJS = $(addprefix $(OBJDIR)/,$(HOST_SRCS:.cpp=.o))

# The TIC-80 console itself, as upstream's cmake/core.cmake enumerates the
# tic80core library. Every file is compiled exactly as upstream wrote it.
TIC_CORE = \
	src/fftdata.c src/core/core.c src/core/draw.c src/core/io.c \
	src/core/sound.c src/tic.c src/cart.c src/tools.c src/zip.c \
	src/tilesheet.c src/script.c src/ext/fft.c src/ext/kiss_fft.c \
	src/ext/kiss_fftr.c src/ext/png.c src/ext/gif.c

# The studio — the editors, the console and the cartridge browser — as
# cmake/studio.cmake enumerates it with BUILD_EDITORS and BUILD_SURF on and
# BUILD_PRO off. ext/png.c and ext/gif.c belong to both that list and the
# core one above; each appears once here, because one link takes one object.
TIC_STUDIO = \
	src/studio/screens/run.c src/studio/screens/menu.c \
	src/studio/screens/mainmenu.c src/studio/screens/start.c \
	src/studio/screens/surf.c src/studio/screens/console.c \
	src/studio/studio.c src/studio/config.c src/studio/fs.c \
	src/studio/net.c \
	src/studio/editors/code.c src/studio/editors/sprite.c \
	src/studio/editors/map.c src/studio/editors/world.c \
	src/studio/editors/sfx.c src/studio/editors/music.c \
	src/ext/md5.c src/ext/json.c src/ext/history.c

# Lua, and the TIC-80 API bound to it — cmake/lua.cmake's luaapi and lua
# libraries. Lua is the only language runtime in this build: script.c
# enumerates whichever TIC_BUILD_WITH_* the build defines, and this one
# defines TIC_BUILD_WITH_LUA alone.
TIC_LUA_API = src/api/luaapi.c src/api/parse_note.c src/api/lua.c

# The SDL front end: the window, the audio device, the input mapping and the
# frame loop. Its main() is renamed below.
TIC_SYSTEM = src/system/sdl/main.c

TIC_SRCS = $(TIC_CORE) $(TIC_STUDIO) $(TIC_LUA_API) $(TIC_SYSTEM)

# The vendored libraries upstream builds alongside its own code, each as its
# own cmake file enumerates it. They are part of the TIC-80 submodule and are
# compiled exactly as they are.
VENDOR_LUA = $(addprefix vendor/lua/, \
	lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c \
	lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c \
	ltm.c lundump.c lvm.c lzio.c lauxlib.c lbaselib.c lcorolib.c ldblib.c \
	liolib.c lmathlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c loadlib.c \
	linit.c lbitlib.c)

VENDOR_GIF = $(addprefix vendor/giflib/, \
	dgif_lib.c egif_lib.c gif_err.c gif_font.c gif_hash.c gifalloc.c \
	openbsd-reallocarray.c)

VENDOR_ZLIB = $(addprefix vendor/zlib/, \
	adler32.c compress.c crc32.c deflate.c inflate.c infback.c inftrees.c \
	inffast.c trees.c uncompr.c zutil.c)

VENDOR_PNG = $(addprefix vendor/libpng/, \
	png.c pngerror.c pngget.c pngmem.c pngpread.c pngread.c pngrio.c \
	pngrtran.c pngrutil.c pngset.c pngtrans.c pngwio.c pngwrite.c \
	pngwtran.c pngwutil.c)

VENDOR_SRCS = $(VENDOR_LUA) $(VENDOR_GIF) $(VENDOR_ZLIB) $(VENDOR_PNG) \
	vendor/blip-buf/blip_buf.c vendor/blip-buf/wave_writer.c \
	vendor/zip/src/zip.c vendor/argparse/argparse.c

TIC_OBJS = $(addprefix $(OBJDIR)/tic/,$(TIC_SRCS:.c=.o) $(VENDOR_SRCS:.c=.o))

OBJS = $(HOST_OBJS) $(TIC_OBJS)

# gnu23 rather than gnu20: this libc++'s <algorithm> uses a C++23 construct
# unconditionally, and building it as C++20 fails inside the header.
STANDARD = -std=gnu++23

# C11, which is what upstream's CMakeLists asks for, and which this build has
# to say out loud in two places.
#
# It must not be C23. There, an empty parameter list means (void) rather than
# "unspecified", so tic80.h's `u64 (*counter)()` and tic.c's definition of the
# same function stop agreeing and the file will not compile.
#
# Rules.mk holds the standard in C_STANDARD, defaulted with ?=, and puts
# $(C_STANDARD) on the command line in its own C recipe rather than folding it
# into CFLAGS. So setting it here is only half the job: this directory's own C
# recipes pass it themselves, and a recipe that forgets does not fall back to
# Rules.mk's default — it falls back to the compiler's, which is C23.
C_STANDARD = -std=gnu11

# Stated, not inherited: this is Circle's own default, written down so the
# build's optimization level is a fact in the file rather than a forensic
# reconstruction.
OPTIMIZE = -O2

# Circle's Rules.mk defines a link rule for $(TARGET).img with its own linker
# script; sdl-app.mk below defines the one this port actually uses. Two
# recipes for one target makes make warn on every board of every build — a
# warning that reads like a fault and is not one. Pointing TARGET at a name
# nothing builds while Rules.mk is read attaches its rule there instead, so
# there is only ever one recipe for the image.
SDL_APP_IMAGE := $(TARGET)
TARGET := $(OBJDIR)/.circle-unused
include $(CIRCLEHOME)/Rules.mk
TARGET := $(SDL_APP_IMAGE)

# The world must be the multicore one circle-libsdl2 configures: the shim's
# core-split machinery cannot exist without it, and an object compiled
# against a single-core world links without complaint and then misbehaves.
# Every object here inherits the flag through Rules.mk's CPPFLAGS, so this
# check covers the whole build.
ifeq ($(findstring ARM_ALLOW_MULTI_CORE,$(DEFINE)),)
$(error the payload requires the multicore circle-stdlib world — build it with 'make -C ../circle-libsdl2 deps')
endif

# WHERE THIS GAME LIVES ON THE CARD. One card carries several games, and two
# of them writing a settings file into the FAT root would each silently
# overwrite the other's. Every game therefore keeps to a directory of its own,
# and nothing of this port's ever touches the root.
#
# It is a build-time constant, not a boot switch: a card's layout is decided
# when the card is staged, and a game that could be relocated at boot would
# only mean two places to look for the same file.
#
# The path is used ONLY by this port's own host layer — argv, the working
# directory, SDL's base path and upstream's own --fs switch. Upstream TIC-80
# is never told about it at build time and needs no patch: it looks where it
# is pointed.
RAPI_GAME_DIR ?= /games/tic80
DEFINE += -DRAPI_GAME_DIR='"$(RAPI_GAME_DIR)"'

# What upstream's CMake would have set for this configuration:
#
#   TIC_RUNTIME_STATIC   the language runtimes are linked in rather than
#                        loaded from shared objects. There is no dynamic
#                        loader here.
#   TIC_BUILD_WITH_LUA   the one language runtime this build carries.
#   BUILD_DEPRECATED     the GIF import path the core keeps for older
#                        cartridges; upstream sets it unconditionally.
#   BUILD_EDITORS        the code, sprite, map, sfx and music editors, and
#                        the console that reaches them.
#   BUILD_SURF           the cartridge browser, which is what BUILD_EDITORS
#                        implies in upstream's CMakeLists.
#   TIC80_FFT_UNSUPPORTED
#                        the spectrum API needs an audio capture device.
#                        circle-libsdl2 opens output devices only, so the
#                        API compiles to its own documented "unsupported"
#                        form and reports zeroes rather than failing to
#                        start.
#   LUA_COMPAT_5_2       Lua's own compatibility switch, which upstream sets
#                        for the luaapi library.
#   PNG_ARM_NEON_OPT=0   libpng's NEON paths select themselves from a Linux
#                        run-time check that does not exist here.
TIC_DEFINE = -DTIC_RUNTIME_STATIC -DTIC_BUILD_WITH_LUA -DBUILD_DEPRECATED \
	-DBUILD_EDITORS -DBUILD_SURF -DTIC80_FFT_UNSUPPORTED=1 \
	-DLUA_COMPAT_5_2 -DPNG_ARM_NEON_OPT=0 \
	-Dstatic_assert=_Static_assert

# The last of those is not upstream's. TIC-80 checks the size of its memory
# layout with C11's static_assert, which <assert.h> defines as a macro for
# the _Static_assert keyword. The <assert.h> reached here is CIRCLE's, which
# comes earlier on the include path than newlib's and defines assert alone —
# so the macro that would otherwise arrive with the header is supplied here
# instead, spelled exactly as newlib spells it.

# TIC-80 writes `#include <SDL.h>`, the spelling a desktop sdl2-config
# include path provides, so the shim's SDL2/ directory goes on the path in
# its own right alongside the SDL2/-prefixed one this project's own code
# uses.
#
# ticext/ carries the three headers upstream's build system generates while
# configuring a build and which this port writes down instead: version.h and
# runtime_versions.h from CMake's configure_file, and libpng's pnglibconf.h.
#
# TIC-80's own directories are on the path the way its build system puts them
# there. src/ carries the double duty of also resolving the
# `#include "../build/assets/*.dat"` lines: those are byte arrays of the
# cartridges compiled into the binary, and src/../build/assets is where they
# live.
INCLUDE := -I $(SHIM)/include -I $(SHIM)/include/SDL2 \
	-I $(CURDIR)/ticext \
	-I $(TIC)/include -I $(TIC)/src -I $(TIC)/src/studio \
	-I $(TIC)/vendor/lua -I $(TIC)/vendor/giflib -I $(TIC)/vendor/blip-buf \
	-I $(TIC)/vendor/zlib -I $(TIC)/vendor/libpng -I $(TIC)/vendor/zip/src \
	-I $(TIC)/vendor/argparse -I $(TIC)/vendor/jsmn \
	$(CIRCLE_STDLIB_INCLUDES) $(INCLUDE)

# TIC-80's own C flags: the build's C flags and C standard, in the order
# Rules.mk's own C recipe uses them, plus what upstream's CMake defines for
# this configuration.
TIC_CFLAGS = $(CFLAGS) $(C_STANDARD) $(TIC_DEFINE)

# The shim comes in whole, every member, rather than only the members the
# link happens to need. An object file linked straight into the kernel beats
# an archive member of the same name and does it silently, so a stub in
# circle_stubs.cpp left behind after the library implemented the real thing
# would quietly win — the game would keep calling the stub and nothing would
# say so. Pulling the archive in whole turns that into a duplicate-symbol
# error at link time, which is the only moment it can still be cheap to fix.
LIBS = --whole-archive $(SHIM)/libSDL2-$(RAPI_BOARD).a --no-whole-archive \
	$(CIRCLE_STDLIB_LIBS)

# ---------------------------------------------------------------------------
# Filesystem syscalls, redirected at link time
# ---------------------------------------------------------------------------
#
# The game runs on the application core, and newlib's Circle glue drives
# FatFs and the SD card straight from wherever it is called — which off core
# 0 is illegal. circle_syscalls.cpp puts the shim's any-core I/O service
# underneath the C library instead; these flags are what put it there.
#
# --wrap rather than redefinition, because redefinition cannot work here:
# the glue defines _open, _read, _write, _close, _lseek, _fstat, opendir,
# readdir, closedir, dup and more in a SINGLE object file. Redefining part
# of that set either collides at link time or, worse, leaves the originals
# linked in beside the replacements with no diagnostic. --wrap renames the
# references instead and leaves the vendored glue untouched — and it is what
# keeps __real_* reachable, which is how the service performs the real work
# once it has reached core 0.
#
# Every name here must also appear in circle_syscalls.cpp: a wrap with no
# __wrap_ definition is an undefined reference, so the link is the check.
WRAPPED_SYSCALLS = \
	_open _close _read _write _lseek _fstat _stat lstat _unlink _rename \
	_fcntl mkdir chdir getcwd dup dup2 \
	opendir readdir closedir rewinddir

# The link is driven by the cross ld directly (Circle's Rules.mk sets
# LD = <prefix>ld for GCC builds), so these are plain linker options, not
# compiler-driver -Wl, ones.
LDFLAGS += $(addprefix --wrap=,$(WRAPPED_SYSCALLS))

# ---------------------------------------------------------------------------
# Compilation
# ---------------------------------------------------------------------------

# This project's own objects, board-scoped. These more-specific rules win
# over Rules.mk's in-place %.o/%.d, so nothing is written beside the source.
$(OBJDIR)/%.o: %.cpp | $(OBJDIR)
	@echo "  CPP   $@"
	@$(CPP) $(CPPFLAGS) -c -o $@ $<

$(OBJDIR)/%.d: %.cpp | $(OBJDIR)
	@$(CPP) $(CPPFLAGS) -M -MG -MT $(@:.d=.o) -MT $@ -MF $@ $<

# TIC-80's objects, mirroring its source tree under $(OBJDIR)/tic/. The
# source tree itself is the upstream submodule, and is never written to.
$(OBJDIR)/tic/%.o: $(TIC)/%.c
	@mkdir -p $(dir $@)
	@echo "  CC    $@"
	@$(CC) $(TIC_CFLAGS) -c -o $@ $<

$(OBJDIR)/tic/%.d: $(TIC)/%.c
	@mkdir -p $(dir $@)
	@$(CC) $(TIC_CFLAGS) -M -MG -MT $(@:.d=.o) -MT $@ -MF $@ $<

# TIC-80's main() is the program's entry point on a desktop, but here main()
# belongs to the Circle kernel (main.cpp in this directory), which calls the
# program once the board is up. Renaming the entry point through the
# preprocessor for this one translation unit keeps upstream's source
# untouched, and the kernel calls the new name.
$(OBJDIR)/tic/src/system/sdl/main.o: $(TIC)/src/system/sdl/main.c
	@mkdir -p $(dir $@)
	@echo "  CC    $@ (entry point renamed)"
	@$(CC) $(TIC_CFLAGS) -Dmain=tic80_main -c -o $@ $<

# miniz, inside the vendored zip library, calls utime() while extracting an
# archive member. newlib's <utime.h> defines struct utimbuf and declares no
# prototype, so the declaration is forced in from this port's own header —
# the function is in circle_stubs.cpp.
$(OBJDIR)/tic/vendor/zip/src/zip.o: $(TIC)/vendor/zip/src/zip.c
	@mkdir -p $(dir $@)
	@echo "  CC    $@"
	@$(CC) $(TIC_CFLAGS) -include $(CURDIR)/ticext/rapi_utime.h -c -o $@ $<

$(OBJDIR)/tic/vendor/zip/src/zip.d: $(TIC)/vendor/zip/src/zip.c
	@mkdir -p $(dir $@)
	@$(CC) $(TIC_CFLAGS) -include $(CURDIR)/ticext/rapi_utime.h -M -MG -MT $(@:.d=.o) -MT $@ -MF $@ $<

$(OBJDIR)/tic/src/system/sdl/main.d: $(TIC)/src/system/sdl/main.c
	@mkdir -p $(dir $@)
	@$(CC) $(TIC_CFLAGS) -Dmain=tic80_main -M -MG -MT $(@:.d=.o) -MT $@ -MF $@ $<

$(OBJDIR):
	@mkdir -p $(OBJDIR)

-include $(DEPS)

# The image link rule. sdl-app.mk lets the caller choose the linker script,
# so this build supplies its own: the shim's script with room made at image
# offset 0x800 for the patchable-defaults block. Everything else about the
# script — including the TLS-section adjacency binutils 2.44 and later
# require — is inherited from the shim's.
SDL_APP_LDSCRIPT = $(CURDIR)/tic80-defaults.ld
include $(SHIM)/sdl-app.mk

# The other half of the guarantee the linker script's ASSERTs begin: check
# the BYTES of the finished image, not just the link. A pre-boot writer
# refuses to stamp an image whose magic is not at 0x800, so an image that
# lost it would boot and then quietly ignore everything ever sent to it —
# including --rapi-debug-uart, which is the channel used to drive the board
# when nobody is at the bench. Better to have no image than that one.
.PHONY: image
image: $(TARGET).img
	@if [ "`dd if=$(TARGET).img bs=4 skip=512 count=1 2>/dev/null`" = "PM8D" ]; \
	then \
		echo "  GATE  $(TARGET).img defaults block at 0x800: present"; \
	else \
		echo "  GATE  $(TARGET).img: defaults block ABSENT at 0x800 — image deleted"; \
		rm -f $(TARGET).img; \
		exit 1; \
	fi

# Board-scoped clean: drop just this board's tree, leaving the other two
# boards' images and objects untouched.
.PHONY: clean-board
clean-board:
	rm -rf $(OBJDIR) build/$(RAPI_BOARD)-stub
