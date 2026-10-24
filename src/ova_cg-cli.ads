--  The command line (PLAN.md, "Starting"): -h, -r, -v and one file.
--  A mistake on it ends the program with Usage_Error_Status.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ova_Cg.Viewer;

package Ova_Cg.Cli is

   Usage_Error_Status : constant := 2;
   Failure_Status     : constant := 1;

   Help_Shown : Boolean := False;
   Has_File   : Boolean := False;
   File       : Unbounded_String;  --  the file argument, if Has_File

   Has_Rulebook : Boolean := False;
   Rulebook     : Unbounded_String;  --  -r's PDF, if Has_Rulebook
   Has_Viewer   : Boolean := False;
   Viewer       : Ova_Cg.Viewer.Viewer_Type;  --  -v's viewer, if Has_Viewer

   --  Parses the command line, or says what is wrong on standard error
   --  and exits with Usage_Error_Status.
   procedure Parse;

   --  Says "ova_cg_ada: A" on standard error and exits with Status.
   procedure Fail (Status : Integer; Message : String) with No_Return;

end Ova_Cg.Cli;
