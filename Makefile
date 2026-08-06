#
# pi-tic80 — TIC-80 as a bootable bare-metal Raspberry Pi image.
#
#   make check-toolchain     report the cross compiler this build will use
#   make deps                the three circle-stdlib worlds and the shim
#                            archives built against them (long: the worlds
#                            build newlib and libc++ from source)
#   make deps-rpi4           the same for one board only, for a machine that
#                            cannot hold three worlds at once
#   make rpi5 | rpi4 | rpi3  one board's kernel image
#   make kernels             all three, built in parallel
#   make verify              truth-gate: every image exists and is non-empty
#   make media               download the freely redistributable cartridges
#                            into media/
#   make netboot             stage the Pi 5 image and its boot configuration
#                            into build/netboot-rpi5/
#   make card                stage the whole card into build/sd-card/, copying
#                            in whatever media/ holds and naming what it does
#                            not. It never downloads anything
#   make clean-boards        drop every board's build tree
#
# The three boards never share mutable state: each has its own circle-stdlib
# world, its own shim archive and its own object directory, so building them
# at the same time is safe and building one never disturbs another.
#
# The libc++ sources every world is built from are one immutable git tag, and
# CIRCLE_LLVM says where that checkout lives. The default puts it beside this
# repository, which is right for a plain clone and for a CI runner. Point
# several projects at one directory to fetch it once for all of them:
#
#   make deps CIRCLE_LLVM=/path/to/circle-llvm
#

include mk/toolchain.mk

# Stated explicitly because the first rule this file sees comes from an
# included makefile, and that would otherwise decide the default goal.
.DEFAULT_GOAL := kernels

BOARDS ?= rpi3 rpi4 rpi5

IMAGE_rpi3 = kernel8.img
IMAGE_rpi4 = kernel8-rpi4.img
IMAGE_rpi5 = kernel_2712.img

.PHONY: deps kernels verify media netboot card clean-boards $(BOARDS)
.PHONY: $(addprefix deps-,$(BOARDS))

deps:
	$(MAKE) -C circle-libsdl2 deps

# One board's dependencies: its own circle-stdlib world and the shim archive
# built against it. A machine with a small disk — a CI runner, most obviously
# — builds one board at a time and keeps only that board's world.
# Written as a static pattern rule over the board list rather than a plain
# pattern rule: these targets are phony, and make does not apply pattern rules
# to phony targets — it would quietly answer "nothing to be done" and leave
# the world unbuilt.
$(addprefix deps-,$(BOARDS)): deps-%:
	$(MAKE) -C circle-libsdl2 world BOARD=$*
	$(MAKE) -C circle-libsdl2 libSDL2-$*.a BOARD=$*

$(BOARDS): check-toolchain
	$(MAKE) -C host RAPI_BOARD=$@

# All three at once. Each sub-make owns a different world and a different
# output directory, so there is nothing for them to collide on.
#
# Each board is waited for BY PID, and its status kept. A bare `wait` reports
# only that the shell has no children left — it is success whatever the jobs
# did — so a board that failed to build would leave this target reporting
# success, and the truth-gate would then pass the board's PREVIOUS image,
# still on disk.
kernels: check-toolchain
	@pids=; fail=0; \
	for b in $(BOARDS); do $(MAKE) -C host RAPI_BOARD=$$b & pids="$$pids $$!"; done; \
	for p in $$pids; do wait $$p || fail=1; done; \
	exit $$fail

# Truth-gate: ask the filesystem, not the exit codes. An image that is
# missing or empty fails here even if the build claimed success.
verify:
	@fail=0; \
	for b in $(BOARDS); do \
		case $$b in \
			rpi3) img=host/build/rpi3/$(IMAGE_rpi3) ;; \
			rpi4) img=host/build/rpi4/$(IMAGE_rpi4) ;; \
			rpi5) img=host/build/rpi5/$(IMAGE_rpi5) ;; \
		esac; \
		if [ -s "$$img" ]; then \
			echo "  OK    $$img ($$(wc -c < $$img | tr -d ' ') bytes)"; \
		else \
			echo "  FAIL  $$img missing or empty"; fail=1; \
		fi; \
	done; \
	exit $$fail

# ---------------------------------------------------------------------------
# Cartridges
# ---------------------------------------------------------------------------
#
#   media/           what `make media` downloads. Gitignored, never shipped,
#                    and never part of a build.
#   build/sd-card/   what `make card` stages. It copies from media/ and
#                    fetches nothing.
#
# `card` does not depend on `media`, so a card built without it is complete
# except for the cartridges and names the files that are absent.
#
# TIC-80 is a fantasy console, so cartridges are its data. It carries a set of
# demonstration cartridges inside the binary — `demo` at its console writes
# them out — and it needs no external file to start. What `make media`
# fetches is two additional cartridges from TIC-80's own repository, at the
# commit this repository pins for the submodule, under the MIT licence the
# repository carries.
#
# Both are checked by SHA256 against the copies this project fetched, and by
# the cartridge format's own magic. TIC-80 publishes no checksum for either
# file, so the recorded SHA256 is the only comparison available and the
# provenance file says so. Re-running re-verifies rather than re-downloading.
MEDIA_DIR = media

TIC80_COMMIT = 4aba09c98f1e5028b82765be1647677b08d35942
TIC80_RAW    = https://raw.githubusercontent.com/nesbox/TIC-80/$(TIC80_COMMIT)

BUNNY_TIC    = $(MEDIA_DIR)/bunny.tic
BUNNY_PATH   = templates/nim/demo/bunny.tic
BUNNY_SHA256 = ae0393d63970e21d7cd2452a2949adf2216dc03c7d72eebd6a36f34362324d8c

CARTTPL_TIC    = $(MEDIA_DIR)/cart-template.tic
CARTTPL_PATH   = templates/nim/src/cart.tic
CARTTPL_SHA256 = 8561fa163e9c55330f30df5c298674cb0c58078c6c0b24989cc176e6cb463080

# sha256sum on Linux, shasum on macOS. Whichever exists; if neither does the
# target stops rather than accepting a download it cannot check.
SHA256SUM := $(firstword $(shell command -v sha256sum 2>/dev/null) \
                         $(shell command -v shasum 2>/dev/null))

media:
	@if [ -z "$(SHA256SUM)" ]; then \
		echo "  MEDIA no checksum tool on this machine (sha256sum or shasum)"; \
		echo "        — refusing to download something that cannot be"; \
		echo "        verified."; \
		exit 1; \
	fi
	@mkdir -p $(MEDIA_DIR)
	@set -e; \
	for spec in "$(BUNNY_TIC)|$(BUNNY_PATH)|$(BUNNY_SHA256)" \
	            "$(CARTTPL_TIC)|$(CARTTPL_PATH)|$(CARTTPL_SHA256)"; do \
		file=`echo "$$spec" | cut -d'|' -f1`; \
		path=`echo "$$spec" | cut -d'|' -f2`; \
		want=`echo "$$spec" | cut -d'|' -f3`; \
		url="$(TIC80_RAW)/$$path"; \
		if [ -f "$$file" ]; then \
			echo "  MEDIA $$file already here — verifying"; \
		else \
			echo "  MEDIA fetching $$url"; \
			curl -fL --retry 3 -o "$$file.part" "$$url" || { \
				rm -f "$$file.part"; \
				echo "  MEDIA download failed"; exit 1; }; \
			mv "$$file.part" "$$file"; \
		fi; \
		got=`$(SHA256SUM) -a 256 "$$file" 2>/dev/null || $(SHA256SUM) "$$file"`; \
		got=`echo "$$got" | awk '{print $$1}'`; \
		if [ "$$got" != "$$want" ]; then \
			echo "  MEDIA SHA256 MISMATCH for $$file"; \
			echo "        expected $$want"; \
			echo "        got      $$got"; \
			echo "        the file has been left in place for inspection, and"; \
			echo "        is NOT safe to put on a card."; \
			exit 1; \
		fi; \
		head -c 4 "$$file" | grep -q TIC || { \
			echo "  MEDIA $$file does not begin with the cartridge magic"; \
			exit 1; }; \
		echo "  MEDIA $$file verified ($$(wc -c < $$file | tr -d ' ') bytes)"; \
	done
	@printf '%s\n' \
		"TIC-80 starter cartridges" \
		"" \
		"Source:   https://github.com/nesbox/TIC-80" \
		"Commit:   $(TIC80_COMMIT)" \
		"Fetched:  `date -u '+%Y-%m-%d %H:%M:%S UTC'`" \
		"" \
		"bunny.tic" \
		"  URL:    $(TIC80_RAW)/$(BUNNY_PATH)" \
		"  SHA256: $(BUNNY_SHA256)" \
		"  What it is: the bunnymark demonstration cartridge shipped with" \
		"  TIC-80's Nim language template. It runs by itself and needs no" \
		"  input." \
		"" \
		"cart-template.tic" \
		"  URL:    $(TIC80_RAW)/$(CARTTPL_PATH)" \
		"  SHA256: $(CARTTPL_SHA256)" \
		"  What it is: the empty starter cartridge TIC-80 ships as the seed" \
		"  for a new Nim project — the default palette and font, and no game" \
		"  code." \
		"" \
		"Licence: MIT, from the TIC-80 repository root LICENSE file," \
		"copyright (c) 2017 Vadim Grigoruk. No separate licence file exists" \
		"under templates/nim/, so the repository licence covers these files." \
		"" \
		"Verification: TIC-80 publishes no checksum for either file. The" \
		"SHA256 above was computed from the copy this project fetched, so a" \
		"later fetch is known to be identical to it." \
		"" \
		"These files are not redistributed by this repository." \
		> $(MEDIA_DIR)/provenance.txt
	@echo "  MEDIA provenance written to $(MEDIA_DIR)/provenance.txt"

# The Pi 5 netboot bundle: the image the Pi 5 firmware looks for, plus the
# boot configuration it must be served alongside. Copy the contents into the
# TFTP root the board boots from (the Raspberry Pi firmware files themselves
# come from that root's existing installation, not from here).
NETBOOT_DIR = build/netboot-rpi5
netboot: rpi5
	@mkdir -p $(NETBOOT_DIR)
	@cp host/build/rpi5/$(IMAGE_rpi5) $(NETBOOT_DIR)/
	@cp host/config.txt host/cmdline.txt $(NETBOOT_DIR)/
	@echo "  STAGED $(NETBOOT_DIR)/"
	@ls -l $(NETBOOT_DIR)/

# The card, staged into a directory to copy onto media formatted elsewhere:
# the three kernels, boot configuration and whatever cartridges media/
# happens to hold.
#
# Everything belonging to this game lives in one directory on the card, named
# by RAPI_GAME_DIR in host/Makefile. A card carries several games, and two of
# them writing a settings file into the FAT root would each silently
# overwrite the other's. The two paths have to agree: the kernel enters this
# directory before the program starts and points TIC-80's own --fs switch at
# it, so a cartridge staged anywhere else is a cartridge the console never
# lists.
#
# This target downloads nothing. It copies what `make media` left and names
# what is absent.
CARD_DIR  = build/sd-card
CARD_GAME = $(CARD_DIR)/games/tic80

card: kernels
	@rm -rf $(CARD_DIR)
	@mkdir -p $(CARD_GAME)
	@cp host/build/rpi3/$(IMAGE_rpi3) $(CARD_DIR)/
	@cp host/build/rpi4/$(IMAGE_rpi4) $(CARD_DIR)/
	@cp host/build/rpi5/$(IMAGE_rpi5) $(CARD_DIR)/
	@cp host/config.txt host/cmdline.txt $(CARD_DIR)/
	@echo "  STAGED $(CARD_DIR)/"
	@found=0; \
	for f in $(MEDIA_DIR)/*.tic $(MEDIA_DIR)/*.png; do \
		[ -f "$$f" ] || continue; \
		cp "$$f" $(CARD_GAME)/; \
		echo "  DATA   `basename $$f`"; \
		found=1; \
	done; \
	echo; \
	if [ $$found -eq 0 ]; then \
		echo "  ABSENT no cartridges. TIC-80 still starts: it carries its own"; \
		echo "         demonstration cartridges, which the console's 'demo'"; \
		echo "         command writes out. 'make media' fetches two more."; \
	fi
	@echo "  NOTE   The Raspberry Pi firmware files are not staged here either."
	@echo "         See README.md."

# Board build trees and staged output only. media/ is not touched: it holds
# downloaded data, which no build target deletes.
clean-boards:
	@for b in $(BOARDS); do $(MAKE) -C host RAPI_BOARD=$$b clean-board; done
	rm -rf $(NETBOOT_DIR) $(CARD_DIR)
