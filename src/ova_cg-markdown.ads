--  A character's sheet in Markdown: ova_fmt's -M, or its -i inline
--  paragraph.
--
--  ova_cg_po's PLAN.md, "The Markdown sheet".  The character as it
--  would be saved, read back as ova_fmt reads it (Save.To_Entity), and
--  formatted by ova_fmt's own Format_Markdown, compiled in place, as
--  `ova_fmt -M` formats the saved file: so the sheet is the same text,
--  and test/files.sh checks that it is.  Inline is the same for
--  ova_fmt's inline format (-i), by its Format_Inline.  ova_fmt writes
--  to Ada.Text_IO's current output; that is a temporary file while a
--  sheet is made, read back here.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ova_Cg.Character;

package Ova_Cg.Markdown is

   --  C's sheet, ova_fmt -M's, in Text; False if C couldn't be read
   --  back (a programmer's error), Text then empty.
   function Sheet (C : not null Character.Character_Access; Text : out Unbounded_String)
     return Boolean;

   --  C as an inline paragraph, ova_fmt -i's, as Sheet.
   function Inline (C : not null Character.Character_Access; Text : out Unbounded_String)
     return Boolean;

   --  Writes Text to the file at Path, through Path.tmp, which replaces
   --  it only once written, as Save.Save_All does.  False, with Msg, if
   --  it couldn't be, the old file left as it was.
   function Save (Text : String; Path : String; Msg : out Unbounded_String) return Boolean;

end Ova_Cg.Markdown;
