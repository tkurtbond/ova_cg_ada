--  Ova_Cg.Paths: normalizing, absolute and relative paths, and rebasing
--  a portrait's.
--
--  Paths are text alone here, so these need no files and no display.

with Ada.Directories;
with Ada.Text_IO;
with Check;
with Ova_Cg.Paths; use Ova_Cg.Paths;

procedure Test_Paths is

   Cwd : constant String := Ada.Directories.Current_Directory;

   procedure Is_Path (Got, Want, Label : String) is
   begin
      Check.Check (Got = Want, Label);
      if Got /= Want then
         Ada.Text_IO.Put_Line ("    got: " & Got);
      end if;
   end Is_Path;

begin
   Is_Path (Normalize ("a/./b//../c/"), "a/c", "Normalize: . and doubled / dropped, .. takes out a name");
   Is_Path (Normalize ("/../a/.."), "/", "Normalize: .. at the root stays at the root");
   Is_Path (Normalize ("../../a"), "../../a", "Normalize: a relative path's leading .. kept");
   Is_Path (Normalize ("a/.."), ".", "Normalize: nothing left is .");

   Is_Path (Absolute ("images/a.png", "/home/u/chars"), "/home/u/chars/images/a.png",
            "Absolute: against the base");
   Is_Path (Absolute ("../a.png", "/home/u/chars"), "/home/u/a.png", "Absolute: .. out of the base");
   Is_Path (Absolute ("/x/y.png", "/home/u"), "/x/y.png", "Absolute: an absolute path is itself");
   Check.Check (Absolute ("a.png") = Cwd & "/a.png", "Absolute: no base is the working directory");
   Check.Check (Absolute ("", "/a") = "", "Absolute: NIL is NIL");

   Is_Path (Dir ("/home/u/chars/hana.yaml"), "/home/u/chars", "Dir: the file's directory");
   Is_Path (Dir ("/hana.yaml"), "/", "Dir: at the root");
   Check.Check (Dir ("hana.yaml") = Cwd, "Dir: of a relative name, the working directory");

   Is_Path (Relative ("/home/u/chars/images/a.png", "/home/u/chars"), "images/a.png", "Relative: below");
   Is_Path (Relative ("/home/u/pics/a.png", "/home/u/chars"), "../pics/a.png", "Relative: beside");
   Is_Path (Relative ("/x/a.png", "/home/u/chars"), "../../../x/a.png", "Relative: all the way up");
   Is_Path (Relative ("/home/u/chars", "/home/u/chars"), ".", "Relative: the directory itself");
   Is_Path (Relative ("/home/u/charsx/a.png", "/home/u/chars"), "../charsx/a.png",
            "Relative: a name's prefix isn't a directory");

   Is_Path (Rebase ("images/a.png", "/home/u/chars", "/home/u/backup"), "../chars/images/a.png",
            "Rebase: the file moved, the image didn't");
   Is_Path (Rebase ("/home/u/pics/a.png", "", "/home/u/chars"), "../pics/a.png",
            "Rebase: an absolute path, on the first save");
   Is_Path (Rebase ("a.png", "", "/home/u"), "a.png", "Rebase: a relative path with no from stays");
   Check.Check (Rebase ("", "/a", "/b") = "", "Rebase: no portrait, none");

   Check.Summary;
end Test_Paths;
