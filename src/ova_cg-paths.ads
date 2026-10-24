--  File paths: made absolute, a file's directory, and one path relative
--  to a directory.
--
--  ova_cg_po's PLAN.md, "The second tab": a character's portrait is
--  saved as a path relative to its YAML file (Changes to ova_fmt,
--  portrait), so the window finds the image from the file's directory,
--  and Save As to another directory rebases the path.  Paths here are
--  text alone: no file is looked at, and symbolic links aren't
--  followed, so "a/../b" is "b" even where a is a link.  A path is
--  "/"-separated; "" is none.

package Ova_Cg.Paths is

   function Is_Absolute (Path : String) return Boolean is
     (Path'Length > 0 and then Path (Path'First) = '/');

   --  Path without "." parts, doubled "/"s, a "/" at the end, or ".."
   --  after a name: "a/./b//../c/" is "a/c".  "." for a relative path
   --  that comes to nothing.
   function Normalize (Path : String) return String;

   --  Path made absolute against directory Base (itself made absolute
   --  against the working directory), and normalized; "" for "".
   function Absolute (Path : String; Base : String := "") return String;

   --  The absolute directory File is in.
   function Dir (File : String) return String;

   --  Path (made absolute as Absolute does, against the working
   --  directory) relative to directory In_Dir: "../images/a.png".  "."
   --  for In_Dir itself.
   function Relative (Path, In_Dir : String) return String;

   --  Path, given relative to directory From, rewritten relative to
   --  directory To: a portrait's path when its YAML file moves.  An
   --  absolute path is made relative to To: a character never saved
   --  (From "") holds the absolute path it was given until its first
   --  save.  A relative path with no From to resolve it against stays as
   --  it is.
   function Rebase (Path, From, To : String) return String;

end Ova_Cg.Paths;
