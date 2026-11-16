with Ada.Unchecked_Deallocation;
with FLTK.Asks;
with FLTK.Native_File_Choosers;
with FLTK.Text_Buffers;
with Ova_Cg.Paths;
with Ova_Fmt.Entities;

package body Ova_Cg.Background is

   use Ada.Strings.Unbounded;
   use type FLTK.Alignment;
   use type Character.Character_Access;
   use type Widgets.Input_Access;

   package Buffers renames FLTK.Text_Buffers;
   package Displays renames FLTK.Widgets.Groups.Text_Displays;
   package Texts renames Widgets.Texts;

   type Buffer_Access is access all Buffers.Text_Buffer'Class;

   --  A fluff field's input: which field it edits.
   type Fluff_Input is new Texts.Text_Input with record
      Field : Character.Fluff_Field;
   end record;

   Row        : constant := 25;
   Left_X     : constant := 10;
   Column_W   : constant := 620;
   Portrait_W : constant := 200;
   Portrait_H : constant := 250;
   Fluff_Rows : constant := 7;

   --  The headings: one a prose section, the portrait's, the notes'.
   Headings : constant := Prose_Section'Pos (Prose_Section'Last) + 3;

   type Editor_Array is array (Prose_Section) of Editor_Access;
   type Buffer_Array is array (Prose_Section) of Buffer_Access;
   type Input_Array is array (Character.Fluff_Field) of Widgets.Input_Access;
   type Box_Array is array (Character.Fluff_Field) of Box_Access;
   type Heading_Array is array (1 .. Headings) of Box_Access;

   type Parts is record
      Background_Tab, Fluff_Tab : Group_Access;
      Summary_In      : Widgets.Input_Access;
      Prose           : Editor_Array;
      Buffers         : Buffer_Array;
      Headings        : Heading_Array;
      Heads           : Natural := 0;  --  Headings (1 .. Heads) opened
      Portrait        : Box_Access;
      Portrait_Path   : Widgets.Output_Access;
      Choose_Portrait, Remove_Portrait : Widgets.Button_Access;
      Image           : Image_Access;
      Fluff_Grid      : Grid_Access;
      Fluff_Labels    : Box_Array;
      Fluff_In        : Input_Array;
      Notes           : Widgets.Browser_Access;
      Note_Header     : Widgets.Input_Access;
      Note_Text       : Multiline_Access;
      Add_Note, Change_Note, Remove_Note : Widgets.Button_Access;
   end record;

   Open : Parts;

   The_Character : Character.Character_Access;
   File_Dir      : Unbounded_String;  --  the YAML file's directory, absolute; "": never saved
   Filling       : Boolean := False;  --  the inputs being set from the character: no change to report

   function Background_Tab return Group_Access is (Open.Background_Tab);
   function Fluff_Tab return Group_Access is (Open.Fluff_Tab);
   function Summary_In return Widgets.Input_Access is (Open.Summary_In);
   function Prose (Which : Prose_Section) return Editor_Access is (Open.Prose (Which));
   function Portrait return Box_Access is (Open.Portrait);
   function Portrait_Path return Widgets.Output_Access is (Open.Portrait_Path);
   function Choose_Portrait return Widgets.Button_Access is (Open.Choose_Portrait);
   function Remove_Portrait return Widgets.Button_Access is (Open.Remove_Portrait);
   function Portrait_Image return Image_Access is (Open.Image);
   function Fluff_Grid return Grid_Access is (Open.Fluff_Grid);
   function Fluff_In (Field : Character.Fluff_Field) return Widgets.Input_Access is
     (Open.Fluff_In (Field));
   function Notes return Widgets.Browser_Access is (Open.Notes);
   function Note_Header return Widgets.Input_Access is (Open.Note_Header);
   function Note_Text return Multiline_Access is (Open.Note_Text);
   function Add_Note return Widgets.Button_Access is (Open.Add_Note);
   function Change_Note return Widgets.Button_Access is (Open.Change_Note);
   function Remove_Note return Widgets.Button_Access is (Open.Remove_Note);

   --  ---- Text ----

   --  What input I holds, trimmed; "" if blank.
   function Input_Text (I : FLTK.Widgets.Inputs.Input'Class) return Unbounded_String is
     (To_Unbounded_String (Character.Trim (I.Get_Value)));

   procedure Report is
   begin
      if Changed /= null then
         Changed.all;
      end if;
   end Report;

   --  ---- The prose sections ----

   function Prose_Of (Which : Prose_Section) return Unbounded_String is
      C : Character.Character_Record'Class renames The_Character.all;
   begin
      case Which is
         when Background_Section      => return C.Background;
         when Appearance_Section      => return C.Appearance;
         when Personality_Section     => return C.Personality;
         when Character_Hooks_Section => return C.Character_Hooks;
         when Other_Notes_Section     => return C.Other_Notes;
      end case;
   end Prose_Of;

   --  Section Which's text, trimmed as the loader trims it, so what is
   --  saved loads the same; blank is absent.  One instance a section:
   --  a buffer's callback isn't told which buffer it is.
   generic
      Which : Prose_Section;
   procedure Prose_Modified (Place, Inserted, Deleted, Restyled : Natural; Deleted_Text : String);

   procedure Prose_Modified (Place, Inserted, Deleted, Restyled : Natural; Deleted_Text : String) is
      pragma Unreferenced (Place, Restyled, Deleted_Text);
      R : Unbounded_String;
   begin
      if The_Character = null or else (Inserted = 0 and Deleted = 0) or else Open.Buffers (Which) = null then
         return;
      end if;
      R := To_Unbounded_String (Character.Trim (Open.Buffers (Which).Get_Entire_Text));
      declare
         C : Character.Character_Record'Class renames The_Character.all;
      begin
         case Which is
            when Background_Section      => Character.Set_Text (C.Has_Background, C.Background, R);
            when Appearance_Section      => Character.Set_Text (C.Has_Appearance, C.Appearance, R);
            when Personality_Section     => Character.Set_Text (C.Has_Personality, C.Personality, R);
            when Character_Hooks_Section =>
               Character.Set_Text (C.Has_Character_Hooks, C.Character_Hooks, R);
            when Other_Notes_Section     => Character.Set_Text (C.Has_Other_Notes, C.Other_Notes, R);
         end case;
      end;
      Report;
   end Prose_Modified;

   procedure Background_Modified is new Prose_Modified (Background_Section);
   procedure Appearance_Modified is new Prose_Modified (Appearance_Section);
   procedure Personality_Modified is new Prose_Modified (Personality_Section);
   procedure Character_Hooks_Modified is new Prose_Modified (Character_Hooks_Section);
   procedure Other_Notes_Modified is new Prose_Modified (Other_Notes_Section);

   Modified : constant array (Prose_Section) of Buffers.Modify_Details_Callback :=
     [Background_Section      => Background_Modified'Access,
      Appearance_Section      => Appearance_Modified'Access,
      Personality_Section     => Personality_Modified'Access,
      Character_Hooks_Section => Character_Hooks_Modified'Access,
      Other_Notes_Section     => Other_Notes_Modified'Access];

   --  ---- The portrait ----

   procedure Free_Image is new Ada.Unchecked_Deallocation (Shared.Shared_Image'Class, Image_Access);

   --  Shows the character's portrait, or says why it can't.  The image
   --  shown before is given up first, so a file changed on disk is read
   --  again, not found in FLTK's cache of shared images.
   procedure Show_Portrait is
      C : Character.Character_Record'Class renames The_Character.all;
   begin
      Open.Portrait_Path.Set_Value (To_String (C.Portrait));
      Open.Portrait.Clear_Image;
      Free_Image (Open.Image);
      if C.Has_Portrait then
         begin
            Open.Image := new Shared.Shared_Image'
              (Shared.Forge.Create (Paths.Absolute (To_String (C.Portrait), To_String (File_Dir)), 0, 0));
         exception
            when FLTK.Images.No_Image_Error =>
               null;
         end;
         if Open.Image /= null and then Open.Image.Is_Valid and then not Open.Image.Is_Empty then
            Open.Portrait.Set_Label ("");
            Open.Portrait.Set_Image (Open.Image.all);
         else
            Free_Image (Open.Image);
            Open.Portrait.Set_Label ("The image can't be read.");
         end if;
      else
         Open.Portrait.Set_Label ("No portrait.");
      end if;
      if C.Has_Portrait then
         Open.Remove_Portrait.Activate;
      else
         Open.Remove_Portrait.Deactivate;
      end if;
      Open.Portrait.Redraw;
   end Show_Portrait;

   procedure Choose_Portrait_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      P : Unbounded_String;
   begin
      if Choose_Image (P) then
         --  Relative to the file once there is one; until then absolute,
         --  for the first save to make relative (Paths.Rebase).
         if File_Dir /= "" then
            P := To_Unbounded_String (Paths.Relative (To_String (P), To_String (File_Dir)));
         else
            P := To_Unbounded_String (Paths.Absolute (To_String (P)));
         end if;
         Character.Set_Text (The_Character.Has_Portrait, The_Character.Portrait, P);
         Show_Portrait;
         Report;
      end if;
   end Choose_Portrait_Action;

   procedure Remove_Portrait_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Character.Set_Text (The_Character.Has_Portrait, The_Character.Portrait, Null_Unbounded_String);
      Show_Portrait;
      Report;
   end Remove_Portrait_Action;

   function Dialog_Image (Path : out Unbounded_String) return Boolean is
      use FLTK.Native_File_Choosers;
      C : Native_File_Chooser := Forge.Create (Browse_File);
   begin
      Path := Null_Unbounded_String;
      C.Set_Title ("Choose the character's portrait");
      C.Add_Filter ("Images", "*.{png,jpg,jpeg,gif,bmp,svg}");
      if C.Show = Picked then
         Path := To_Unbounded_String (C.Get_Filename);
      end if;
      return Path /= "";
   end Dialog_Image;

   procedure Dialog_Tell (Text : String) is
   begin
      FLTK.Asks.Message_Box (Text);
   end Dialog_Tell;

   --  ---- The summary and the fluff ----

   procedure Summary_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if Filling then
         return;
      end if;
      Character.Set_Text (The_Character.Has_Summary, The_Character.Summary, Input_Text (Open.Summary_In.all));
      Report;
   end Summary_Action;

   procedure Fluff_Action (W : in out FLTK.Widgets.Widget'Class) is
      I : Fluff_Input'Class renames Fluff_Input'Class (W);
      C : Character.Character_Record'Class renames The_Character.all;
   begin
      if Filling then
         return;
      end if;
      Character.Set_Text (C.Has_Fluff_Field (I.Field), C.Fluff (I.Field), Input_Text (I));
      --  The fluff: block is written while any field has text.
      C.Has_Fluff := (for some F of C.Has_Fluff_Field => F);
      Report;
   end Fluff_Action;

   --  ---- The notes ----

   --  The notes' headers listed again, line Line selected (0: none).
   procedure Show_Notes (Line : Natural) is
      C : Character.Character_Record'Class renames The_Character.all;
   begin
      Open.Notes.Clear;
      for N of C.Notes loop
         Open.Notes.Add (To_String (N.Header));
      end loop;
      if Line in 1 .. Open.Notes.Number_Of_Lines then
         Open.Notes.Set_Select (Line => Line);
         Open.Note_Header.Set_Value (To_String (C.Notes (Line).Header));
         Open.Note_Text.Set_Value (To_String (C.Notes (Line).Text));
      else
         Open.Note_Header.Set_Value ("");
         Open.Note_Text.Set_Value ("");
      end if;
   end Show_Notes;

   procedure Notes_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Line : constant Natural := Open.Notes.Selected_Index;
      C    : Character.Character_Record'Class renames The_Character.all;
   begin
      if Line in 1 .. Natural (C.Notes.Length) then
         Open.Note_Header.Set_Value (To_String (C.Notes (Line).Header));
         Open.Note_Text.Set_Value (To_String (C.Notes (Line).Text));
      end if;
   end Notes_Action;

   --  The note typed; False, said why, if its header or text is blank:
   --  the loader requires both.
   function Note_Read (N : out Ova_Fmt.Entities.Note_Item) return Boolean is
   begin
      N := (Header => Input_Text (Open.Note_Header.all), Text => Input_Text (Open.Note_Text.all));
      if N.Header = "" or else N.Text = "" then
         Tell ("A note needs a header and some text.");
         return False;
      end if;
      return True;
   end Note_Read;

   --  Add puts the note last.
   procedure Add_Note_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      N : Ova_Fmt.Entities.Note_Item;
   begin
      if Note_Read (N) then
         The_Character.Notes.Append (N);
         Show_Notes (Natural (The_Character.Notes.Length));
         Report;
      end if;
   end Add_Note_Action;

   --  Change and Remove need a line selected.
   procedure Change_Note_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Line : constant Natural := Open.Notes.Selected_Index;
      N    : Ova_Fmt.Entities.Note_Item;
   begin
      if Line in 1 .. Natural (The_Character.Notes.Length) and then Note_Read (N) then
         The_Character.Notes.Replace_Element (Line, N);
         Show_Notes (Line);
         Report;
      end if;
   end Change_Note_Action;

   procedure Remove_Note_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Line : constant Natural := Open.Notes.Selected_Index;
   begin
      if Line in 1 .. Natural (The_Character.Notes.Length) then
         The_Character.Notes.Delete (Line);
         Show_Notes (0);
         Report;
      end if;
   end Remove_Note_Action;

   --  ---- Showing a character ----

   procedure Show (C : not null Character.Character_Access; Dir : String) is
   begin
      The_Character := C;
      File_Dir := To_Unbounded_String (Dir);
      Filling := True;
      Open.Summary_In.Set_Value (To_String (C.Summary));
      for S in Prose_Section loop
         Open.Buffers (S).Set_Entire_Text_Quietly (To_String (Prose_Of (S)));  --  no change to report
      end loop;
      for F in Character.Fluff_Field loop
         Open.Fluff_In (F).Set_Value (To_String (C.Fluff (F)));
      end loop;
      Show_Notes (0);
      Show_Portrait;
      Filling := False;
   end Show;

   procedure Set_Dir (Dir : String) is
   begin
      File_Dir := To_Unbounded_String (Dir);
      Show_Portrait;
   end Set_Dir;

   --  ---- Building ----

   procedure Heading (X, Y, W : Integer; Text : String) is
      B : constant Box_Access := new Boxes.Box'(Boxes.Forge.Create (X, Y, W, 20, Text));
   begin
      B.Set_Alignment (FLTK.Align_Left + FLTK.Align_Inside);
      B.Set_Label_Font (FLTK.Helvetica_Bold);
      Open.Heads := Open.Heads + 1;
      Open.Headings (Open.Heads) := B;
   end Heading;

   procedure Prose_Editor (Which : Prose_Section; Y, H : Integer; Title : String) is
      B : constant Buffer_Access := new Buffers.Text_Buffer'(Buffers.Forge.Create);
      E : Editor_Access;
   begin
      Heading (Left_X, Y, Column_W, Title);
      E := new Editors.Text_Editor'(Editors.Forge.Create (Left_X, Y + 20, Column_W, H));
      B.Add_Modify_Details_Callback (Modified (Which));
      E.Set_Buffer (Buffers.Text_Buffer (B.all));
      E.Set_Wrap_Mode (Displays.Bounds, 0);
      Open.Prose (Which) := E;
      Open.Buffers (Which) := B;
   end Prose_Editor;

   procedure Fluff_Field (Field : Character.Fluff_Field; Row, Col : Positive; Label : String) is
      B : constant Box_Access := new Boxes.Box'(Boxes.Forge.Create (0, 0, 0, 0, Label));
      I : constant Widgets.Input_Access :=
        new Fluff_Input'(Texts.Forge.Create (0, 0, 0, 0, "") with Field => Field);
   begin
      B.Set_Alignment (FLTK.Align_Right + FLTK.Align_Inside);
      Open.Fluff_Grid.Set_Widget (B.all, Row, 2 * Col - 1);
      I.Set_When (FLTK.When_Changed);
      I.Set_Callback (Fluff_Action'Access);
      Open.Fluff_Grid.Set_Widget (I.all, Row, 2 * Col);
      Open.Fluff_Labels (Field) := B;
      Open.Fluff_In (Field) := I;
   end Fluff_Field;

   procedure Build (X, Y, W, H : Integer) is
      use Character;
      Top : constant := 10;
      YY  : Integer;
      PH  : Integer;

      function Button (X, W : Integer; Label : String; Action : FLTK.Widgets.Widget_Callback)
        return Widgets.Button_Access is
         B : constant Widgets.Button_Access :=
           new Widgets.Buttons.Button'(Widgets.Buttons.Forge.Create (X, YY, W, Row, Label));
      begin
         B.Set_Callback (Action);
         return B;
      end Button;

   begin
      Shared.Register_Images;
      Open.Background_Tab := new Widgets.Groups.Group'(Widgets.Groups.Forge.Create (X, Y, W, H, "Background"));
      Open.Background_Tab.Begin_Current;
      --  The summary and the five prose sections.
      YY := Y + Top;
      Open.Summary_In := new Texts.Text_Input'
        (Texts.Forge.Create (Left_X + 80, YY, Column_W - 80, Row, "Summary"));
      Open.Summary_In.Set_When (FLTK.When_Changed);
      Open.Summary_In.Set_Callback (Summary_Action'Access);
      YY := YY + Row + 10;
      PH := (Y + H - 10 - YY) / (Prose_Section'Pos (Prose_Section'Last) + 1) - 25;
      Prose_Editor (Background_Section, YY, PH, "Background");
      YY := YY + PH + 25;
      Prose_Editor (Appearance_Section, YY, PH, "Appearance");
      YY := YY + PH + 25;
      Prose_Editor (Personality_Section, YY, PH, "Personality");
      YY := YY + PH + 25;
      Prose_Editor (Character_Hooks_Section, YY, PH, "Character Hooks");
      YY := YY + PH + 25;
      Prose_Editor (Other_Notes_Section, YY, PH, "Other Notes");
      Open.Background_Tab.End_Current;

      --  The portrait, the fluff, the notes.
      Open.Fluff_Tab := new Widgets.Groups.Group'(Widgets.Groups.Forge.Create (X, Y, W, H, "Fluff"));
      Open.Fluff_Tab.Begin_Current;
      YY := Y + Top;
      Heading (Left_X, YY, Portrait_W, "Character Portrait");
      Open.Portrait := new Boxes.Box'
        (Boxes.Forge.Create (FLTK.Down_Frame, Left_X, YY + 20, Portrait_W, Portrait_H, ""));
      Open.Portrait.Set_Alignment (FLTK.Align_Inside + FLTK.Align_Wrap);
      Open.Portrait.Set_Image_Fit (True, Expand => False);
      Open.Portrait_Path := new Widgets.Outputs.Output'
        (Widgets.Outputs.Forge.Create (Left_X + Portrait_W + 10, YY + 40, Column_W - Portrait_W - 10, Row,
                                       "Image file, relative to the character's"));
      Open.Portrait_Path.Set_Alignment (FLTK.Align_Top_Left);
      YY := YY + 75;
      Open.Choose_Portrait := Button (Left_X + Portrait_W + 10, 100, "Choose...", Choose_Portrait_Action'Access);
      Open.Remove_Portrait := Button (Left_X + Portrait_W + 115, 80, "Remove", Remove_Portrait_Action'Access);

      YY := YY - 75 + 20 + Portrait_H + 10;
      Open.Fluff_Grid := new Grids.Grid'(Grids.Forge.Create (Left_X, YY, Column_W, Fluff_Rows * (Row + 5)));
      Open.Fluff_Grid.Set_Layout (Fluff_Rows, 4);
      Open.Fluff_Grid.Set_Gap (5, 5);
      Open.Fluff_Grid.Set_Column_Weight (1, 0);
      Open.Fluff_Grid.Set_Column_Width (1, 100);
      Open.Fluff_Grid.Set_Column_Weight (3, 0);
      Open.Fluff_Grid.Set_Column_Width (3, 100);
      Open.Fluff_Grid.Begin_Current;
      Fluff_Field (Concept, 1, 1, "Concept");
      Fluff_Field (Birthday, 1, 2, "Birthday");
      Fluff_Field (Age, 2, 1, "Age");
      Fluff_Field (Gender, 2, 2, "Gender");
      Fluff_Field (Height, 3, 1, "Height");
      Fluff_Field (Weight, 3, 2, "Weight");
      Fluff_Field (Hair, 4, 1, "Hair");
      Fluff_Field (Eyes, 4, 2, "Eyes");
      Fluff_Field (Association, 5, 1, "Association");
      Fluff_Field (Hobbies, 5, 2, "Hobbies");
      Fluff_Field (Favorite_Food, 6, 1, "Favorite Food");
      Fluff_Field (Allies, 6, 2, "Allies");
      Fluff_Field (Enemies, 7, 1, "Enemies");
      Fluff_Field (Love_Interests, 7, 2, "Love Interests");
      Open.Fluff_Grid.End_Current;
      pragma Assert (for all I of Open.Fluff_In => I /= null);

      YY := YY + Fluff_Rows * (Row + 5) + 10;
      Heading (Left_X, YY, Column_W, "Notes");
      Open.Notes := new Widgets.Hold.Hold_Browser'
        (Widgets.Hold.Forge.Create (Left_X, YY + 20, 200, Y + H - 10 - Row - 5 - YY - 20));
      Open.Notes.Set_Format_Character (Standard.Character'Val (0));  --  headers are text, never format codes
      Open.Notes.Set_Callback (Notes_Action'Access);
      Open.Note_Header := new Texts.Text_Input'
        (Texts.Forge.Create (Left_X + 270, YY + 20, Column_W - 270, Row, "Header"));
      Open.Note_Text := new Multiline.Multiline_Input'
        (Multiline.Forge.Create (Left_X + 270, YY + 50, Column_W - 270, Y + H - 10 - (YY + 50), "Text"));
      Open.Note_Text.Set_Wrap (True);
      Open.Note_Text.Set_Alignment (FLTK.Align_Left_Top);
      YY := Y + H - 10 - Row;
      Open.Add_Note := Button (Left_X, 65, "Add", Add_Note_Action'Access);
      Open.Change_Note := Button (Left_X + 68, 65, "Change", Change_Note_Action'Access);
      Open.Remove_Note := Button (Left_X + 136, 65, "Remove", Remove_Note_Action'Access);
      Open.Fluff_Tab.End_Current;
   end Build;

   procedure Close is
      procedure Free_Group is new Ada.Unchecked_Deallocation (Widgets.Groups.Group'Class, Group_Access);
      procedure Free_Box is new Ada.Unchecked_Deallocation (Boxes.Box'Class, Box_Access);
      procedure Free_Grid is new Ada.Unchecked_Deallocation (Grids.Grid'Class, Grid_Access);
      procedure Free_Editor is new Ada.Unchecked_Deallocation (Editors.Text_Editor'Class, Editor_Access);
      procedure Free_Buffer is new Ada.Unchecked_Deallocation (Buffers.Text_Buffer'Class, Buffer_Access);
      procedure Free_Input is new Ada.Unchecked_Deallocation (Texts.Text_Input'Class, Widgets.Input_Access);
      procedure Free_Output is
        new Ada.Unchecked_Deallocation (Widgets.Outputs.Output'Class, Widgets.Output_Access);
      procedure Free_Multiline is
        new Ada.Unchecked_Deallocation (Multiline.Multiline_Input'Class, Multiline_Access);
      procedure Free_Browser is
        new Ada.Unchecked_Deallocation (Widgets.Hold.Hold_Browser'Class, Widgets.Browser_Access);
      procedure Free_Button is
        new Ada.Unchecked_Deallocation (Widgets.Buttons.Button'Class, Widgets.Button_Access);
   begin
      --  The editors before their buffers; every child before its group.
      Free_Input (Open.Summary_In);
      for S in Prose_Section loop
         Free_Editor (Open.Prose (S));
         Free_Buffer (Open.Buffers (S));
      end loop;
      for B of Open.Headings loop
         Free_Box (B);
      end loop;
      Free_Box (Open.Portrait);
      Free_Image (Open.Image);
      Free_Output (Open.Portrait_Path);
      Free_Button (Open.Choose_Portrait);
      Free_Button (Open.Remove_Portrait);
      for F in Character.Fluff_Field loop
         Free_Box (Open.Fluff_Labels (F));
         Free_Input (Open.Fluff_In (F));
      end loop;
      Free_Grid (Open.Fluff_Grid);
      Free_Browser (Open.Notes);
      Free_Input (Open.Note_Header);
      Free_Multiline (Open.Note_Text);
      Free_Button (Open.Add_Note);
      Free_Button (Open.Change_Note);
      Free_Button (Open.Remove_Note);
      Free_Group (Open.Background_Tab);
      Free_Group (Open.Fluff_Tab);
      Open := (others => <>);
      The_Character := null;
      File_Dir := Null_Unbounded_String;
   end Close;

begin
   Tell := Dialog_Tell'Access;
   Choose_Image := Dialog_Image'Access;
end Ova_Cg.Background;
