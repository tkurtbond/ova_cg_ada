# ova_cg_ada -- an OVA character generator in Ada, with fltkada (FLTK)
# for its window and alibfyaml (libfyaml) for its files.  See AGENTS.md
# and PLAN.md.
#
# gprbuild builds from ova_cg_ada.gpr: the program in program mode, the
# test programs (test/test_*.adb) in tests mode.  Both write into
# $(OBJ); the program goes here, the tests into $(OBJ).
#
# The libraries: arg_parser, libfyaml_ada and fltkada installed on
# GPR_PROJECT_PATH; ova_fmt's library project, ova_fmt_lib.gpr, in
# OVA_FMT_DIR (the submodule ext/ova_fmt by default), which is put on
# GPR_PROJECT_PATH here.  fltkada is
# installed both static and dynamic, and library_type picks: dynamic,
# on the shared GNAT runtime, named here because the installed
# project's default is whichever kind was installed first.

SHELL = bash

GPRBUILD ?= gprbuild
OVA_FMT_DIR ?= ext/ova_fmt
export GPR_PROJECT_PATH := $(abspath $(OVA_FMT_DIR))$(if $(GPR_PROJECT_PATH),:$(GPR_PROJECT_PATH))
GPRFLAGS := -p -q -P ova_cg_ada.gpr -Xlibrary_type=dynamic

OBJ := obj

PROGRAM := ova_cg_ada

# Every source a program is built from, for make's dependencies.
PROGSRC := $(wildcard src/*.ad[sb] src/*.c $(OVA_FMT_DIR)/src/*.ad[sb]) \
  $(OVA_FMT_DIR)/ova_fmt_lib.gpr

# Test support, and test programs (test/<name>.adb): TESTS need no
# display, GUITESTS do.
TESTSUPPORT := $(wildcard test/check.ad[sb])
TESTS       := $(patsubst test/%.adb,%,$(wildcard $(foreach t,rules calc files model paths spawn viewer,test/test_$(t).adb)))
GUITESTS    := $(patsubst test/%.adb,%,$(wildcard $(foreach t,window background linked limits markdown resize,test/test_$(t).adb)))
TESTBINS    := $(TESTS:%=$(OBJ)/%)
GUITESTBINS := $(GUITESTS:%=$(OBJ)/%)
# Seconds a test may run before it counts as hung, and how long the
# program must keep running to count as started (test-gui).
TIMEOUT  ?= 60
RUNTIME  ?= 3

.PHONY: all tests test check-pages test-viewers test-gui test-headless test-sway valgrind valgrind-headless valgrind-sway \
  display install uninstall clean
.NOTPARALLEL:

all: $(PROGRAM)

tests: $(PROGRAM) $(TESTBINS) $(GUITESTBINS)

$(OBJ):
	mkdir -p $@

# Not there: the submodule wasn't checked out.
$(OVA_FMT_DIR)/ova_fmt_lib.gpr:
	@echo "$@ isn't there: run git submodule update --init," \
	  "or set OVA_FMT_DIR to an ova_fmt checkout" >&2; exit 1

# test_files saves its copies here, for test/files.sh.
$(OBJ)/files: | $(OBJ)
	mkdir -p $@

$(PROGRAM): $(PROGSRC) ova_cg_ada.gpr | $(OBJ)
	$(GPRBUILD) $(GPRFLAGS) -XOVA_CG_MODE=program

$(OBJ)/test_%: test/test_%.adb $(TESTSUPPORT) $(PROGSRC) ova_cg_ada.gpr | $(OBJ)
	$(GPRBUILD) $(GPRFLAGS) -XOVA_CG_MODE=tests $(notdir $<)

# The oracle for files: what the generator saves must format as the
# file it loaded (test/files.sh, after test_files).  ova_fmt (Ada) by
# default, the one in OVA_FMT_DIR, built here; ova_fmt_po, its Oberon
# port, gives the same output.
OVA_FMT ?= $(OVA_FMT_DIR)/ova_fmt

$(OVA_FMT_DIR)/ova_fmt: $(wildcard $(OVA_FMT_DIR)/src/*.ad[sb]) $(OVA_FMT_DIR)/ova_fmt.gpr \
  $(OVA_FMT_DIR)/ova_fmt_lib.gpr
	$(GPRBUILD) -p -q -P $(OVA_FMT_DIR)/ova_fmt.gpr

# What needs no display: the unit tests, test/files.sh, then
# test/cli.sh; fail at the end if any failed.
test: $(PROGRAM) $(TESTBINS) $(filter $(OVA_FMT_DIR)/ova_fmt,$(OVA_FMT)) | $(OBJ)/files
	@status=0; for t in $(TESTS); do \
	  echo "== $$t"; (cd test && timeout $(TIMEOUT) ../$(OBJ)/$$t) || status=1; \
	done; \
	if [ -n "$(filter test_files,$(TESTS))" ]; then \
	  echo "== files.sh"; test/files.sh $(OVA_FMT) || status=1; fi; \
	echo "== cli.sh"; test/cli.sh ./$(PROGRAM) || status=1; \
	exit $$status

# Every page in Ova_Cg.Rules against the rulebook: the entries'
# headings, found by their font in the PDF (tools/rulebook-headings.py,
# which needs mutool).  Not part of make test, which can't count on the
# PDF.
RULEBOOK ?= $(HOME)/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf
check-pages: $(OBJ)/list_rules
	@tools/rulebook-headings.py $(RULEBOOK) > $(OBJ)/headings.txt
	@$(OBJ)/list_rules > $(OBJ)/rules.txt
	@if diff $(OBJ)/headings.txt $(OBJ)/rules.txt; then \
	  echo "ok   - all $$(wc -l < $(OBJ)/rules.txt) pages match the rulebook's headings"; \
	else echo "FAIL - Ova_Cg.Rules (>) differs from the rulebook's headings (<)"; exit 1; fi

$(OBJ)/list_rules $(OBJ)/open_page: $(OBJ)/%: test/%.adb $(PROGSRC) ova_cg_ada.gpr | $(OBJ)
	$(GPRBUILD) $(GPRFLAGS) -XOVA_CG_MODE=tests $(notdir $<)

# Ova_Cg.Viewer with the real viewers, okular, evince and mupdf, on a
# headless sway of test/viewer.sh's own, on a private D-Bus session bus,
# with a scratch HOME.  Not part of make test: it needs the viewers, and
# takes a minute or two.
test-viewers: $(OBJ)/open_page
	test/viewer.sh $(OBJ)/open_page

# FLTK needs a display even for windows never shown.  An agent never
# runs these on the user's desktop (AGENTS.md): use test-headless or
# test-sway.
display:
	@if [ -z "$$DISPLAY$$WAYLAND_DISPLAY" ]; then \
	  echo "the window tests need a display: use make test-headless or make test-sway"; exit 1; \
	fi

# The window tests, then the program itself, which waits for the user:
# it must still be running after RUNTIME seconds, when timeout ends it
# (status 124): it started, drew, and didn't crash.  Then test/quit.sh:
# started again, Ctrl+E opens Limits from a text input and it quits on
# Ctrl+Q (X11 only; skipped on Wayland).
# The program's own runs keep their preferences in obj/config, not the
# user's ~/.config.
test-gui: tests display | $(OBJ)/files
	@export XDG_CONFIG_HOME=$(CURDIR)/$(OBJ)/config; \
	status=0; for t in $(GUITESTS); do \
	  echo "== $$t"; (cd test && timeout $(TIMEOUT) ../$(OBJ)/$$t) || status=1; \
	done; \
	echo "== $(PROGRAM) (must still be running after $(RUNTIME) s)"; \
	timeout $(RUNTIME) ./$(PROGRAM); st=$$?; \
	if [ $$st -eq 124 ]; then echo "ok   - $(PROGRAM) started and ran"; \
	else echo "FAIL - $(PROGRAM) exited with $$st"; status=1; fi; \
	echo "== quit.sh"; test/quit.sh ./$(PROGRAM) || status=1; \
	exit $$status

# On a virtual X server (Xvfb).  WAYLAND_DISPLAY is unset because FLTK
# prefers Wayland when it is set, even under xvfb-run.
test-headless: tests
	env -u WAYLAND_DISPLAY xvfb-run -a $(MAKE) test-gui

# On Wayland, on a headless sway (tools/with-sway.sh, pofltk's).
test-sway: tests
	tools/with-sway.sh $(MAKE) test-gui

# The tests under valgrind.  Memory errors fail a run; leaks don't by
# themselves, since FLTK's display stack (fontconfig, Pango, and GTK's
# decorations under Wayland) leaks by design.  A child Ova_Cg.Spawn
# forks reports nothing: it only execs or exits, and what it runs isn't
# ours to check.
VALGRIND ?= valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=none \
  --error-exitcode=99 --child-silent-after-fork=yes
valgrind: tests display | $(OBJ)/files
	@status=0; for t in $(TESTS) $(GUITESTS); do \
	  echo "== valgrind $$t"; \
	  (cd test && $(VALGRIND) --log-file=../$(OBJ)/$$t.vg ../$(OBJ)/$$t) || status=1; \
	  grep -E 'ERROR SUMMARY' $(OBJ)/$$t.vg; \
	done; \
	if [ $$status -eq 0 ]; then echo "All checks passed."; else exit 1; fi

valgrind-headless: tests
	env -u WAYLAND_DISPLAY xvfb-run -a $(MAKE) valgrind

valgrind-sway: tests
	tools/with-sway.sh $(MAKE) valgrind

# ---- Installation ----
#
# To $(PREFIX)/bin, $HOME/local/bin by default, as ova_fmt's.  DESTDIR
# is prepended, for staging.  The program finds libfltkada.so where
# fltkada is installed, by its run path.
PREFIX ?= $(HOME)/local
BINDIR ?= $(PREFIX)/bin

install: $(PROGRAM)
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(PROGRAM) $(DESTDIR)$(BINDIR)/$(PROGRAM)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(PROGRAM)

clean:
	rm -rf $(OBJ) $(PROGRAM)

print-%: ; @echo $* = $($*)
