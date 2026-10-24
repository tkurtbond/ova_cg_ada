--  Ova_Cg.Markdown_Tab: the character's Markdown sheet, kept current,
--  copied and saved.
--
--  Needs a display: run by make test-gui, as test_window is.  The tab
--  shows Ova_Cg.Markdown's sheet of the character shown, after every
--  kind of change (a name typed, an Ability added, Background text
--  typed, a file opened); Copy puts it on the clipboard, read back by
--  pasting it into an input of this test's own; Save Markdown... writes
--  it where the chooser says, suggesting the character's name, and says
--  why when it can't.  Inline, checked, shows the inline paragraph
--  instead, kept current the same way, and Save Markdown... takes it.
--  That the sheet is ova_fmt -M's, and the paragraph -i's, is
--  test/files.sh's.

with Ada.Directories;
with Ada.Direct_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Check;
with FLTK.Menu_Items;
with FLTK.Static;
with FLTK.Widgets.Groups.Windows;
with FLTK.Widgets.Inputs.Text.Multiline;
with Ova_Cg.Background;
with Ova_Cg.Markdown;
with Ova_Cg.Markdown_Tab;
with Ova_Cg.Rules;
with Ova_Cg.Trait_Panel;
with Ova_Cg.Widgets;
with Ova_Cg.Window;

procedure Test_Markdown is

   use Ova_Cg;
   use type Rules.Item, Window.Window_Access, Window.Tabs_Access;
   use type Ova_Cg.Markdown_Tab.Group_Access, Ova_Cg.Markdown_Tab.Display_Access;

   package Tab renames Ova_Cg.Markdown_Tab;
   package Windows renames FLTK.Widgets.Groups.Windows;
   package Multiline renames FLTK.Widgets.Inputs.Text.Multiline;

   Save_Path : constant String := "../obj/files/markdown-tab.md";
   Bad_Path  : constant String := "../obj/no/such/dir/markdown-tab.md";

   Tells, Asks : Natural := 0;
   Chosen      : Unbounded_String;  --  the chooser's answer; Null: cancelled
   Cancelled   : Boolean := True;
   Suggested   : Unbounded_String;
   Back        : Unbounded_String;
   OK          : Boolean;

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

   function Choose_Path (Suggest : String; P : out Unbounded_String) return Boolean is
   begin
      Asks := Asks + 1;
      Suggested := To_Unbounded_String (Suggest);
      P := Chosen;
      return not Cancelled;
   end Choose_Path;

   --  ---- Looking ----

   function Has (S : String; Part : String) return Boolean is
     (Ada.Strings.Fixed.Index (S, Part) > 0);

   --  The file at Path, in Text; False if it can't be read.
   function Read_File (Path : String; Text : out Unbounded_String) return Boolean is
   begin
      Text := Null_Unbounded_String;
      if not Ada.Directories.Exists (Path) then
         return False;
      end if;
      declare
         Size : constant Natural := Natural (Ada.Directories.Size (Path));
         subtype Contents is String (1 .. Size);
         package IO is new Ada.Direct_IO (Contents);
         F : IO.File_Type;
         S : Contents;
      begin
         if Size = 0 then
            return True;
         end if;
         IO.Open (F, IO.In_File, Path);
         IO.Read (F, S);
         IO.Close (F);
         Text := To_Unbounded_String (S);
         return True;
      end;
   end Read_File;

   --  Whether the tab shows the sheet of the character shown, or its
   --  inline paragraph if Inline is checked, as Ova_Cg.Markdown makes
   --  it, in its display.
   function Shown return Boolean is
      Want : Unbounded_String;
      Made : Boolean;
   begin
      if Tab.Inline.Is_On then
         Made := Markdown.Inline (Window.The_Character, Want);
      else
         Made := Markdown.Sheet (Window.The_Character, Want);
      end if;
      return Made and then Tab.Sheet = To_String (Want)
        and then Tab.Display.Get_Buffer.Get_Entire_Text = To_String (Want);
   end Shown;

   --  ---- Doing ----

   procedure Pick (P : Trait_Panel.Trait_Panel_Access; Name : String) is
      It : constant Rules.Item := Rules.Find (Name);
   begin
      pragma Assert (It /= null);
      Widgets.Choose (P.all, It);
      P.Choice.Do_Callback;
   end Pick;

   procedure Add_Ability (Name : String; Level : Integer) is
      P : constant Trait_Panel.Trait_Panel_Access := Window.Abilities;
   begin
      Pick (P, Name);
      P.Spinner.Set_Value (Long_Float (Level));
      P.Text.Set_Value ("");
      P.Add_Button.Do_Callback;
   end Add_Ability;

   --  Checks or unchecks Inline, as a click does.
   procedure Set_Inline (On : Boolean) is
   begin
      Tab.Inline.Set_State (if On then Widgets.Buttons.On else Widgets.Buttons.Off);
      Tab.Inline.Do_Callback;
   end Set_Inline;

   --  Deletes the file at P, if there is one.
   procedure Remove (P : String) is
   begin
      if Ada.Directories.Exists (P) then
         Ada.Directories.Delete_File (P);
      end if;
   end Remove;

   procedure Choose (P : String) is
   begin
      Chosen := To_Unbounded_String (P);
      Cancelled := False;
   end Choose;

   procedure Cancel is
   begin
      Chosen := Null_Unbounded_String;
      Cancelled := True;
   end Cancel;

   --  Copy, read back by pasting into an input in a window of its own.
   procedure Check_Copy is
      type Window_Access is access all Windows.Window'Class;
      type Input_Access is access all Multiline.Multiline_Input'Class;
      procedure Free is new Ada.Unchecked_Deallocation (Windows.Window'Class, Window_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Multiline.Multiline_Input'Class, Input_Access);
      Win : Window_Access := new Windows.Window'(Windows.Forge.Create (100, 100, "test_markdown"));
      In_Box : Input_Access;
   begin
      Tab.Copy.Do_Callback;
      In_Box := new Multiline.Multiline_Input'(Multiline.Forge.Create (Win.all, 0, 0, 100, 100, ""));
      FLTK.Static.Paste (In_Box.all, FLTK.Static.Clipboard);
      Check.Check (Tab.Sheet = In_Box.Get_Value, "Copy: the whole sheet on the clipboard");
      Free (In_Box);
      Free (Win);
   end Check_Copy;

begin
   Window.Build;
   Window.Tell := Tell'Unrestricted_Access;
   Window.Ask := Ask'Unrestricted_Access;
   Tab.Tell := Tell'Unrestricted_Access;
   Tab.Choose_Path := Choose_Path'Unrestricted_Access;
   Window.Tabs.Set_Visible (Tab.Tab.all);
   Check.Check (Tab.Tab.Get_Label = "Markdown" and then Tab.Display.Is_Visible, "the Markdown tab");
   Check.Check (Shown, "a new character's sheet");

   --  ---- Kept current ----
   Window.Name_In.Set_Value ("Kiri");
   Window.Name_In.Do_Callback;
   Check.Check (Shown and then Has (Tab.Sheet, "# Kiri"), "a name typed: the sheet's title");
   Add_Ability ("Attack", 3);
   Check.Check (Shown and then Has (Tab.Sheet, "Attack +3"), "an Ability added: listed");
   Background.Prose (Background.Background_Section).Get_Buffer.Append_Text ("Kiri grew up by the sea.");
   Check.Check (Shown and then Has (Tab.Sheet, "Kiri grew up by the sea."), "Background typed: in the sheet");
   OK := Window.Load ("data/Ai.yaml");
   Check.Check (OK and then not Window.Modified and then Shown
                and then Has (Tab.Sheet, "# Ai (Amnesiatic ESPer)"),
                "a file opened: its character's sheet");

   --  ---- Copy ----
   Check_Copy;

   --  ---- Save Markdown... ----
   Remove (Save_Path);
   Choose (Save_Path);
   Tab.Save.Do_Callback;
   Check.Check (Asks = 1 and then Suggested = "Ai.md", "Save Markdown...: the character's name suggested");
   Check.Check (Read_File (Save_Path, Back) and then Back = Tab.Sheet and then Tells = 0
                and then not Window.Modified,
                "the sheet written where chosen, the character not marked changed");
   Remove (Save_Path);
   Cancel;
   Tab.Save.Do_Callback;
   Check.Check (Asks = 2 and then not Read_File (Save_Path, Back) and then Tells = 0,
                "cancelled: nothing written, nothing said");
   Choose (Bad_Path);
   Tab.Save.Do_Callback;
   Check.Check (Tells = 1, "a file that can't be written: said why");
   Window.Bar.Picked (FLTK.Menu_Items.Menu_Item (Window.Bar.Item (Window.New_Item).Data.all));
   Choose (Save_Path);
   Tab.Save.Do_Callback;
   Check.Check (Suggested = "" and then Read_File (Save_Path, Back) and then Back = Tab.Sheet,
                "a character with no name: nothing suggested, the sheet saved");

   --  ---- Inline ----
   OK := Window.Load ("data/Ai.yaml");
   Check.Check (OK and then not Tab.Inline.Is_On and then Shown, "Inline starts unchecked: the sheet");
   Set_Inline (True);
   Check.Check (Shown and then Has (Tab.Sheet, "**Ai.** An amnesiac") and then not Has (Tab.Sheet, "# Ai"),
                "Inline checked: the inline paragraph");
   Window.Name_In.Set_Value ("Aiko");
   Window.Name_In.Do_Callback;
   Check.Check (Shown and then Has (Tab.Sheet, "**Aiko.**"), "Inline: kept current");
   Remove (Save_Path);
   Choose (Save_Path);
   Tab.Save.Do_Callback;
   Check.Check (Suggested = "Aiko-inline.md" and then Read_File (Save_Path, Back)
                and then Back = Tab.Sheet,
                "Inline: Save Markdown... suggests NAME-inline.md, saves the paragraph");
   Remove (Save_Path);
   Set_Inline (False);
   Check.Check (Shown and then Has (Tab.Sheet, "# Aiko"), "Inline unchecked: the sheet again");

   Window.Close;
   --  fltkada keeps no count of the widgets open, as pofltk's
   --  OpenWidgets is: the window's and the tab's are all forgotten, and
   --  valgrind-headless finds none of them leaked (PLAN.md, "Findings").
   Check.Check (Window.Main = null and then Window.Tabs = null and then Tab.Tab = null
                and then Tab.Display = null, "every widget is deleted");
   Check.Summary;
end Test_Markdown;
