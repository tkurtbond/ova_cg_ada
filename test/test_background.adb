--  Ova_Cg.Background: the Background and Fluff tabs, driven as a user
--  would, and what they save.
--
--  Needs a display: run by make test-gui, as test_window is.  The text,
--  the fluff, the notes and the portrait shown from a character, each
--  change made as the user makes it (text typed into an editor's
--  buffer, an input's value set and its callback run, a button pushed),
--  and checked in the model, in the window's title, and in what is
--  saved.  The portrait is an image this test writes, saved as a path
--  relative to the YAML file, and rebased when Save As moves the file.

with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Check;
with FLTK;
with FLTK.Menu_Items;
with Ova_Cg.Background;
with Ova_Cg.Character;
with Ova_Cg.Paths;
with Ova_Cg.Save;
with Ova_Cg.Widgets;
with Ova_Cg.Window;
with System;

procedure Test_Background is

   use Ova_Cg;
   use type Background.Image_Access, Background.Group_Access, Window.Window_Access,
     Window.Tabs_Access, System.Address;

   package Ch renames Ova_Cg.Character;
   package B renames Ova_Cg.Background;

   --  fltkada writes no PNG, so the portrait is a PPM, as test_resize's
   --  (PLAN.md, "Findings").
   Image_Path : constant String := "../obj/face.ppm";       --  written here
   Save_Path  : constant String := "../obj/files/bg.yaml";  --  beside it, in obj/files
   Bad_Path   : constant String := "../obj/no/such/dir/bg.yaml";
   Image_W    : constant := 40;
   Image_H    : constant := 60;

   Tells        : Natural := 0;
   Chosen_Image : Unbounded_String;  --  Null: cancelled
   Chosen_Path  : Unbounded_String;
   C            : Ch.Character_Access;
   Text         : Unbounded_String;
   N            : Natural;
   OK           : Boolean;

   --  ---- What would wait for the user ----

   procedure Tell (Text : String) is
   begin
      Tells := Tells + 1;
      Ada.Text_IO.Put_Line ("    told: " & Text);
   end Tell;

   function Ask (Question : String) return Window.Answer is
      pragma Unreferenced (Question);
   begin
      return Window.Discard;
   end Ask;

   function Choose_Path (Save : Boolean; P : out Unbounded_String) return Boolean is
      pragma Unreferenced (Save);
   begin
      P := Chosen_Path;
      return P /= Null_Unbounded_String;
   end Choose_Path;

   function Choose_Image (P : out Unbounded_String) return Boolean is
   begin
      P := Chosen_Image;
      return P /= Null_Unbounded_String;
   end Choose_Image;

   --  ---- Looking ----

   function Saved return String is (Save.To_Text (Window.The_Character));

   function Has (S : String; Part : String) return Boolean is
     (Ada.Strings.Fixed.Index (S, Part) > 0);

   --  Whether section Which's text, trimmed as the tab trims it, is R.
   function Prose_Is (Which : B.Prose_Section; R : Unbounded_String) return Boolean is
     (Ch.Trim (B.Prose (Which).Get_Buffer.Data.Get_Entire_Text) = To_String (R));

   --  Whether input I's text, trimmed as the tab trims it, is R.
   function Input_Is (I : Widgets.Input_Access; R : Unbounded_String) return Boolean is
     (Ch.Trim (I.Get_Value) = To_String (R));

   function Output_Is (O : Widgets.Output_Access; R : Unbounded_String) return Boolean is
     (Ch.Trim (O.Get_Value) = To_String (R));

   --  Types S at the end of section Which, as the user does.
   procedure Append (Which : B.Prose_Section; S : String) is
   begin
      B.Prose (Which).Get_Buffer.Data.Append_Text (S);
   end Append;

   --  Replaces section Which's text with S.
   procedure Set_Prose (Which : B.Prose_Section; S : String) is
   begin
      B.Prose (Which).Get_Buffer.Data.Set_Entire_Text (S);
   end Set_Prose;

   --  Whether every field of the tabs shows the character's text.
   function All_Shown return Boolean is
      C  : constant Ch.Character_Access := Window.The_Character;
      OK : Boolean :=
        Input_Is (B.Summary_In, C.Summary)
        and then Prose_Is (B.Background_Section, C.Background)
        and then Prose_Is (B.Appearance_Section, C.Appearance)
        and then Prose_Is (B.Personality_Section, C.Personality)
        and then Prose_Is (B.Character_Hooks_Section, C.Character_Hooks)
        and then Prose_Is (B.Other_Notes_Section, C.Other_Notes)
        and then Output_Is (B.Portrait_Path, C.Portrait);
   begin
      for F in Ch.Fluff_Field loop
         OK := OK and then Input_Is (B.Fluff_In (F), C.Fluff (F));
      end loop;
      return OK;
   end All_Shown;

   --  Whether the notes' browser lists the character's notes' headers.
   function Notes_Shown return Boolean is
      C : constant Ch.Character_Access := Window.The_Character;
      I : Natural := 0;
   begin
      for Note of C.Notes loop
         I := I + 1;
         if I > B.Notes.Number_Of_Lines or else B.Notes.Get_Line_Text (I) /= To_String (Note.Header) then
            return False;
         end if;
      end loop;
      return I = B.Notes.Number_Of_Lines;
   end Notes_Shown;

   function Note_Count return Natural is (Natural (Window.The_Character.Notes.Length));

   --  Whether the portrait box shows an image, which FLTK fits to it as it
   --  draws, shrinking it but not growing it.
   function Image_Shown return Boolean is
      Img : constant B.Image_Access := B.Portrait_Image;
   begin
      return Img /= null and then Img.Get_W > 0 and then B.Portrait.Get_Image /= null
        and then B.Portrait.Is_Image_Fitted
        and then not B.Portrait.Is_Image_Expanding;
   end Image_Shown;

   function Portrait_Says (S : String) return Boolean is (B.Portrait.Get_Label = S);

   function Title return String is (Window.Main.Get_Label);

   function Modified return Boolean is
     (Window.Modified and then Title'Length > 2 and then Title (Title'Last) = '*');

   function First_Header return String is
     (To_String (Window.The_Character.Notes.First_Element.Header));

   --  ---- Driving ----

   function Load (Name : String) return Boolean is (Window.Load ("data/" & Name));

   --  Types S into input I, as the user does: its callback runs.
   procedure Type_In (I : Widgets.Input_Access; S : String) is
   begin
      I.Set_Value (S);
      I.Do_Callback;
   end Type_In;

   procedure Pick_Item (Item : Window.Item_Index) is
   begin
      Window.Bar.Picked (FLTK.Menu_Items.Menu_Item (Window.Bar.Item (Item).Data.all));
   end Pick_Item;

   procedure Select_Note (Line : Positive) is
   begin
      B.Notes.Set_Select (Line);
      B.Notes.Do_Callback;
   end Select_Note;

   --  An image to choose: a gradient, Image_W by Image_H, as a binary
   --  PPM.
   function Write_Image return Boolean is
      use Ada.Streams.Stream_IO;
      F : File_Type;
      S : Stream_Access;
   begin
      Create (F, Out_File, Image_Path);
      S := Stream (F);
      String'Write (S, "P6" & ASCII.LF & "40 60" & ASCII.LF & "255" & ASCII.LF);
      for I in 0 .. Image_W * Image_H * 3 - 1 loop
         Standard.Character'Write (S, Standard.Character'Val (I mod 251));
      end loop;
      Close (F);
      return Natural (Ada.Directories.Size (Image_Path)) > Image_W * Image_H * 3;
   end Write_Image;

begin
   Window.Build;
   Window.Tell := Tell'Unrestricted_Access;
   Window.Ask := Ask'Unrestricted_Access;
   Window.Choose_Path := Choose_Path'Unrestricted_Access;
   B.Choose_Image := Choose_Image'Unrestricted_Access;

   Check.Check (Write_Image, "an image written to choose");

   Check.Check (Window.Tabs.Get_Visible.all'Address = Window.Sheet_Tab.all'Address, "the Character tab first");
   Window.Tabs.Set_Visible (B.Background_Tab.all);
   Window.Main.Show;
   Window.Main.Wait_For_Expose;
   OK := FLTK.Check;
   Check.Check (B.Prose (B.Background_Section).Is_Visible, "the Background tab, shown");
   Check.Check (All_Shown and then Notes_Shown and then Portrait_Says ("No portrait.")
                and then B.Portrait_Image = null and then not B.Remove_Portrait.Is_Active,
                "a new character: every field empty, no portrait");

   --  ---- Shown from a file ----
   OK := Load ("Sheet.yaml");
   C := Window.The_Character;
   Check.Check (OK and then All_Shown,
                "Sheet.yaml: the summary, the prose sections, the fluff and the portrait's path shown");
   Check.Check (C.Has_Background and then C.Has_Appearance and then C.Has_Personality and then C.Has_Other_Notes
                and then C.Has_Summary and then C.Has_Fluff_Field (Ch.Concept),
                "and it has each");
   Check.Check (Output_Is (B.Portrait_Path, To_Unbounded_String ("images/hana.png")) and then B.Portrait_Image = null
                and then Portrait_Says ("The image can't be read.") and then B.Remove_Portrait.Is_Active,
                "its portrait, not there: the path, and why there's no image");
   OK := Load ("Jiro.yaml");
   Check.Check (OK and then All_Shown and then Window.The_Character.Has_Character_Hooks,
                "Jiro.yaml: his Character Hooks shown");
   OK := Load ("Raine.yaml");
   Check.Check (OK and then Note_Count > 0 and then Notes_Shown, "Raine.yaml: the notes' headers listed");
   Check.Check (B.Notes.Get_Line_Text (1) = "Nightmares", "the first, Nightmares");
   Select_Note (1);
   C := Window.The_Character;
   Check.Check (Input_Is (B.Note_Header, C.Notes (1).Header)
                and then Ch.Trim (B.Note_Text.Get_Value) = To_String (C.Notes (1).Text),
                "a note selected: its header and text to edit");

   --  ---- Text typed ----
   OK := Load ("Sheet.yaml");
   C := Window.The_Character;
   Check.Check (not Window.Modified, "loaded: nothing changed");
   Append (B.Appearance_Section, " She hums.");
   Check.Check (Has (To_String (C.Appearance), "coat that never stops moving. She hums.") and then Modified,
                "typing in Appearance: the character's, and the title marked");
   Check.Check (Has (Saved, "She hums."), "and saved");
   B.Prose (B.Appearance_Section).Get_Buffer.Data.Insert_Text (0, "  ");
   Check.Check (Element (C.Appearance, 1) = 'S', "blanks at the ends are trimmed, as the loader trims them");
   Set_Prose (B.Appearance_Section, "   ");
   Check.Check (not C.Has_Appearance and then C.Appearance = Null_Unbounded_String
                and then not Has (Saved, "appearance:"),
                "emptied: not saved");
   Set_Prose (B.Other_Notes_Section, "Owes two favors now.");
   Check.Check (Has (Saved, "other-notes: Owes two favors now."), "Other Notes saved");
   Set_Prose (B.Character_Hooks_Section, "Needs a courier.");
   Check.Check (C.Has_Character_Hooks and then Has (Saved, "character-hooks: Needs a courier."),
                "Character Hooks saved");
   Type_In (B.Summary_In, "A schoolgirl and a storm.");
   Check.Check (C.Summary = "A schoolgirl and a storm." and then Has (Saved, "summary: A schoolgirl and a storm."),
                "the summary typed and saved");

   --  ---- The fluff ----
   Type_In (B.Fluff_In (Ch.Hair), "Black");
   Check.Check (C.Has_Fluff_Field (Ch.Hair) and then Has (Saved, "hair: Black"), "Hair typed: saved in fluff:");
   Type_In (B.Fluff_In (Ch.Favorite_Food), "Melon bread");
   Check.Check (Has (Saved, "favorite-food: Melon bread"), "Favorite Food: its key, favorite-food");
   for F in Ch.Fluff_Field loop
      Type_In (B.Fluff_In (F), " ");
   end loop;
   Check.Check (not C.Has_Fluff and then not Has (Saved, "fluff:"), "every field emptied: no fluff: block");
   Type_In (B.Fluff_In (Ch.Age), "15");
   Check.Check (C.Has_Fluff and then Has (Saved, "fluff:") and then Has (Saved, "age: 15"),
                "one field again: the block again");
   Check.Check (All_Shown, "and every field still shows the character's");

   --  ---- The notes ----
   Tells := 0;
   B.Note_Header.Set_Value ("Rivals");
   B.Note_Text.Set_Value ("");
   B.Add_Note.Do_Callback;
   Check.Check (Tells = 1 and then Note_Count = 0, "a note with no text: said so, not added");
   B.Note_Text.Set_Value ("The track team's captain.");
   B.Add_Note.Do_Callback;
   B.Note_Header.Set_Value ("Secrets");
   B.Note_Text.Set_Value ("Nobody knows about the Gale.");
   B.Add_Note.Do_Callback;
   Check.Check (Note_Count = 2 and then Notes_Shown and then B.Notes.Selected_Index = 2,
                "two added, in order, the last selected");
   Text := To_Unbounded_String (Saved);
   Check.Check (Has (To_String (Text), "header: Rivals") and then Has (To_String (Text), "The track team's captain.")
                and then Has (To_String (Text), "header: Secrets"),
                "and saved");
   Select_Note (1);
   B.Note_Header.Set_Value ("Rival");
   B.Change_Note.Do_Callback;
   Check.Check (First_Header = "Rival" and then Notes_Shown and then B.Notes.Selected_Index = 1,
                "Change: the header changed, in its place");
   B.Remove_Note.Do_Callback;
   Check.Check (Note_Count = 1 and then First_Header = "Secrets" and then Notes_Shown, "Remove");
   N := Note_Count;
   B.Remove_Note.Do_Callback;
   Check.Check (Note_Count = N, "Remove with nothing selected removes nothing");

   --  ---- The portrait ----
   --  Sheet.yaml is in test/data; the image in obj.
   Chosen_Image := To_Unbounded_String (Paths.Absolute (Image_Path));
   B.Choose_Portrait.Do_Callback;
   Check.Check (C.Portrait = "../../obj/face.ppm" and then All_Shown,
                "an image chosen: its path relative to the character's file");
   Check.Check (Image_Shown and then Portrait_Says ("") and then B.Remove_Portrait.Is_Active,
                "and shown, scaled to the box");
   Check.Check (Has (Saved, "portrait: ""../../obj/face.ppm"""),
                "and saved so (quoted, as OvaSave quotes text starting with .)");
   Tells := 0;
   Chosen_Path := To_Unbounded_String (Bad_Path);
   Pick_Item (Window.Save_As_Item);
   Check.Check (Tells = 1 and then C.Portrait = "../../obj/face.ppm"
                and then Title = "OVA Character Generator - Sheet.yaml *",
                "a save that fails: said so, the path as it was");
   Chosen_Path := To_Unbounded_String (Save_Path);
   Pick_Item (Window.Save_As_Item);
   Check.Check (C.Portrait = "../face.ppm" and then Title = "OVA Character Generator - bg.yaml"
                and then Image_Shown and then All_Shown,
                "Save As to obj/files: the path rebased, the image still shown");
   Text := To_Unbounded_String (Saved);
   OK := Window.Load (To_String (Chosen_Path));
   C := Window.The_Character;
   Check.Check (OK and then Tells = 1 and then C.Portrait = "../face.ppm" and then Image_Shown and then All_Shown
                and then Notes_Shown,
                "loaded again: the portrait found from the file's directory");
   Check.Check (Saved = To_String (Text), "and everything the tab set, the same");
   Chosen_Image := Null_Unbounded_String;
   B.Choose_Portrait.Do_Callback;
   Check.Check (C.Portrait = "../face.ppm" and then not Window.Modified, "the chooser cancelled: nothing changes");
   B.Remove_Portrait.Do_Callback;
   Check.Check (not C.Has_Portrait and then not Has (Saved, "portrait:") and then Portrait_Says ("No portrait.")
                and then B.Portrait_Image = null and then not B.Remove_Portrait.Is_Active and then Modified,
                "Remove: no portrait");

   --  A character never saved holds the absolute path, until its first
   --  save.
   Pick_Item (Window.New_Item);
   C := Window.The_Character;
   Check.Check (All_Shown and then Notes_Shown and then B.Portrait_Image = null, "New: every field empty again");
   Chosen_Image := To_Unbounded_String (Image_Path);
   B.Choose_Portrait.Do_Callback;
   Check.Check (C.Portrait = Paths.Absolute (Image_Path) and then Image_Shown,
                "no file yet: the image's absolute path");
   Window.Name_In.Set_Value ("Someone");
   Window.Name_In.Do_Callback;
   Pick_Item (Window.Save_Item);
   Check.Check (C.Portrait = "../face.ppm" and then not Window.Modified and then Image_Shown,
                "the first save: made relative");

   Window.Close;
   if Ada.Directories.Exists (Image_Path) then
      Ada.Directories.Delete_File (Image_Path);
   end if;
   --  As test_markdown's: fltkada keeps no count of the widgets open.
   Check.Check (Window.Main = null and then Window.Tabs = null and then B.Background_Tab = null
                and then B.Fluff_Tab = null,
                "every widget is deleted");
   Check.Summary;
end Test_Background;
