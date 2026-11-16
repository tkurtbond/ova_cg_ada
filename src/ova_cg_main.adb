--  ova_cg_ada: an OVA character generator; the main program.
--
--  PLAN.md, "Starting": the command line, then the file, then a
--  display, then the window.  A file that can't be opened is said on
--  standard error, status 1, before a display is needed, as a mistake
--  on the command line is (status 2).  The program can't do anything
--  without a window, so with no display it says so and exits with
--  status 1, before FLTK is asked to open one, which would end the
--  program with FLTK's own "Can't open display".  A display that is
--  named but can't be opened is said too (FLTK.Static.Can_Open_Display).

with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Ada.Unchecked_Deallocation;
with FLTK.Environment;
with FLTK.Static;
with FLTK;
with Ova_Cg.Character;
with Ova_Cg.Cli;
with Ova_Cg.Window;

procedure Ova_Cg_Main is

   use Ova_Cg;

   package Ch renames Ova_Cg.Character;

   Characters : Ch.Characters;  --  the file's, in its order; none without one

   --  Where the rulebook's path and the viewer chosen are kept:
   --  $XDG_CONFIG_HOME/Vendor/Application.prefs.
   Vendor      : constant String := "ova_cg_ada";
   Application : constant String := "ova_cg_ada";

   --  The file argument's characters, or a reason on standard error,
   --  status 1.
   procedure Load_File is
      Msg : Unbounded_String;
   begin
      if not Ch.Load_All (To_String (Cli.File), Characters, Msg) then
         Cli.Fail (Cli.Failure_Status, To_String (Msg));
      end if;
   end Load_File;

   --  True if the environment variable Name is set and not empty.
   function Is_Set (Name : String) return Boolean is
     (Ada.Environment_Variables.Exists (Name)
      and then Ada.Environment_Variables.Value (Name) /= "");

   --  With no display, the reason and, in tmux, where it came from
   --  (PLAN.md, "Findings": a tmux session last attached from a
   --  terminal without a display drops DISPLAY and WAYLAND_DISPLAY from
   --  new panes, and may keep a DISPLAY that is gone).  Both unset is
   --  refused before FLTK is asked: FLTK would still try the socket
   --  wayland-0.
   procedure Require_Display is
      use Ada.Text_IO;
      Unset : constant Boolean := not Is_Set ("DISPLAY") and not Is_Set ("WAYLAND_DISPLAY");
   begin
      if Unset or else not FLTK.Static.Can_Open_Display then
         Flush (Standard_Output);
         if Unset then
            Put_Line (Standard_Error,
                      Program & ": no display: neither DISPLAY nor WAYLAND_DISPLAY is set");
         else
            Put_Line (Standard_Error,
                      Program & ": no display: the one DISPLAY or WAYLAND_DISPLAY names can't be opened");
         end if;
         if Is_Set ("TMUX") then
            Put_Line (Standard_Error,
                      Program & ": in tmux, the session may have been attached from a "
                      & "terminal without one; reattach from the desktop, or set them "
                      & "from `tmux show-environment -g`");
         end if;
         GNAT.OS_Lib.OS_Exit (Cli.Failure_Status);
      end if;
   end Require_Display;

begin
   Cli.Parse;
   if Cli.Help_Shown then
      return;
   end if;
   if Cli.Has_File then
      Load_File;
   end if;
   Require_Display;
   if Cli.Has_Rulebook then
      Window.Rulebook_Option := Cli.Rulebook;
   end if;
   if Cli.Has_Viewer then
      Window.Viewer := Cli.Viewer;
      Window.Viewer_Option := True;
   end if;
   Window.Build;
   declare
      procedure Free is new Ada.Unchecked_Deallocation
        (FLTK.Environment.Database'Class, Window.Database_Access);
      Prefs  : Window.Database_Access :=
        new FLTK.Environment.Database'
          (FLTK.Environment.Forge.From_Scope (FLTK.Environment.User, Vendor, Application));
      Status : Integer;
   begin
      Window.Use_Preferences (Prefs);
      Window.Main.Show;
      if Cli.Has_File then
         Window.Adopt (Characters, To_String (Cli.File));
      end if;
      Status := FLTK.Run;
      pragma Unreferenced (Status);
      Window.Close;
      Free (Prefs);
   end;
end Ova_Cg_Main;
