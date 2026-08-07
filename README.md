# pi-tic80

**The TIC-80 fantasy console running directly on a Raspberry Pi with no
operating system.** The board powers on and the console is what boots: no
Linux, no desktop, no launcher, and nothing else running beside it.

It builds for the Raspberry Pi 3, Pi 4 and Pi 5, all three from one source
tree.

## What this is

[TIC-80](https://github.com/nesbox/TIC-80) is a fantasy computer: a small
machine that never existed, with a 240x136 screen, sixteen colours, four
sound channels, and its own code, sprite, map, sound and music editors built
in. Programs for it are single files called cartridges. This repository is the
thin layer that lets it run with nothing underneath: a
[Circle](https://github.com/rsta2/circle) kernel that brings the board up, and
[circle-libsdl2](https://github.com/Xalior/circle-libsdl2), an SDL2
implementation built on Circle's bare-metal drivers.

TIC-80's own source is not copied or modified here. It is a submodule, pinned
at an upstream commit, and the build reads it without ever writing to it.
Where the console needs something that is not SDL2 and that a bare-metal C
library does not provide, this repository supplies it in `host/`.

Three processor cores are given separate work:

- **Core 0** owns the hardware. Circle's world lives here — interrupts, USB,
  the SD card, sound — and no other core touches a device.
- **Core 1** runs TIC-80 and nothing else.
- **Core 2** puts finished frames on the screen. The console draws at 256x144
  — its 240x136 screen and the border around it — and never learns the
  display's size; the picture is scaled once, at the end, onto whatever the
  screen is really showing.

## State of this port

This is an early port. **It has not been run on hardware.** The list below is
what the code does, not what has been observed.

**Present:**

- Video: the console's own screen, uploaded whole each frame and scaled to the
  display.
- Keyboard and mouse: USB devices through Circle's HID drivers. The editors
  need both.
- Game controllers: TIC-80's four-player pad mapping, through SDL's game
  controller API.
- Sound: TIC-80 generates its own audio and needs no separate mixer library,
  so the console's four channels reach the SDL audio device directly.
- Files: cartridges and the configuration, read from and written to the SD
  card.
- Lua: cartridges written in Lua run. TIC-80's demonstration cartridges are
  compiled into the binary, so there is something to run before you add a
  single file — type `demo` at the console.

**Absent, and why:**

- **Every language except Lua.** TIC-80 supports a dozen: Ruby, JavaScript,
  MoonScript, Fennel, Wren, Squirrel, Scheme, Python, Janet, WebAssembly and
  more. Each is a complete interpreter compiled into the binary, and this port
  builds only Lua — the one TIC-80 itself treats as the default. Adding
  another is a source list and a define in `host/Makefile`, not new work.
- **The spectrum API.** TIC-80's `fft()` and `ffts()` read a live audio
  spectrum from a capture device. circle-libsdl2 opens audio output devices
  only, so this port sets upstream's own `TIC80_FFT_UNSUPPORTED`, and those
  two functions report that there is nothing to hear.
- **Networking.** TIC-80 can browse and download community cartridges over the
  internet. There is no network stack behind SDL here, so the browser lists
  what is on the card and nothing else.
- **The PRO features.** Upstream gates text-format cartridges and a few export
  formats behind a paid build. This is not that build, so cartridges must be
  the binary `.tic` or `.png` kind.

## What you need to supply

Nothing, to start. TIC-80 carries its own demonstration cartridges inside the
binary, and `demo` at its console writes them onto the card as real files you
can then load, run and edit.

Cartridges are the console's data, and they are other people's work. This
repository ships none.

```sh
make media
```

fetches two cartridges from TIC-80's own repository, at the commit this
repository pins for the submodule, under the MIT licence that repository
carries:

| File | What it is |
|---|---|
| `bunny.tic` | The bunnymark demonstration — bouncing sprites, running by itself, needing no input. |
| `cart-template.tic` | The empty starter cartridge, with the default palette and font and no program. |

Both are checked against a recorded SHA256 and an exact byte count. TIC-80
publishes no checksum for either file, so the recorded checksum is the only
comparison available; it was computed from the copy this project fetched.
There is no format check because a `.tic` cartridge has no magic number — the
format is a bare stream of chunks.

`make media` writes a `provenance.txt` beside what it downloads, naming the
source, the date and the licence.

Anything else — cartridges from tic80.com, from itch.io, from a friend — is
yours to obtain and to put on the card. Community cartridges carry no blanket
licence, and this project does not collect them.

## Building

You need a Linux or macOS machine, GNU make, and the Arm GNU toolchain for
`aarch64-none-elf` (release 15.2.Rel1). Put its `bin` directory on your
`PATH`, or unpack it into `toolchains/` in this repository.

```sh
git clone --recursive https://github.com/Xalior/pi-tic80.git
cd pi-tic80
make deps       # long: builds newlib and libc++ from source, once per board
make kernels    # the three board images
make verify     # confirms each image exists and is not empty
```

`make deps` is the slow step, and it is slow once. It builds a complete C and
C++ world for each board, because each board's world is compiled for its own
processor.

Part of that world is libc++, whose sources are fetched from a git tag that
carries the bare-metal patches. That tag is hosted on Codeberg, which is small
and volunteer run. One copy is enough for every board and for every project on
your machine, so tell the build where to keep it and it is fetched once:

```sh
make deps CIRCLE_LLVM=/path/to/circle-llvm
```

The default puts that checkout beside this repository, which is the right
answer for a plain clone or a continuous-integration runner and needs no
setting at all.

The images land in `host/build/<board>/`:

| Board | Image |
|---|---|
| Pi 3 | `host/build/rpi3/kernel8.img` |
| Pi 4 | `host/build/rpi4/kernel8-rpi4.img` |
| Pi 5 | `host/build/rpi5/kernel_2712.img` |

Building one board on its own is `make rpi5`, and its dependencies alone are
`make deps-rpi5`, which is what a machine without room for three worlds wants.

On macOS, use GNU make 4 (`gmake`, from Homebrew) rather than the make macOS
ships. The system one is version 3.81, and there are situations in which it
stops with no output at all and names no reason.

## Putting it on a card

```sh
make card
```

That stages the card into `build/sd-card/` for you to copy onto FAT32 media:
the three kernel images under the names each board's firmware looks for, the
boot configuration, and whatever cartridges `make media` left, in
`games/tic80/`. It downloads nothing itself, and it says which files are
absent.

One thing is not staged and has to be added by hand: **the Raspberry Pi
firmware files** — `bootcode.bin`, `start*.elf`, `fixup*.dat` and, for the
Pi 4, `armstub8-rpi4.bin`. Take them from a Raspberry Pi OS card or from the
[firmware repository](https://github.com/raspberrypi/firmware).

Everything this console reads and writes stays inside `games/tic80/` on the
card. A card can carry several of these projects, and each keeps to its own
directory rather than writing settings into the card's root.

### The thermal settings in `cmdline.txt`

One card boots any of the three boards, so all three read the same
`cmdline.txt`. It carries `socmaxtemp=70`, the temperature in degrees Celsius
at which the processor is slowed down to cool itself.

If your board has a fan, add `gpiofanpin=` and the GPIO pin it is wired to —
`gpiofanpin=45` is a Raspberry Pi 5 Case Fan or Active Cooler. Naming a fan
pin changes what happens at that temperature: the fan is switched on and the
processor is left at full speed, instead of being slowed down. That is what a
game wants, because a slowed processor drops frames.

### Boot options

`cmdline.txt` also accepts switches this kernel reads:

| Option | Effect |
|---|---|
| `rapi-perf=N` | Print a performance line to the serial console every N seconds. |
| `rapi-debug-uart` | Accept key presses from the serial console, so a board with no keyboard attached can still be driven. |

## How the layers fit

`host/` holds everything this repository adds, and nothing else:

| File | What it is |
|---|---|
| `kernel.cpp`, `kernel.h`, `main.cpp` | The Circle kernel: brings up the serial console, the SD card and the filesystem, elects the three cores, and calls TIC-80. |
| `defaults.cpp`, `defaults.h`, `defaultsblock.h`, `tic80-defaults.ld` | A patchable block of text at offset 0x800 in the image, which a boot loader can write arguments into without anything being rebuilt. |
| `circle_syscalls.cpp` | Puts the SD card underneath the C library in a way that is legal from a core that does not own the hardware. |
| `circle_stubs.cpp` | Three things a desktop C library answers and this one does not: `utime`, `chmod`, and the storage upstream's own no-capture-device build leaves undefined. |
| `ticext/` | Headers upstream's build system generates while configuring a build, written down instead: the version strings, and libpng's configuration. |
| `config.txt`, `cmdline.txt` | Firmware boot configuration, one file for all three boards. |

There is no SDL2 in `host/`. SDL2 is circle-libsdl2's job, and a function that
library does not yet implement is reported to it rather than written here,
where only this one project could ever reach it.

TIC-80's entry point is renamed by the preprocessor for one file, so that
`main` belongs to the Circle kernel and the console is a function it calls.
That is the whole of the intrusion into upstream: no patch, no fork, no edit.

The console is pointed at its own directory on the card four ways, because
different parts of it derive paths differently: the program name it is given,
upstream's own `--fs` switch, the directory SDL reports it may write into, and
the working directory the kernel sets before it starts.

## License

The code in this repository — the kernel layer in `host/` and the build — is
released under the GNU Lesser General Public License, version 3. See
[LICENSE](LICENSE).

The submodules are other people's work and carry their own terms, and both
matter before you distribute anything you build here:

- **TIC-80** is released under the MIT licence. The libraries vendored inside
  it — Lua, zlib, libpng, giflib and others — carry their own, listed in that
  repository's `THIRD_PARTY_LICENSES.md`.
- **Circle** is released under the GNU General Public License, version 3.

Building a kernel image here combines all of them, and the result is covered
by the GNU General Public License, version 3. Doing that for yourself is
straightforward; redistributing the result means satisfying every one of those
terms at once, including supplying complete source.
