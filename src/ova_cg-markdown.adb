with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Text_IO.Text_Streams;
with GNAT.OS_Lib;
with Interfaces.C.Strings;
with Ova_Cg.Save;
with Ova_Fmt.Config;
with Ova_Fmt.Entities;
with Ova_Fmt.Format_Inline;
with Ova_Fmt.Format_Markdown;

package body Ova_Cg.Markdown is

   package IO renames Ada.Text_IO;
   package SIO renames Ada.Streams.Stream_IO;
   package Saving renames Ova_Cg.Save;

   --  The rest of File, an In_File, byte for byte.
   function Read_All (File : IO.File_Type) return Unbounded_String is
      use type Ada.Streams.Stream_Element_Offset;
      S      : constant IO.Text_Streams.Stream_Access := IO.Text_Streams.Stream (File);
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Text   : Unbounded_String;
   begin
      loop
         S.Read (Buffer, Last);
         exit when Last < Buffer'First;
         for B of Buffer (1 .. Last) loop
            Append (Text, Standard.Character'Val (B));
         end loop;
      end loop;
      return Text;
   end Read_All;

   --  C in the format F, Markdown or Inline, into Text.
   function Format (C : not null Character.Character_Access; F : Ova_Fmt.Config.Output_Format;
                    Text : out Unbounded_String) return Boolean
   is
      use type Ova_Fmt.Config.Output_Format;
      E    : Ova_Fmt.Entities.Entity;
      Old  : constant IO.File_Access := IO.Current_Output;
      Temp : IO.File_Type;
   begin
      Text := Null_Unbounded_String;
      if not Saving.To_Entity (C, E) then
         return False;
      end if;
      Ova_Fmt.Config.Format := F;
      IO.Create (Temp, IO.Out_File);   --  no name: deleted when closed
      IO.Set_Output (Temp);
      begin
         if F = Ova_Fmt.Config.Inline then
            Ova_Fmt.Format_Inline.Process_Entity (E, 1);
         else
            Ova_Fmt.Format_Markdown.Process_Entity (E, 1);
         end if;
      exception
         when others =>
            IO.Set_Output (Old.all);
            IO.Close (Temp);
            Character.Free_Entity (E);
            raise;
      end;
      IO.Set_Output (Old.all);
      Character.Free_Entity (E);
      --  Reset ends the last line, as closing it would: as ova_fmt -o's
      --  file ends.
      IO.Reset (Temp, IO.In_File);
      Text := Read_All (Temp);
      IO.Close (Temp);
      return True;
   end Format;

   function Sheet (C : not null Character.Character_Access; Text : out Unbounded_String)
     return Boolean is (Format (C, Ova_Fmt.Config.Markdown, Text));

   function Inline (C : not null Character.Character_Access; Text : out Unbounded_String)
     return Boolean is (Format (C, Ova_Fmt.Config.Inline, Text));

   --  C's: Ada.Directories.Rename raises Use_Error where To exists.
   function C_Rename (From, To : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "rename";

   function Save (Text : String; Path : String; Msg : out Unbounded_String) return Boolean is
      use type Interfaces.C.int;
      package CStr renames Interfaces.C.Strings;
      Tmp : constant String := Path & ".tmp";
      F   : SIO.File_Type;
   begin
      Msg := Null_Unbounded_String;
      begin
         SIO.Create (F, SIO.Out_File, Tmp);
         String'Write (SIO.Stream (F), Text);
         SIO.Close (F);
      exception
         when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error
            | Ada.IO_Exceptions.Device_Error =>
            Msg := To_Unbounded_String ("couldn't write " & Path & ": " & GNAT.OS_Lib.Errno_Message);
            if SIO.Is_Open (F) then
               SIO.Close (F);
            end if;
            if Ada.Directories.Exists (Tmp) then
               Ada.Directories.Delete_File (Tmp);
            end if;
            return False;
      end;
      declare
         From : CStr.chars_ptr := CStr.New_String (Tmp);
         To   : CStr.chars_ptr := CStr.New_String (Path);
         Rc   : constant Interfaces.C.int := C_Rename (From, To);
      begin
         CStr.Free (From);
         CStr.Free (To);
         if Rc /= 0 then
            Msg := To_Unbounded_String ("couldn't write " & Path & ": " & GNAT.OS_Lib.Errno_Message);
            Ada.Directories.Delete_File (Tmp);
            return False;
         end if;
      end;
      return True;
   end Save;

end Ova_Cg.Markdown;
