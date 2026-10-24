--  Writes characters as YAML in ova_fmt's format.
--
--  ova_cg_po's PLAN.md, "Files".  The document is built with
--  alibfyaml's emitter, never written as text here, so the quoting is
--  libfyaml's: text goes through Libfyaml.Documents.Styled, since
--  libfyaml writes a Create_Scalar plain even where plain YAML can't
--  hold it ("#1 fan" reads back as a comment).  Text of more than one
--  line is a literal block, as in ova_fmt's fixtures; any other, plain
--  where that is safe, else double-quoted.  Numbers, booleans and keys
--  are plain.
--
--  One document, a sequence of the file's characters, in order, each
--  entity's keys in the order of ova_fmt's fixtures.  The numbers
--  written are the ones in effect: an override where there is one,
--  which the mapping's overrides: key then lists.
--
--  A failed save leaves the old file as it was: the document goes to
--  PATH.tmp, which then replaces PATH.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ova_Cg.Character;
with Ova_Fmt.Entities;

package Ova_Cg.Save is

   --  The characters Cs as YAML text, for the tests.
   function All_To_Text (Cs : Character.Characters) return String;

   --  C as YAML text, for the tests.
   function To_Text (C : not null Character.Character_Access) return String;

   --  Writes the characters Cs to the file at Path, through Path.tmp,
   --  which replaces it only once written.  False, with Msg, if it
   --  couldn't be, the old file left as it was.
   function Save_All (Cs : Character.Characters; Path : String; Msg : out Unbounded_String)
     return Boolean;

   --  C alone, as Save_All.
   function Save (C : not null Character.Character_Access; Path : String;
                  Msg : out Unbounded_String) return Boolean;

   --  C as it would be saved, read back as ova_fmt reads a file's
   --  entity.  False if C's YAML couldn't be built or read (a
   --  programmer's error).  Free E with Character.Free_Entity.
   function To_Entity (C : not null Character.Character_Access; E : out Ova_Fmt.Entities.Entity)
     return Boolean;

   --  A copy of C, sharing nothing with it: To_Entity's, made a
   --  character as a file's is.  A saved character reads back with no
   --  notices, so the copy's numbers are C's.  null as To_Entity.
   function Copy (C : not null Character.Character_Access) return Character.Character_Access;

end Ova_Cg.Save;
