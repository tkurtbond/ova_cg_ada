# PLAN.md

`ova_cg_ada` is an Ada port of `ova_cg_po`
(`~/Repos/RPG/Tools/ova_cg_po`), the Oberon-2 OVA character generator.
**ova_cg_po's PLAN.md is the design**: the rules the program computes,
the data tables, the window, the files, the viewer, and the reasons for
each. This file doesn't repeat it. It records how the port maps onto
Ada and its libraries, the decisions the port made, and the build
order. ova_cg_po's sources and tests are the specification: each
package ports a module, and each test its checks, with the same labels.

## The libraries

| ova_cg_po | ova_cg_ada |
|---|---|
| poc, `-OC` | GNAT (gprbuild), Ada 2022, `-gnata` |
| ArgParser | arg_parser (`arg_parser.gpr`) |
| Ropes | `Ada.Strings.Unbounded` |
| polibfyaml | alibfyaml (`libfyaml_ada.gpr`), with its `Libfyaml.Documents.Styled` (below) |
| pofltk | fltkada (`fltkada.gpr`, installed) |
| `OvaEntities`, `OvaText`, `OvaOut`, `OvaConfig`, `OvaCommon`, `OvaInline` (ova_fmt_po's, copied) | the Ada ova_fmt's packages, through its `ova_fmt_lib.gpr` (submodule `ext/ova_fmt`), not copied |
| `FlPreferences` | `FLTK.Environment` (`Fl_Preferences`) |
| `OvaSpawn.c` | `Ova_Cg.Spawn`, with what it needs of POSIX imported from C directly, or a small C file if that proves simpler |

## Packages

| ova_cg_po | ova_cg_ada |
|---|---|
| `OvaCg` (main) | `Ova_Cg_Main` (the executable `ova_cg_ada`), `Ova_Cg.Cli` |
| `OvaRules` | `Ova_Cg.Rules` |
| `OvaCalc` | `Ova_Cg.Calc` |
| `OvaCharacter` | `Ova_Cg.Character` |
| `OvaSave` | `Ova_Cg.Save` |
| `OvaPaths` | `Ova_Cg.Paths` |
| `OvaSpawn` | `Ova_Cg.Spawn` |
| `OvaViewer` | `Ova_Cg.Viewer` |
| `OvaWidgets` | `Ova_Cg.Widgets` |
| `OvaTraitPanel` | `Ova_Cg.Trait_Panel` |
| `OvaAttackDialog` | `Ova_Cg.Attack_Dialog` |
| `OvaLinkedDialog` | `Ova_Cg.Linked_Dialog` |
| `OvaSettings` | `Ova_Cg.Settings` |
| `OvaBackground` | `Ova_Cg.Background` |
| `OvaMarkdown` | `Ova_Cg.Markdown` |
| `OvaMarkdownTab` | `Ova_Cg.Markdown_Tab` |
| `OvaWindow` | `Ova_Cg.Window` |

Tests: `test/TestX.Mod` becomes `test/test_x.adb`, `Check.Mod`
`test/check.ads`, `ListRules.Mod` `test/list_rules.adb`, `OpenPage.Mod`
`test/open_page.adb`. The shell tests (`cli.sh`, `files.sh`,
`quit.sh`, `viewer.sh`, the fakes) and `test/data/` are ova_cg_po's,
with the program's name changed.

## Decisions

- **The main procedure is `Ova_Cg_Main`**, named `ova_cg_ada` by the
  project, since `Ova_Cg` is the packages' parent (as `Ova_Fmt` is
  ova_fmt's).
- **fltkada is used as installed** (`with "fltkada.gpr"`, the project
  gprinstall writes, which is `Externally_Built`), as arg_parser and
  libfyaml_ada are. Until 2026-11-17 it was used where it was built,
  through a project of our own (`proj/fltkada_ext.gpr`) marking that
  tree `Externally_Built`, since the tree's `fltkada.gpr` isn't; the
  install then was weeks behind the tree. Its library is dynamic
  (`library_type`'s default), on the shared GNAT runtime, so the
  program is bound with `-shared`; the run path gprbuild records finds
  `libfltkada.so` in the install (checked with `readelf -d`).
- **ova_fmt is a submodule, `ext/ova_fmt`, used through its library
  project `ova_fmt_lib.gpr`** (since 2026-11-17): all of its packages
  but `ova_fmt_main.adb` and `Ova_Fmt.Cli` (which parses ova_fmt's own
  command line at elaboration). `OVA_FMT_DIR` names another checkout.
  Before, ova_fmt's `src/` was compiled here from `OVA_FMT_SRC` (the
  user's own tree) with those three excluded, so anyone else building
  needed that tree where the user keeps it. The submodule pins a commit
  known to work, so a `git clone --recursive` builds; the library
  project keeps which files are the library in ova_fmt. ova_fmt's code
  is now compiled with its own switches (Ada 2012, no `-gnata`), not
  ours.
- **The prefs file is `$XDG_CONFIG_HOME/ova_cg_ada/ova_cg_ada.prefs`**
  (vendor and application `ova_cg_ada`), so the two programs' don't
  mix.
- **Usage errors**: arg_parser says what is wrong and prints the usage
  on standard error itself; `Ova_Cg.Cli` exits with status 2.
- **The files.sh oracle is the Ada ova_fmt** (`OVA_FMT`); ova_fmt_po
  gives the same output and can be named instead.
- **Styled scalars: `Libfyaml.Documents.Styled`, now in alibfyaml.**
  alibfyaml had no way to build a scalar with a style (polibfyaml's
  `CreateStyledScalar`), so it was written here first, as a child
  package, which sees the document's private handle, and then moved
  into alibfyaml with its own test (`test/test_styled.adb` there). It
  ports polibfyaml's logic (plain when plain is safe, a
  literal block for multi-line text that allows one, double-quoted
  otherwise). The node is parsed from its YAML source with
  `fy_node_build_from_malloc_string`: libfyaml keeps pointing into the
  source, so it is copied into a `malloc`'d buffer that libfyaml then
  owns and frees with the document (or with its parser, if the source
  doesn't parse); nothing here has to outlive the document. Text that
  isn't well-formed UTF-8 goes to `Create_Scalar`, as polibfyaml's
  does.
- **Save builds an empty document by parsing `"[]"`** and replacing its
  root: alibfyaml has no constructor for an empty one.
- **Save replaces the file with C's `rename`**, after writing
  `PATH.tmp` (`Ada.Directories.Rename` won't replace an existing
  file). Its messages are ova_cg_po's.
- **Messages are alibfyaml's**: a file that can't be read says
  `ova_cg_ada: FILE: No such file or directory`, without polibfyaml's
  `error: ` (`cli.sh` expects that).
- **The character type is `Character_Access`** (ova_cg_po's
  `OvaCharacter.Character`): `Character` would hide
  `Standard.Character`. Its record, `Character_Record`, extends
  `Calc.Sheet_Record`.
- **What is taken out of a list is the caller's to free**:
  `Remove_Trait`, `Remove_Modifier` and the rest clear the item's
  `Next`, so it can be freed alone with `Calc.Free_Traits` or
  `Free_Mods`; `Change_Trait` frees the linked content it drops. Where
  ova_cg_po's collector frees them, the window will.
- **The Markdown sheet is ova_fmt's output, caught in a temporary
  file**: ova_fmt's formatters write to `Ada.Text_IO`'s current
  output, so `Ova_Cg.Markdown` sets it to a nameless temporary file,
  resets that to `In_File` (which ends the last line, as closing it
  would, so the text is what `ova_fmt -o` writes) and reads it back
  through its text stream: GNAT won't open a file again that is still
  open unshared. `files.sh` compares every fixture's sheet and inline
  paragraphs with ova_fmt's (108); a byte planted in the sheet fails
  all 108. `test_files` saves them and checks `Markdown.Save`, as
  TestFiles does. `Save`'s message is `couldn't write PATH: ` and the
  system's reason, as `Save.Save_All`'s, where OvaMarkdown's gave an
  error number.
- **Ova_Cg.Spawn's C part is `src/ova_cg_spawn.c`**, OvaSpawn.c with
  its functions renamed `ova_cg_spawn_*`; the project's languages are
  Ada and C. `Args` keeps OvaSpawn's fixed 8192-byte vector, so one too
  long is still `E2BIG`.
- **`Terminate_Process`** is OvaSpawn's `Terminate`, a reserved word in
  Ada.
- **"" is NIL** in Spawn and Viewer: an empty argument reads back from
  `Arg` as "", no output from `Capture` is "", and `Choose` takes ""
  for an option not given.
- **The viewers' program names are variables** in `Ova_Cg.Viewer`'s
  spec (`Okular_Program` and the rest), as OvaViewer's are, so
  `test_viewer` puts the fakes in their place.
- **`Ova_Cg.Cli` checks `--viewer` with `Viewer.Parse`**, as OvaCg's
  `DoViewer` does, and holds the viewer parsed; the main gives it to
  the window, with `Viewer_Option` set so the one kept doesn't replace
  it.
- **The window frees what ova_cg_po's collector did**: the combat
  box's rows are freed and made again by `Show_Rows`, each child
  before its row; an attack removed is freed only after the rows are
  made again (a 0.0 timeout), since its row's boxes point to it; the
  characters put away by New or Open are freed after the new ones are
  shown, and a character removed after the next one is shown.
- **Boss NPCs** follow ova_cg_po's PLAN.md, "Boss NPCs": `Boss_Only`
  items that `Rules.Find` finds and `Count` and `Get` don't, offered
  through `Offer_Count`, `Offered` and `Offer_Index`, only by a Boss's
  own Abilities. The divider is `FLTK.Flag_Divider` on the last of the
  other Abilities: a flag, not a row, so no index shifts. The spell
  chooser needs no change, since its search already leaves unchosen an
  item it doesn't reach.

## Findings

- `Arg_Parser.Parse_Arguments` reports an unknown option, a missing
  argument or a bad one on standard error, with the usage, before it
  re-raises.
- fltk.ads's `pragma Linker_Options` (`-lfltk`, ...) reach only a
  program that `with`s FLTK, but every program here links
  `libfltkada.so` (the project imports it). **Fixed in fltkada** (with
  the user's go-ahead, 2026-11-17): its `fltkada.gpr` gives them as
  `Linker_Options`, which gprinstall copies into the installed
  project, and, for the dynamic kind, as `Library_Options`, so
  `libfltkada.so` records them (`NEEDED`).
- `Ova_Cg.Calc`'s lists are freed by hand (`Free`), where ova_cg_po's
  are collected, so a test that re-initializes a record still linked
  into a sheet (TestCalc's `InitAttack (a)` before the `Parse` checks)
  leaks what it held; `test_calc` uses a fresh attack there.
- END costs are `Natural`, so a lost floor at 0 raises
  `Constraint_Error` rather than giving a wrong number.
- **alibfyaml's emitter flags were wrong** (`Libfyaml.Thin`): it put
  the mode at bit 8 and the width at bit 16, but libfyaml's header has
  the indent at bit 8, the width at bit 12 and the mode at bit 20, so
  `Emit_Mode_Block` asked for the original mode, indented by one.
  **Fixed in alibfyaml** (with the user's go-ahead; its
  `test/test_emit.adb`), and `Ova_Cg.Save` passes `Emit_Mode_Block`,
  where it passed libfyaml's `FYECF_MODE_BLOCK` (`16#10_0000#`)
  itself. Its files are byte for byte ova_cg_po's (all 56 in
  `obj/files/`).
- **fltkada's `Textline_Browser.Set_Column_Widths` raised
  `Constraint_Error` on every call**: it copied `Widths'Length + 1`
  widths from `Widths`, one past its end, before setting the closing 0.
  **Fixed in fltkada** (its `test/column_widths.adb`, FLTKAda-BUGS.md
  section 10), and `Textline.Extra`, which this repo set them with, is
  gone.
- **fltkada leaked a `Text_Display`'s scrollbars**: freeing one lost
  its two `Fl_Scrollbar`s (184 bytes each, made in `Fl_Text_Display`'s
  constructor), since `Group`'s `Extra_Final` took every child out of
  the group (`Clear`) before the C++ destructor would delete the two
  FLTK made itself. **Fixed in fltkada** (with the user's go-ahead):
  a group takes out only the children made after its constructor
  (`test/group_children.adb`, FLTKAda-BUGS.md section 11).
- fltkada's `Forge.Create` of a group ends it (`fl_group_end`), and
  copies a widget's label (`copy_label`), so a label needn't outlive
  the call.
- **fltkada's `FLTK.Environment.Forge.Root` gives a group whose first
  `Set` crashes in FLTK** (`Storage_Error`, a segfault in
  libfltk): its C glue, `new_fl_pref_group_copy`, calls `new
  Fl_Preferences(static_cast<Fl_Preferences*>(e))`, and FLTK 1.4 has
  no constructor of one pointer, so C++ takes `Fl_Preferences(ID)`
  (`ID` is `void*`) and looks the database up as a node's id. Shown by
  a scratch program: `From_Filesystem`, `Root`, then `Set`. The copy
  constructor alone wouldn't do: the copy shares the database's root
  node, and `~Fl_Preferences` deletes the root node when its node has
  no parent, so the group and the database would both delete it.
  **Fixed in fltkada** (with the user's go-ahead): the root group is a
  `My_Root_Group`, a copy whose destructor forgets its node first;
  fltkada's `test/preferences.adb` and FLTKAda-BUGS.md section 9. The
  main opens `From_Scope (User, "ova_cg_ada", "ova_cg_ada")`, which
  FLTK keeps in `$XDG_CONFIG_HOME/ova_cg_ada/ova_cg_ada.prefs` (shown
  by a scratch program under valgrind).
- `FLTK.Environment.Flush` gave no result, so `Window.Keep` couldn't
  tell that the preferences weren't written. **Fixed in fltkada**
  (FLTKAda-BUGS.md section 12): it raises `Preference_Error`, and
  `Keep` says so; the choice still holds for the run (`test_limits`,
  with preferences under `/proc`).
- **FLTK calls the `Resize` of a hidden child box of the window**,
  which FLTK resizes with the window (smoke program), so a `Watcher`,
  a box as big as the window and hidden, is the window's resize hook:
  it fits what FLTK doesn't stretch (the combat box's rows) from a
  timeout. (It fitted the trait panels' name columns and the portrait
  too, until fltkada's `-1` column width and `Set_Image_Fit` let FLTK
  do both; 2026-11-15.)
- `FLTK.Asks.Text_Input` gives "" for Cancel, so the window's
  `Ask_Text` takes an empty answer as Cancel, as ova_cg_po's does.
- **fltkada keeps no count of the widgets open**, as pofltk's
  `OpenWidgets` is, so a GUI test's last check, "every widget is
  deleted", is that every accessor the window and its tabs and
  dialogs give is null after `Window.Close`; `make valgrind-headless`
  shows that none of their widgets is leaked. A closed dialog is freed
  from a timeout (it closes in its own callback), which the tests and
  a quit never get to run, so `Window.Close` frees them itself
  (`Free_Closed`); before it did, every dialog a test closed was lost.
- **fltkada binds no image writer** (it reads PNGs with
  `FLTK.Images.RGB.PNG`, no `fl_write_png`), so `test_resize` and
  `test_background` write their portraits as binary PPMs, which FLTK's
  `Fl_Shared_Image` reads as well.
- Neither `test_spawn` nor TestSpawn can tell whether
  `Terminate_Process` checks the start time: a planted bug that drops
  the check passes both, since no test can give a `Process` a reused
  pid.

## Build order

The phases are ova_cg_po's (its PLAN.md, "Build order"), each ported
with its tests before the next.

- Phase 0 [done]: the project, the GNUmakefile, the docs, the test
  scripts and fixtures, `test/check.ads`, and a main that parses the
  command line and checks for a display. `cli.sh` passes but for the
  two file checks, which need Phase 3 (they pass now).
- Phase 1 [done]: `Ova_Cg.Rules` and `test_rules`, `list_rules` (`make
  check-pages`: all 173 pages match the headings).
- Phase 2 [done]: `Ova_Cg.Calc` and `test_calc`'s hand-made checks
  (173, the same labels as ova_cg_po's run). The sample characters'
  checks need `Ova_Cg.Character`, and come with Phase 3.
- Phase 3 [done]: `Ova_Cg.Character`, `Ova_Cg.Save`,
  `Libfyaml.Documents.Styled`, and `test_files`, `test_model`,
  `files.sh`, `test_calc`'s twelve samples; the main loads its file.
  `test_calc` (408) and `test_files` (349) give ova_cg_po's output line
  for line, but for the Markdown checks; `test_model` passes its 29;
  `files.sh` its 424; valgrind: no errors, nothing lost.
- Phase 4 [done]: `Ova_Cg.Paths`, `Ova_Cg.Spawn`, `Ova_Cg.Viewer`, and
  `test_paths`, `test_spawn`, `test_viewer`, `open_page`. `test_paths`
  (21), `test_spawn` (28) and `test_viewer` (28) give ova_cg_po's
  output line for line; valgrind: no errors, nothing lost. `make
  test-viewers` passes its 28 with okular, evince and mupdf.
- Phase 5 [done]: the window. ova_cg_po built it a module at a time
  with its tests; here the modules come bottom-up, each compiled as it
  is written, since `Ova_Cg.Window` withs all of them and every GUI
  test needs it: `Ova_Cg.Widgets` [done], `Ova_Cg.Trait_Panel` [done],
  `Ova_Cg.Attack_Dialog` [done], `Ova_Cg.Settings` [done], `Ova_Cg.Background` [done],
  `Ova_Cg.Markdown` [done], `Ova_Cg.Markdown_Tab` [done], `Ova_Cg.Linked_Dialog` [done],
  `Ova_Cg.Window` [done]; then `test_window` (101), `test_background`
  (44), `test_linked` (58), `test_limits` (41), `test_markdown`,
  `test_resize`, `quit.sh`, and the main's window [done]: each test's
  labels are ova_cg_po's, check for check, and each was shown to fail
  on a planted bug. `make test`, `make test-headless`, `make
  test-sway` pass; `make valgrind-headless`: no errors.
- fltkada's Phase 30 helpers in use [done, 2026-11-15]: the main
  checks `FLTK.Static.Can_Open_Display` too (`cli.sh`, "named but
  gone"); menus use `Add_Text` and the item-state calls; the file
  choosers `Add_Filter`; the portrait `Set_Image_Fit`; the trait
  panels' and the attack dialog's name columns `-1`; spinners
  `Get_Integer_Value` (`Widgets.Spin_Value` gone); the prose
  `Set_Entire_Text_Quietly`; `test_limits` `Find_Line`. Linked_Dialog's
  widths stay fixed: the dialog doesn't resize. `Ova_Cg.Background`
  catches the `No_Image_Error` fltkada's `Shared.Forge.Create` now
  raises for a file it can't read (fltkada bug 141's fix). `make
  test`, `test-headless`, `test-sway`, `valgrind-headless` and
  `valgrind-sway` pass.
- fltkada used as installed [done, 2026-11-17]: `with "fltkada.gpr"`
  from `GPR_PROJECT_PATH`, `proj/fltkada_ext.gpr` and `FLTKADA` gone.
  fltkada's `fltkada.gpr` now gives the FLTK libraries as
  `Linker_Options` (and, dynamic, `Library_Options`); reinstalled at
  `/usr/local/sw/versions/ada`, static and dynamic, by its `make
  install PREFIX=...`. Found doing it (fltkada's FLTKAda-BUGS.md,
  section 142, fixed there with the user's go-ahead): its two kinds
  shared `obj/` and `lib/` (now `obj/KIND`, `lib/KIND`); gprinstall
  won't install over an install made from a since-changed `fltkada.gpr`
  (`install` now uninstalls first); and the installed project's
  `library_type` defaults to the kind installed first (`install` does
  dynamic first, and the GNUmakefile names `dynamic` anyway). The
  program's run path names the install, not the tree (`readelf -d`).
  `make test`, `test-headless` pass; fltkada's `check-headless` passes.
- ova_fmt as a submodule [done, 2026-11-17]: ova_fmt gained
  `ova_fmt_lib.gpr` (its packages but the command line, a static
  library), which its own `ova_fmt.gpr` withs; its output is unchanged
  (all of `test-data/` in every format, compared with the old binary).
  Here `with "ova_fmt_lib.gpr"`, found through `OVA_FMT_DIR`
  (`ext/ova_fmt`), which the GNUmakefile puts on `GPR_PROJECT_PATH`;
  `OVA_FMT_SRC` and the exclusion list gone; `OVA_FMT` defaults to the
  submodule's `ova_fmt`, built by `make test`. README.md has a quick
  start, tried from GitHub on a scratch prefix. It found that
  arg_parser didn't build from a clone: its `arg_parser.gpr` named a
  `config/` source directory that nothing fills (gitignored; Alire's
  configuration goes to `alire/config`). Fixed in arg_parser with the
  user's go-ahead: `config/` dropped, `alire.toml` uses `arg_parser.gpr`
  itself (its `project-files` named the gitignored
  `alire/alire_default.gpr`), and a GNUmakefile's `make install`, as
  alibfyaml's, which the quick start uses.

## The window's widgets

- **A Number_Box's `Target` is an interface** (`Get`, `Put`), which
  the window extends for each kind of number; the box owns its target
  and `Set_Target` frees the one before.
- **A Panel is an abstract tagged limited record** holding its
  widgets, not a widget: its callbacks find it by the widget's address
  among the open panels, as OvaWidgets' `PanelOf` does by pointer.
  `Close_Panel` frees its widgets, where ova_cg_po's are deleted with
  their window, so it is closed before its window is freed.
- **Menu labels from the user's text** are added with fltkada's
  `Add_Text`, which takes the text literally, so FLTK reads no `/` as
  a submenu and no `&` or `_` as a shortcut (`test_window`, "Imp/Co @b
  _x"). Until 2026-11-15 they were set with `Set_Label` on a
  placeholder item, as ova_cg_po does, with `&` doubled. Item state is
  `Is_Item_Checked`, `Set_Item_Checked` and `Set_Item_Active`.
- **A dialog that closes itself** (`Attack_Dialog`, and the others
  like it) hides its window and hands its widgets to a list a zero
  timeout frees, since OK and Cancel run inside a widget's callback.
  Its public state (`Dialog`) is null at once, as ova_cg_po's, so a
  test can open it again before the timeout runs.
- **Cancel's ownership**: the dialog frees what it takes out (a
  removed Perk or Flaw, the copy kept for Cancel, a new attack
  cancelled); the window must not use a new attack after `Done
  (False)`.
- **Background owns its two tabs**: `Build` opens the "Background"
  and "Fluff" groups inside the window's Tabs and `Close` frees every
  widget, then the tabs, so the window calls it before freeing its
  Tabs. Each prose buffer has its own modify callback, an instance of
  one generic a section, since fltkada's callback isn't told its
  buffer; `Show` sets them with `Set_Entire_Text_Quietly`, so the
  callbacks report nothing (until 2026-11-15, by being set while
  `Filling`).
- **The portrait is a shared image** (`FLTK.Images.Shared`, after
  `Register_Images`), which picks PNG, JPEG, GIF, BMP or SVG by the
  file's contents as OvaImages' `Load` does; an invalid or empty one
  is "can't be read". The one shown before is released first, so a
  file changed on disk is read again rather than found in FLTK's
  cache. fltkada's `Set_Image` can't show no image, so a removed
  portrait is cleared with `Clear_Image`, added to fltkada for this
  (with `Choice`'s `Clear_Chosen`; both were child packages here
  first). Checked under Xvfb: a
  800x1000 PNG shows at 194x243 in the 200x250 box and 394x493 after
  the box grows and `Fit`; a 40x50 one is not enlarged; a text file
  is "can't be read"; valgrind: no errors. Since 2026-11-15 the box
  has `Set_Image_Fit (True, Expand => False)`, so FLTK scales the
  image as it draws, keeping its own size, and `Fit` and `Scale` are
  gone (`test_resize`, `test_background`).
- **The notes are a vector** (`Ova_Fmt.Entities.Note_Vectors`), where
  ova_cg_po's are a list: Add appends, Change replaces the element,
  Remove deletes it.
- **Linked_Dialog finds a callback's sender by address** among its
  open widgets (`W'Address = Open.X.all'Address`), as Attack_Dialog
  does, and closes like it: Close hides the window, and a zero
  timeout frees the panels' widgets, then the window. Close waits
  while the attack dialog is open. A removed spell or attack is freed
  after the END box's target that points into it is cleared. Checked
  under Xvfb on Fukiko's form and Companion and Auren's Magic: valgrind
  shows no errors, and every block definitely lost is in fontconfig's
  or pango's font caches, none in the program or fltkada.
