with Ada.Text_IO;
with GNAT.OS_Lib;
with Arg_Parser;

package body Ova_Cg.Cli is

   function Do_Help return Boolean;
   function Do_Rulebook (Arg : String) return Boolean;
   function Do_Viewer (Arg : String) return Boolean;
   function Do_Argument (Start_With : Positive; Arg : String) return Boolean;

   Options : aliased Arg_Parser.Option_Array :=
     [Arg_Parser.Make_Option
        ("Display this text.", 'h', "help", Do_Help'Access),
      Arg_Parser.Make_String_Option
        ("The rulebook's PDF (else OVA_RULEBOOK, else the one chosen before, "
         & "else ~/Reference/RPG/OVA/).", 'r', "rulebook", Do_Rulebook'Access),
      Arg_Parser.Make_String_Option
        ("okular, evince, mupdf, xdg-open, or a command: %f the PDF, "
         & "%p its page, %l the printed page.", 'v', "viewer", Do_Viewer'Access)];

   The_Parser : constant Arg_Parser.Parser :=
     Arg_Parser.Make_Parser
       (Program & " [options] [file.yaml]", Do_Argument'Access, Options'Access);

   procedure Fail (Status : Integer; Message : String) is
   begin
      Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Program & ": " & Message);
      GNAT.OS_Lib.OS_Exit (Status);
   end Fail;

   function Do_Help return Boolean is
   begin
      Arg_Parser.Usage (The_Parser);
      Help_Shown := True;
      return False;
   end Do_Help;

   function Do_Rulebook (Arg : String) return Boolean is
   begin
      Has_Rulebook := True;
      Rulebook := To_Unbounded_String (Arg);
      return True;
   end Do_Rulebook;

   function Do_Viewer (Arg : String) return Boolean is
   begin
      if not Ova_Cg.Viewer.Parse (Arg, Viewer) then
         Fail (Usage_Error_Status,
               "--viewer takes okular, evince, mupdf, xdg-open, or a command "
               & "with %f for the PDF: " & Arg);
      end if;
      Has_Viewer := True;
      return True;
   end Do_Viewer;

   function Do_Argument (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Has_File then
         Fail (Usage_Error_Status, "one file at a time: " & Arg);
      end if;
      Has_File := True;
      File := To_Unbounded_String (Arg);
      return True;
   end Do_Argument;

   procedure Parse is
   begin
      Arg_Parser.Parse_Arguments (The_Parser);
   exception
      --  Arg_Parser has said what is wrong, and the usage, on standard
      --  error.
      when Arg_Parser.Unknown_Option | Arg_Parser.Unknown_Argument
         | Arg_Parser.Argument_Required | Arg_Parser.Invalid_Option_Argument =>
         GNAT.OS_Lib.OS_Exit (Usage_Error_Status);
   end Parse;

end Ova_Cg.Cli;
