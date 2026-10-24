--  The rulebook viewer: finding the PDF, and turning a viewer to a page.
--
--  ova_cg_po's PLAN.md, "The rulebook viewer": reuse a viewer already
--  open, start one only when none is.  okular is turned over D-Bus
--  (gdbus) when one shows the rulebook already, evince reuses its own
--  window, mupdf can't be reused, so the one this program started last
--  is ended (by its pid, never by name) before the next starts, and
--  xdg-open can't turn to a page at all, so the caller is told which.  A
--  command template runs as given.  Every program is started with
--  Ova_Cg.Spawn, never a shell.  Needs no display, and uses no fltkada.
--
--  The programs' names are variables, so the tests can put fakes in
--  their place (test_viewer).

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ova_Cg.Spawn;

package Ova_Cg.Viewer is

   --  The programs run, by name on PATH.
   Okular_Program   : Unbounded_String := To_Unbounded_String ("okular");
   Evince_Program   : Unbounded_String := To_Unbounded_String ("evince");
   Mupdf_Program    : Unbounded_String := To_Unbounded_String ("mupdf");
   Xdg_Open_Program : Unbounded_String := To_Unbounded_String ("xdg-open");
   Gdbus_Program    : Unbounded_String := To_Unbounded_String ("gdbus");

   --  ---- The PDF ----

   --  Whether a file is at Path.
   function Exists (Path : String) return Boolean;

   --  The rulebook's PDF: the first of Option (--rulebook), Env
   --  (OVA_RULEBOOK), Saved (the preferences) that isn't "", else the
   --  default under Home, made absolute.  Whether a file is there.
   function Choose (Option, Env, Saved, Home : String; Path : out Unbounded_String)
     return Boolean;

   --  Choose, with OVA_RULEBOOK and HOME from the environment.
   function Find_Rulebook (Option, Saved : String; Path : out Unbounded_String) return Boolean;

   --  ---- Viewers ----

   type Kind_Type is (Okular, Evince, Mupdf, Xdg_Open, Template);

   --  A viewer: its kind, and for a Template, the command, whose words
   --  %f, %p and %l become the PDF, the page index and the label.
   --  okular to start with.
   type Viewer_Type is private;

   function Kind (V : Viewer_Type) return Kind_Type;

   --  The viewer used when the user hasn't chosen one: the first of
   --  okular, evince and mupdf on PATH, else xdg-open.
   procedure Default (V : out Viewer_Type);

   --  The viewer S names: "okular", "evince", "mupdf", "xdg-open", or a
   --  command template, which must hold %f.  False, V unchanged, for
   --  anything else.
   function Parse (S : String; V : in out Viewer_Type) return Boolean;

   --  What Parse takes back: the viewer's name, or its template.
   function Name (V : Viewer_Type) return String;

   --  The command that starts V on Pdf at printed page Page, in A.
   procedure Command (V : Viewer_Type; Pdf : String; Page : Positive; A : out Spawn.Args);

   --  Pdf as a file: URL for okular's openDocument, with only "%", "#",
   --  "?" and control characters percent-encoded (ova_cg_po's PLAN.md,
   --  "Findings": okular compares the URL with its tabs' as given).
   function File_Url (Pdf : String) return String;

   --  ---- Opening ----

   --  Shows printed page Page of Pdf (an absolute path, as Choose
   --  gives) in V.  False, with Msg saying why, if the viewer couldn't
   --  be started; True with Msg set if the user has more to do
   --  (xdg-open can't turn to a page), and with Msg "" if not.
   function Open (V : Viewer_Type; Pdf : String; Page : Positive; Msg : out Unbounded_String)
     return Boolean;

   --  Ends the mupdf Open started last, if it is still running.
   procedure End_Mupdf;

   --  The mupdf Open started last, for the tests: its pid, 0 for none
   --  or ended.
   function Last_Mupdf return Integer;

private

   type Viewer_Type is record
      Kind     : Kind_Type := Okular;
      Template : Unbounded_String;
   end record;

end Ova_Cg.Viewer;
