--  The main window: its menu bar, the sheet's first two tabs, and the
--  file's characters.
--
--  ova_cg_po's PLAN.md, "The window".  One window, narrow enough to sit
--  beside the rulebook's viewer, a menu bar, and five tabs, each a
--  column: the first two the sheet's right half, "Character" (the
--  names, the Abilities and Weaknesses, the totals and warnings, the
--  Combat Notes) and "Attacks" (the combat box and the sheet's
--  numbers), with a box beside every computed number for its override;
--  then "Background" and "Fluff", Ova_Cg.Background's, and "Markdown",
--  Ova_Cg.Markdown_Tab's.
--
--  A file holds one character or several (ova_cg_po's PLAN.md,
--  "Several characters in a file"): Characters, in the file's order, of
--  which one, The_Character, is shown.  The Choice at the right of the
--  menu bar, and the Character menu, switch between them, add, copy,
--  remove and reorder them.  Every change marks the file modified, and
--  Save writes them all.
--
--  The character is Ova_Cg.Character's: every change a widget makes
--  goes into it, then Character.Recompute, then the window shows it
--  again, so no widget holds the only copy of anything.  The window
--  owns the characters, and frees them when they are put away.
--
--  What would wait for the user -- a message, a question, a file
--  chooser, the rulebook's viewer -- goes through an access-to-
--  subprogram variable (Tell, Ask, Choose_Path, Confirm, Choose_Pdf,
--  Ask_Text, and Widgets.Open_Page), so a test can answer it.
--
--  The rulebook's path and the viewer the user chooses are kept in the
--  preferences (Use_Preferences), between runs.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with FLTK.Environment;
with FLTK.Widgets.Groups.Scrolls;
with FLTK.Widgets.Groups.Tabbed;
with FLTK.Widgets.Groups.Windows.Double;
with FLTK.Widgets.Inputs.Text.Multiline;
with FLTK.Widgets.Menus.Menu_Bars;
with Ova_Cg.Character;
with Ova_Cg.Trait_Panel;
with Ova_Cg.Viewer;
with Ova_Cg.Widgets;

package Ova_Cg.Window is

   package Windows renames FLTK.Widgets.Groups.Windows.Double;
   package Bars renames FLTK.Widgets.Menus.Menu_Bars;
   package Tabbed renames FLTK.Widgets.Groups.Tabbed;
   package Scrolls renames FLTK.Widgets.Groups.Scrolls;
   package Multiline renames FLTK.Widgets.Inputs.Text.Multiline;

   type Window_Access is access all Windows.Double_Window'Class;
   type Bar_Access is access all Bars.Menu_Bar'Class;
   type Tabs_Access is access all Tabbed.Tabbed_Group'Class;
   type Group_Access is access all Widgets.Groups.Group'Class;
   type Scroll_Access is access all Scrolls.Scroll'Class;
   type Multiline_Access is access all Multiline.Multiline_Input'Class;

   subtype Item_Index is FLTK.Widgets.Menus.Index;

   --  The sheet's numbers, each with its box.
   type Sheet_Number is
     (Defense_Number, Barrier_Number, Incorporeal_Number, Health_Number, Endurance_Number,
      Reserve_Number, TV_Number, Ability_Levels_Number, Weakness_Levels_Number, Total_Number,
      Ability_Points_Number, Points_Number);

   --  One attack's row in the combat box: its name, its ROLL, DX and
   --  END, and its Edit and Remove buttons.
   type Attack_Row is new Widgets.Groups.Group with record
      Attack       : Character.Attack;
      Name         : Widgets.Output_Access;
      Roll, DX     : Widgets.Number_Box_Access;
      End_Box      : Widgets.Number_Box_Access;
      Edit, Remove : Widgets.Button_Access;
   end record;
   type Attack_Row_Access is access all Attack_Row'Class;

   --  ---- The widgets, for tests (null before Build and after Close) ----

   function Main return Window_Access;
   function Bar return Bar_Access;
   function Tabs return Tabs_Access;
   function Sheet_Tab return Group_Access;
   function Attacks_Tab return Group_Access;

   --  The menu bar's items, each a place for Get_Flags and Picked.
   function New_Item return Item_Index;
   function Open_Item return Item_Index;
   function Save_Item return Item_Index;
   function Save_As_Item return Item_Index;
   function Quit_Item return Item_Index;
   function Limits_Item return Item_Index;
   function Transformed_Item return Item_Index;
   function Add_Character_Item return Item_Index;
   function Duplicate_Item return Item_Index;
   function Remove_Character_Item return Item_Index;
   function Move_Up_Item return Item_Index;
   function Move_Down_Item return Item_Index;
   function Next_Item return Item_Index;
   function Previous_Item return Item_Index;
   function Rulebook_Item return Item_Index;
   function Choose_Pdf_Item return Item_Index;
   function Viewer_Item return Item_Index;

   --  The characters, by number and name; the one shown chosen.
   function Character_Choice return Widgets.Choice_Access;

   function Name_In return Widgets.Input_Access;
   function Player_In return Widgets.Input_Access;
   function Tagline_In return Widgets.Input_Access;
   --  The NPC type: item 1 none, then Heroic, Secondary and Extra.
   function NPC_Type_In return Widgets.Choice_Access;
   function Abilities return Trait_Panel.Trait_Panel_Access;
   function Weaknesses return Trait_Panel.Trait_Panel_Access;
   function Ability_End return Widgets.Number_Box_Access;     --  the selected Ability's END
   function Ability_Mods return Widgets.Button_Access;        --  its Perks and Flaws
   function Ability_Linked return Widgets.Button_Access;      --  its linked content: "Spells...", ...
   function Number (Which : Sheet_Number) return Widgets.Number_Box_Access;
   function Warnings return Widgets.Browser_Access;
   function Combat_Notes return Multiline_Access;
   function Attack_Box return Scroll_Access;
   function Row_Count return Natural;                         --  the combat box's rows
   function Row (I : Positive) return Attack_Row_Access       --  in order
     with Pre => I <= Row_Count;
   function Add_Attack return Widgets.Button_Access;

   --  ---- The file's characters ----

   --  How many there are, and the I'th (1 is the first).
   function Count return Natural;
   function Character_At (I : Positive) return Character.Character_Access
     with Pre => I <= Count;
   function Current return Positive;                          --  the one shown's place
   function The_Character return Character.Character_Access;  --  the one shown
   function Path return String;                               --  the file's; "" for none
   function Modified return Boolean;                          --  changed since loaded or saved

   --  ---- What would wait for the user; a test sets its own ----

   --  Shows a message.
   type Tell_Handler is access procedure (Text : String);
   Tell : Tell_Handler;

   --  Asks whether to save first.
   type Answer is (Save_First, Discard, Cancel);
   type Ask_Handler is access function (Question : String) return Answer;
   Ask : Ask_Handler;

   --  Asks for a file to open, or to save to if Save.
   type Path_Handler is access function (Save : Boolean; Path : out Unbounded_String) return Boolean;
   Choose_Path : Path_Handler;

   --  Asks whether to do what Question says, as Yes, which names it, or
   --  Cancel.
   type Confirm_Handler is access function (Question, Yes : String) return Boolean;
   Confirm : Confirm_Handler;

   --  Asks for the rulebook's PDF.
   type Pdf_Handler is access function (Path : out Unbounded_String) return Boolean;
   Choose_Pdf : Pdf_Handler;

   --  Asks for a line of text, showing Text as it is.
   type Text_Handler is access function (Prompt : String; Text : in out Unbounded_String) return Boolean;
   Ask_Text : Text_Handler;

   --  ---- The rulebook ----

   --  --rulebook's path, or the one chosen this run ("": none).
   Rulebook_Option : Unbounded_String;
   --  The one saved in the preferences ("": none).
   function Saved_Rulebook return String;
   --  The viewer, and whether --viewer chose it, so the preferences'
   --  doesn't replace it.
   Viewer        : Ova_Cg.Viewer.Viewer_Type;
   Viewer_Option : Boolean := False;

   type Database_Access is access all FLTK.Environment.Database'Class;

   --  Takes the rulebook's path and the viewer from Db (null: none),
   --  where the ones the user chooses are kept; --viewer's wins over the
   --  one kept, and --rulebook's and OVA_RULEBOOK's over the path kept
   --  (Viewer.Find_Rulebook).  A viewer kept that isn't one is ignored.
   --  Db is the caller's, freed after Close.
   procedure Use_Preferences (Db : Database_Access);

   --  ---- The window ----

   --  Opens the window, not yet shown, with a new character.
   procedure Build with Pre => Main = null;

   --  Shows the characters Cs, just loaded by Character.Load_All from
   --  the file at Path, and says what the file gives that the rules
   --  compute differently (Character.Notices).  The window owns Cs from
   --  now on.
   procedure Adopt (Cs : Character.Characters; Path : String)
     with Pre => Main /= null and then not Cs.Is_Empty;

   --  Opens the characters in the file at Path; False, said why, if it
   --  can't.
   function Load (Path : String) return Boolean with Pre => Main /= null;

   --  File > Quit, and the window's close button: hides the window,
   --  which ends FLTK.Run, once the changes are saved or let go.
   procedure Quit with Pre => Main /= null;

   --  Frees the window, everything in it, and the characters.
   procedure Close with Pre => Main /= null;

end Ova_Cg.Window;
