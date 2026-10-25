# AGENTS.md

Working notes for an agent in this repo, which holds `ova_cg_ada`, a
character generator for OVA (Open Versatile Anime engine). It is an Ada
port of `ova_cg_po` (`~/Repos/RPG/Tools/ova_cg_po`, Oberon-2), with an
FLTK window (fltkada) and YAML files (alibfyaml) in ova_fmt's format.
PLAN.md is the port's mapping, decisions and build order; ova_cg_po's
PLAN.md is the design it ports. This file is operational notes, not a
design doc.

ova_cg_po is the specification: its `src/*.Mod` for what the program
does, its `test/*.Mod` for the checks, which are ported check for
check, with the same labels. Its `AGENTS.md` has the reasons behind
most of the rules below.

## Reference material

| What | Where |
|---|---|
| The design | `~/Repos/RPG/Tools/ova_cg_po/PLAN.md` |
| The Oberon program and tests (the specification) | `~/Repos/RPG/Tools/ova_cg_po/src`, `test` |
| OVA rulebook (PDF, 170 pages) | `~/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf` |
| Rulebook as text | `~/Reference/RPG/OVA/ova-rulebook.txt`, `ova-rulebook-not-layout.txt` |
| Descriptions as Markdown | `~/Reference/RPG/OVA/abilities.md`, `weaknesses.md` -- **never copy into this repo** (below) |
| The YAML format, and the sources used here | the Ada ova_fmt: `~/Repos/RPG/Tools/ova_fmt/` (`PLAN.md`, `src/`, `test-data/`) |
| fltkada (FLTK 1.4 binding) | `/usr/local/sw/src/tkb/fltkada` (`readme.md`, `AGENTS.md`, `doc/binding_architecture.md`, `PROBLEMS-OUTSTANDING.md`, `examples/`) |
| alibfyaml (libfyaml binding) | `~/Repos/Ada/alibfyaml`; installed: `/usr/local/sw/versions/ada/include/libfyaml_ada`, `share/gpr/libfyaml_ada.gpr` |
| arg_parser | installed: `/usr/local/sw/versions/ada/include/arg_parser`, `share/gpr/arg_parser.gpr` |

## The rulebook's text stays out of the program

The program knows the *names* of Abilities, Weaknesses, Perks and Flaws,
the numbers the rules attach to them, and the rulebook page each is
described on. **It holds no descriptions**: none in the source, the
data tables, tooltips, tests or docs. To explain an item it opens the
rulebook at that page in the system's PDF viewer. Don't paste text from
`abilities.md`, `weaknesses.md` or the rulebook into this repo, even as
a comment.

**Every name the window shows has its page beside it** (`Attack
(p. 50)`), made by `Ova_Cg.Rules.Label` or `Page_Text`, never formatted
by hand. **Page numbers are the book's printed ones**; the PDF's page
index is the printed page + 2.

## Build / test

```sh
make                 # obj/ and ./ova_cg_ada
make test            # what needs no display: unit tests (TESTS), test/files.sh
                     #   (needs ova_fmt built: OVA_FMT), test/cli.sh
make check-pages     # Ova_Cg.Rules' pages against the rulebook's headings (needs mutool)
make test-viewers    # Ova_Cg.Viewer with real okular, evince, mupdf (test/viewer.sh;
                     #   its own headless sway and private bus)
make test-headless   # make test-gui on Xvfb: window tests (GUITESTS), the
                     #   program running RUNTIME seconds, test/quit.sh (Ctrl+E, Ctrl+Q)
make test-sway       # make test-gui on a headless sway (quit.sh skips: X11 only)
make valgrind-headless   # every test under valgrind, on Xvfb; also valgrind-sway
make install         # to $(PREFIX)/bin, default ~/local/bin (DESTDIR for staging)
make clean           # rm -rf obj ova_cg_ada
make print-VAR       # show a makefile variable
```

- **`make test-gui` and `make valgrind` use whatever display is set**:
  never run them directly here (that is the desktop); run the
  `-headless` and `-sway` targets.
- `ova_cg_ada.gpr` builds the program (`-XOVA_CG_MODE=program`) or a
  test program named on the command line (`-XOVA_CG_MODE=tests
  test_calc.adb`); the GNUmakefile does both. A new unit test needs
  only its file, `test/test_NAME.adb`, with NAME in the GNUmakefile's
  list for TESTS or GUITESTS.
- **fltkada is used where it is built** (`FLTKADA`, default
  `/usr/local/sw/src/tkb/fltkada`), through `proj/fltkada_ext.gpr`,
  which marks it `Externally_Built`: building here never compiles or
  relinks anything in that tree. Rebuild it there (`make
  build-dynamic`). It is a shared library built on the shared GNAT
  runtime, so everything here is bound with `-shared`.
- **ova_fmt's sources are compiled here as they are** (`OVA_FMT_SRC`,
  default `~/Repos/RPG/Tools/ova_fmt/src`), all but its main program
  and `Ova_Fmt.Cli`: `Ova_Fmt.Entities` reads a character exactly as
  ova_fmt does, and its Markdown and inline formatters make the
  Markdown tab. Change them in ova_fmt, never by copying.
- **Don't modify the library repos** (fltkada, alibfyaml, arg_parser,
  ova_fmt) without the user's go-ahead. A change one needs is made and
  tested in its own repo.
- **Don't run `make install` with the default `PREFIX` unless asked.**
- **A shell check's own mistakes look like the program's**: `env` takes
  its options before its assignments (`env -u TMUX DISPLAY= ...`).
  Read a FAIL's cause before changing the program.

## Windows and the display

- **An agent never opens windows on the user's desktop**: not the
  program, not a test, not a scratch program. The user's desktop is
  Wayland, and XWayland is the desktop too. Use `make test-headless`
  (Xvfb, `WAYLAND_DISPLAY` unset) or `make test-sway`, and for a single
  run `env -u WAYLAND_DISPLAY xvfb-run -a ./ova_cg_ada ...`.
- **Never start the user's PDF viewer either.** `test_spawn` and
  `test_viewer` put fakes in the programs' places: `test/fake-viewer.sh`
  records its arguments in `obj/fake-viewer.log` and runs until ended;
  `test/fake-gdbus.sh` answers okular's calls from
  `obj/gdbus.scenario` and logs them in `obj/gdbus.log`. Only `make
  test-viewers` runs the real viewers, on its own sway, private bus and
  scratch `HOME`.
- GUI tests drive themselves: `Do_Callback`, events sent to windows
  never shown, timers that answer dialogs, and freeing every window
  before the end. Look at a window by capturing it under Xvfb, not by
  showing it.
- **Nothing in the window waits for the user**: a message, the
  save-first question, the file chooser and the rulebook go through
  access-to-subprogram variables (`Ova_Cg.Window.Tell`, `Ask`,
  `Choose_Path`, `Ova_Cg.Widgets.Open_Page`, ...), which a test sets.
- **Never write the user's preferences**
  (`~/.config/ova_cg_ada/`): a test opens its own file in `obj/`, and
  `make test-gui` runs the program with `XDG_CONFIG_HOME` in `obj/`.
- **End only the processes you started, by PID.** Never `pkill -x
  okular` (or evince, mupdf). Never `pkill -f` with a pattern your own
  command line contains.

## Working with fltkada, alibfyaml and Ada here

- **The rules and the window are separate.** `Ova_Cg.Rules` and
  `Ova_Cg.Calc` use neither fltkada nor alibfyaml, so their tests run
  with no display. Every number on the window comes from `Ova_Cg.Calc`;
  no widget callback does arithmetic of its own.
- **Every computed number has an override box beside it**;
  `Ova_Cg.Calc` takes the overrides as input.
- **An fltkada object owns its C++ widget**, and its `Finalize` deletes
  it (deferred with `Fl::delete_widget` inside a callback). A C++
  group deletes its children when it is deleted, while their Ada
  objects still think they own them: **free a group's children's Ada
  objects before the group's** (in a record, declare the group first;
  free heap children first). `Group.Clear` removes children without
  deleting them.
- **Never free a widget, or clear its group, inside its own
  callback**: rebuild from a timeout (`FLTK.Static.Add_Timeout` with
  0.0), which a test runs with `FLTK.Wait`.
- **FLTK calls an Ada `Resize` override only for Box, Table and
  Table_Row** (fltkada's PROBLEMS-OUTSTANDING.md); a layout that must
  follow the window's size is done another way (PLAN.md).
- Callbacks are `access procedure (Item : in out Widget'Class)`;
  state rides in a derived widget's own fields. **Allocate widgets
  through named, library-level access types**: an anonymous access
  allocator fails its accessibility check (`Program_Error`).
- **A `Forge.Create` of a group ends it**: a group's children are
  made with the `Parent` form of `Create`, or between `Begin_Current`
  and `End_Current`.
- **A menu shortcut must be a key no input takes**: `Fl_Input` types
  Ctrl+H, I, J, L and M into itself and takes Ctrl+A, C, V, X and Z.
  Limits is Ctrl+E (`test/quit.sh`).
- **Browser lines and `Choice` items are 1-based (0: none)** in
  fltkada, where pofltk's `Choice` is 0-based; `Rules.Get` is 0-based,
  so a Choice's item is `Rules.Get (Kind, Chosen_Index - 1)`. No
  fltkada call chooses none: `FLTK.Widgets.Menus.Choices.Extra`
  (`src/`) has `Choose_None`. A browser that shows names has its format
  character off, so a name starting with `@` isn't a format code.
- **Save through alibfyaml's emitter** (`Libfyaml.Documents`), never by
  writing YAML text by hand. **Text goes through
  `Libfyaml.Documents.Styled`, never `Create_Scalar`**: libfyaml writes
  a `Create_Scalar` plain even where that changes or breaks it (`#1
  fan`, a leading quote). `Create_Scalar` is for keys and numbers.
  `Styled` lives here, not in alibfyaml (PLAN.md).
- **A portrait's path is relative to the YAML file**, so Save As
  rebases it with `Ova_Cg.Paths.Rebase`; paths are text, never looked
  up on disk.
- **Programs are started with `Ova_Cg.Spawn`**: an argument vector, no
  shell, detached in its own session (`setsid`), and a missing program
  reported as `ENOENT`.
- A programmer error is an assertion (`-gnata`); bad input, a cancelled
  dialog or a viewer that won't start comes back as `False` with a
  message, shown in a dialog.

## Testing policy

- Run `make test` after any change, and `make test-headless` after a
  change to the window.
- **The sample characters are the oracle for the calculations**:
  `test/test_calc.adb` checks every derived number on the fixtures
  (`test/data/`, ova_cg_po's, kept the same) as ova_cg_po's `TestCalc`
  does.
- **A file the program saves must load in ova_fmt** and format the same
  as the file it was loaded from: `test_files` saves each fixture into
  `obj/files/`, and `test/files.sh` formats both in every format and
  compares.
- Unit tests print `ok   - <label>` / `FAIL - <label>` and end with
  `All checks passed.` or `<N> check(s) failed.`, exiting 1 on failure
  (`test/check.ads`).
- **Prove a new check can fail**: plant the bug it targets and watch it
  fail.
- `make valgrind` must have no errors.

## Conventions

- Comments explain why and only claim what has been verified. A comment
  that depends on how FLTK, fltkada, libfyaml or a viewer behaves is
  tested with a throwaway program in the scratchpad first (under Xvfb).
- A rule in the code cites its rulebook page (`--  p. 83`), never its
  text.
- Record decisions and findings in PLAN.md as they happen. Mark a
  finished step `[done]`.
- Commit only when the user asks.
