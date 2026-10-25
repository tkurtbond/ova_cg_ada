with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with FLTK.Asks;
with FLTK.Native_File_Choosers;
with FLTK.Static;
with FLTK.Widgets.Boxes;
with Ova_Cg.Attack_Dialog;
with Ova_Cg.Background;
pragma Elaborate (Ova_Cg.Background);    --  its own Tell is set first, then the window's
with Ova_Cg.Calc;
with Ova_Cg.Linked_Dialog;
with Ova_Cg.Markdown_Tab;
pragma Elaborate (Ova_Cg.Markdown_Tab);  --  the same
with Ova_Cg.Paths;
with Ova_Cg.Rules;
with Ova_Cg.Save;
with Ova_Cg.Settings;
with Ova_Fmt.Entities;
with System;

package body Ova_Cg.Window is

   package Boxes renames FLTK.Widgets.Boxes;
   package Groups renames Widgets.Groups;
   package Buttons renames Widgets.Buttons;
   package Texts renames Widgets.Texts;
   package Outputs renames Widgets.Outputs;
   package Hold renames Widgets.Hold;
   package Choices renames Widgets.Choices;
   package Env renames FLTK.Environment;

   use type Calc.Attack;
   use type Calc.Modifier;
   use type Calc.Trait;
   use type Calc.Warning_Code;
   use type Character.Character_Access;
   use type Character.Trait;
   use type Rules.Item;
   use type Rules.Kind;
   use type Rules.Link;
   use type System.Address;
   use type Trait_Panel.Trait_Panel_Access;
   use type Attack_Dialog.Window_Access;
   use type Linked_Dialog.Window_Access;
   use type Settings.Window_Access;

   Width      : constant := 640;
   Height     : constant := 800;
   Bar_Height : constant := 25;
   Tab_Height : constant := 25;
   Choice_W   : constant := 250;  --  the characters' Choice, at the menu bar's right
   Title      : constant String := "OVA Character Generator";
   Row_Height : constant := 25;
   --  Each tab's one column.
   Left_X     : constant := 10;
   Column_W   : constant := 620;
   Top        : constant := Bar_Height + Tab_Height + 10;
   --  The combat box: rows shown before it scrolls, each Row_Height + 5
   --  high; an attack's name's width.
   Attack_Rows : constant := 17;
   Row_Step    : constant := 30;
   Name_W      : constant := 180;

   function Image (I : Integer) return String is
     (Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Left));

   --  The window, which fits what FLTK doesn't stretch to its new size:
   --  a hidden box as big as the window, which FLTK resizes with it, and
   --  whose Resize FLTK calls, as it doesn't a window's (PLAN.md,
   --  "Findings").
   type Watcher is new Boxes.Box with null record;
   overriding procedure Resize (This : in out Watcher; X, Y, W, H : Integer);

   type Watcher_Access is access all Watcher'Class;
   type Box_Access is access all Boxes.Box'Class;
   type Pref_Access is access all Env.Pref_Group'Class;

   package Row_Vectors is new Ada.Containers.Vectors (Positive, Attack_Row_Access);
   package Box_Vectors is new Ada.Containers.Vectors (Positive, Box_Access);
   package Attack_Vectors is new Ada.Containers.Vectors (Positive, Calc.Attack, Calc."=");

   type Number_Boxes is array (Sheet_Number) of Widgets.Number_Box_Access;

   type Places is record
      New_Item, Open_Item, Save_Item, Save_As_Item, Quit_Item : Item_Index := 1;
      Limits_Item, Transformed_Item, Add_Character_Item, Duplicate_Item : Item_Index := 1;
      Remove_Character_Item, Move_Up_Item, Move_Down_Item, Next_Item, Previous_Item : Item_Index := 1;
      Rulebook_Item, Choose_Pdf_Item, Viewer_Item : Item_Index := 1;
   end record;

   --  The window's widgets.
   type Parts is record
      Main             : Window_Access;
      Watch            : Watcher_Access;
      Bar              : Bar_Access;
      Items            : Places;
      Character_Choice : Widgets.Choice_Access;
      Tabs             : Tabs_Access;
      Sheet_Tab, Attacks_Tab : Group_Access;
      Name_In, Player_In, Tagline_In : Widgets.Input_Access;
      NPC_Type_In      : Widgets.Choice_Access;
      Abilities, Weaknesses : Trait_Panel.Trait_Panel_Access;
      Ability_End      : Widgets.Number_Box_Access;
      Ability_Mods, Ability_Linked : Widgets.Button_Access;
      Numbers          : Number_Boxes;
      Warnings         : Widgets.Browser_Access;
      Combat_Notes     : Multiline_Access;
      Labels           : Box_Vectors.Vector;  --  the attacks tab's, there for their text
      Attack_Box       : Scroll_Access;
      Rows             : Row_Vectors.Vector;  --  the combat box's, in order
      Add_Attack       : Widgets.Button_Access;
   end record;

   Open : Parts;

   --  The file's characters, in order, and the one shown,
   --  Chars (Cur); the file they came from or were saved to ("": none),
   --  and whether any has changed since.
   Chars        : Character.Characters;
   Cur          : Positive := 1;
   The_Char     : Character.Character_Access;
   The_Path     : Unbounded_String;
   Is_Modified  : Boolean := False;
   Was_Modified : Boolean := False;  --  Is_Modified, when Limits... opened

   --  Attacks removed whose rows still point to them: freed once the
   --  rows are made again.
   Removed_Attacks : Attack_Vectors.Vector;

   --  Where the rulebook and viewer are kept (null: nowhere).
   Prefs : Database_Access;
   Root  : Pref_Access;
   Saved : Unbounded_String;

   function Main return Window_Access is (Open.Main);
   function Bar return Bar_Access is (Open.Bar);
   function Tabs return Tabs_Access is (Open.Tabs);
   function Sheet_Tab return Group_Access is (Open.Sheet_Tab);
   function Attacks_Tab return Group_Access is (Open.Attacks_Tab);
   function New_Item return Item_Index is (Open.Items.New_Item);
   function Open_Item return Item_Index is (Open.Items.Open_Item);
   function Save_Item return Item_Index is (Open.Items.Save_Item);
   function Save_As_Item return Item_Index is (Open.Items.Save_As_Item);
   function Quit_Item return Item_Index is (Open.Items.Quit_Item);
   function Limits_Item return Item_Index is (Open.Items.Limits_Item);
   function Transformed_Item return Item_Index is (Open.Items.Transformed_Item);
   function Add_Character_Item return Item_Index is (Open.Items.Add_Character_Item);
   function Duplicate_Item return Item_Index is (Open.Items.Duplicate_Item);
   function Remove_Character_Item return Item_Index is (Open.Items.Remove_Character_Item);
   function Move_Up_Item return Item_Index is (Open.Items.Move_Up_Item);
   function Move_Down_Item return Item_Index is (Open.Items.Move_Down_Item);
   function Next_Item return Item_Index is (Open.Items.Next_Item);
   function Previous_Item return Item_Index is (Open.Items.Previous_Item);
   function Rulebook_Item return Item_Index is (Open.Items.Rulebook_Item);
   function Choose_Pdf_Item return Item_Index is (Open.Items.Choose_Pdf_Item);
   function Viewer_Item return Item_Index is (Open.Items.Viewer_Item);
   function Character_Choice return Widgets.Choice_Access is (Open.Character_Choice);
   function Name_In return Widgets.Input_Access is (Open.Name_In);
   function Player_In return Widgets.Input_Access is (Open.Player_In);
   function Tagline_In return Widgets.Input_Access is (Open.Tagline_In);
   function NPC_Type_In return Widgets.Choice_Access is (Open.NPC_Type_In);
   function Abilities return Trait_Panel.Trait_Panel_Access is (Open.Abilities);
   function Weaknesses return Trait_Panel.Trait_Panel_Access is (Open.Weaknesses);
   function Ability_End return Widgets.Number_Box_Access is (Open.Ability_End);
   function Ability_Mods return Widgets.Button_Access is (Open.Ability_Mods);
   function Ability_Linked return Widgets.Button_Access is (Open.Ability_Linked);
   function Number (Which : Sheet_Number) return Widgets.Number_Box_Access is (Open.Numbers (Which));
   function Warnings return Widgets.Browser_Access is (Open.Warnings);
   function Combat_Notes return Multiline_Access is (Open.Combat_Notes);
   function Attack_Box return Scroll_Access is (Open.Attack_Box);
   function Row_Count return Natural is (Natural (Open.Rows.Length));
   function Row (I : Positive) return Attack_Row_Access is (Open.Rows (I));
   function Add_Attack return Widgets.Button_Access is (Open.Add_Attack);

   function Count return Natural is (Natural (Chars.Length));
   function Character_At (I : Positive) return Character.Character_Access is (Chars (I));
   function Current return Positive is (Cur);
   function The_Character return Character.Character_Access is (The_Char);
   function Path return String is (To_String (The_Path));
   function Modified return Boolean is (Is_Modified);
   function Saved_Rulebook return String is (To_String (Saved));

   procedure Show_All;
   procedure Show_Rows;
   procedure Show_Characters;

   --  ---- Text ----

   --  "Attack (p. 50)", or the name and "(p. ?)" for one the tables don't
   --  have.
   function Label_Of (It : Rules.Item; Name : Unbounded_String) return String is
     (if It /= null then Rules.Label (It) else To_String (Name) & " (" & Rules.Page_Text (null) & ")");

   --  ---- What would wait for the user ----

   procedure Dialog_Tell (Text : String) is
   begin
      FLTK.Asks.Message_Box (Text);
   end Dialog_Tell;

   --  Escape, or the dialog closed, is Cancel.
   function Dialog_Ask (Question : String) return Answer is
      use FLTK.Asks;
   begin
      case Extended_Choice (Question, "Save", "Don't save", "Cancel") is
         when First  => return Save_First;
         when Second => return Discard;
         when others => return Cancel;
      end case;
   end Dialog_Ask;

   --  Cancel is the default, pushed by Enter; Escape is Cancel too.
   function Dialog_Confirm (Question, Yes : String) return Boolean is
      use FLTK.Asks;
   begin
      return Extended_Choice (Question, Yes, "Cancel") = First;
   end Dialog_Confirm;

   function Dialog_Path (Save : Boolean; Path : out Unbounded_String) return Boolean is
      use FLTK.Native_File_Choosers;
      C : Native_File_Chooser := Forge.Create (if Save then Browse_Save_File else Browse_File);
   begin
      Path := Null_Unbounded_String;
      if Save then
         C.Set_Title ("Save the character as");
         C.Set_Options (Saveas_Confirm);
      else
         C.Set_Title ("Open a character");
      end if;
      C.Set_Filter ("YAML" & ASCII.HT & "*.{yaml,yml}");  --  FLTK's "name<tab>pattern"
      if C.Show = Picked then
         Path := To_Unbounded_String (C.Get_Filename);
      end if;
      return Path /= "";
   end Dialog_Path;

   function Dialog_Pdf (Path : out Unbounded_String) return Boolean is
      use FLTK.Native_File_Choosers;
      C : Native_File_Chooser := Forge.Create (Browse_File);
   begin
      Path := Null_Unbounded_String;
      C.Set_Title ("The rulebook's PDF");
      C.Set_Filter ("PDF" & ASCII.HT & "*.pdf");
      if C.Show = Picked then
         Path := To_Unbounded_String (C.Get_Filename);
      end if;
      return Path /= "";
   end Dialog_Pdf;

   --  FLTK's input dialog gives "" for Cancel, so an empty answer is
   --  taken as one.
   function Dialog_Text (Prompt : String; Text : in out Unbounded_String) return Boolean is
      Answer : constant String := FLTK.Asks.Text_Input (Prompt, To_String (Text));
   begin
      if Answer = "" then
         return False;
      end if;
      Text := To_Unbounded_String (Answer);
      return True;
   end Dialog_Text;

   --  Tell as it is now: the dialog's, which a test may have replaced.
   procedure Say (Text : String) is
   begin
      Tell (Text);
   end Say;

   --  ---- The rulebook ----

   --  Keeps Text under Key in the preferences, written at once.  A
   --  file that can't be written is said; the choice still holds for
   --  this run.
   procedure Keep (Key, Text : String) is
   begin
      if Root /= null then
         Root.Set (Key, Text);
         Env.Flush (Prefs.all);
      end if;
   exception
      when Env.Preference_Error =>
         Say ("The preferences couldn't be written, so this choice won't be kept for the next run.");
   end Keep;

   --  What the preferences hold under Key; "" for nothing.
   function Kept (Key : String) return String is
     (Character.Trim (Root.Get (Key, "")));

   procedure Free_Root is
      procedure Free is new Ada.Unchecked_Deallocation (Env.Pref_Group'Class, Pref_Access);
   begin
      if Root /= null then
         Free (Root);
      end if;
   end Free_Root;

   procedure Use_Preferences (Db : Database_Access) is
      V : Ova_Cg.Viewer.Viewer_Type;
   begin
      Free_Root;
      Prefs := Db;
      Saved := Null_Unbounded_String;
      if Db /= null then
         Root := new Env.Pref_Group'Class'(Env.Forge.Root (Env.Database (Db.all)));
         Saved := To_Unbounded_String (Kept ("rulebook"));
         Ova_Cg.Viewer.Default (V);
         if not Viewer_Option and then Ova_Cg.Viewer.Parse (Kept ("viewer"), V) then
            Viewer := V;
         end if;
      end if;
   end Use_Preferences;

   --  Asks for the rulebook's PDF, uses it from now on, and keeps it.
   function Choose_Rulebook return Boolean is
      P : Unbounded_String;
   begin
      if not Choose_Pdf (P) then
         return False;
      end if;
      P := To_Unbounded_String (Paths.Absolute (To_String (P)));
      Rulebook_Option := P;
      Saved := P;
      Keep ("rulebook", To_String (P));
      return True;
   end Choose_Rulebook;

   --  Opens the rulebook at printed page Page.  If it isn't found, asks
   --  for it once; if not given, says why.
   procedure Open_Page (Page : Positive) is
      Pdf, Msg : Unbounded_String;

      function Found return Boolean is
        (Ova_Cg.Viewer.Find_Rulebook (To_String (Rulebook_Option), To_String (Saved), Pdf));

   begin
      if not Found and then (not Choose_Rulebook or else not Found) then
         Say ("The rulebook isn't at " & To_String (Pdf)
              & ": choose it with Rulebook > Choose PDF..., or give it with --rulebook or OVA_RULEBOOK.");
         return;
      end if;
      --  Msg says why it failed, or what the viewer couldn't do.
      if not Ova_Cg.Viewer.Open (Viewer, To_String (Pdf), Page, Msg) or else Msg /= "" then
         Say (To_String (Msg));
      end if;
   end Open_Page;

   procedure Rulebook_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Widgets.Open_Page (1);
   end Rulebook_Action;

   procedure Choose_Pdf_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Ignore : constant Boolean := Choose_Rulebook;  --  False: cancelled
   begin
      null;
   end Choose_Pdf_Action;

   --  Rulebook > Viewer...: a viewer's name or a command, kept.
   procedure Viewer_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Text : Unbounded_String := To_Unbounded_String (Ova_Cg.Viewer.Name (Viewer));
      V    : Ova_Cg.Viewer.Viewer_Type;
   begin
      if Ask_Text ("Viewer: okular, evince, mupdf, xdg-open, or a command"
                   & " (%f the PDF, %p its page, %l the printed page)", Text)
      then
         Ova_Cg.Viewer.Default (V);
         if Ova_Cg.Viewer.Parse (To_String (Text), V) then
            Viewer := V;
            Keep ("viewer", Ova_Cg.Viewer.Name (V));
         else
            Say ("Not a viewer: " & To_String (Text)
                 & ". Give okular, evince, mupdf, xdg-open, or a command with %f for the PDF.");
         end if;
      end if;
   end Viewer_Action;

   --  ---- Title and changes ----

   --  The file's name, its path without its directory.
   function File_Name return String is
      P     : constant String := To_String (The_Path);
      Slash : constant Natural := Ada.Strings.Fixed.Index (P, "/", Ada.Strings.Backward);
   begin
      return P (Slash + 1 .. P'Last);
   end File_Name;

   procedure Show_Title is
      T : Unbounded_String := To_Unbounded_String (Title);
   begin
      if The_Path /= "" then
         Append (T, " - " & File_Name);
      end if;
      if Count > 1 then
         Append (T, " (" & Image (Cur) & " of " & Image (Count) & ")");
      end if;
      if Is_Modified then
         Append (T, " *");
      end if;
      Open.Main.Set_Label (To_String (T));
   end Show_Title;

   procedure Show_Warnings is
      L : Calc.Warning_List renames The_Char.Warnings;
   begin
      Open.Warnings.Clear;
      for I in 1 .. Calc.Length (L) loop
         declare
            W : constant Calc.Warning := Calc.Element (L, I);
            R : Unbounded_String;
         begin
            if W.Of_Attack /= null then
               Append (R, Character.Attack (W.Of_Attack).Name & ": ");
            end if;
            if W.Of_Trait /= null then
               Append (R, Label_Of (W.Of_Trait.Item, Character.Trait (W.Of_Trait).Name));
            end if;
            if W.Of_Mod /= null then
               if W.Of_Trait /= null then
                  Append (R, ": ");
               end if;
               Append (R, Label_Of (W.Of_Mod.Item, Character.Modifier (W.Of_Mod).Name));
            end if;
            case W.Code is
               when Calc.Unknown_Item =>
                  Append (R, " isn't in the rulebook's lists");
               when Calc.Level_Range =>
                  if W.Of_Trait.Of_Kind = Rules.Ability then
                     Append (R, ": an Ability is +1 to +5 (p. 18)");
                  else
                     Append (R, ": a Weakness is -1 to -3 (p. 18)");
                  end if;
               when Calc.Too_Often =>
                  Append (R, " is taken more often than it may be (p. 83)");
               when Calc.Cost_Range =>
                  Append (R, "'s cost is outside its range, or not in steps of 5 (p. 87)");
               when Calc.No_Damage_Ineffective =>
                  Append (R, "No Damage with Ineffective (p. 88)");
               when Calc.Redirectable_Alone =>
                  Append (R, "Redirectable without Ranged (p. 86)");
               when Calc.Spell_Range =>
                  Append (R, ": a spell's level isn't 1 to 5 (or -1 to -3, a Weakness), or its Magic's"
                          & " isn't 1 to 5: no cost (p. 58)");
               when Calc.Table_Range =>
                  Append (R, "Tough, Vigorous or Endurance Reserve past +5, counted as +5");
               when Calc.Base_Zero_Broken =>
                  Append (R, "The Character Total is beyond Base Zero's range (p. 21)");
               when Calc.Starting_Broken =>
                  Append (R, "The Abilities are beyond the starting levels and the Weaknesses (p. 21)");
               when Calc.Ceiling_Broken =>
                  Append (R, "The Abilities are beyond the Power Ceiling (p. 21)");
               when Calc.Over_Five =>
                  if W.Of_Attack = null then
                     Append (R, "DEFENSE: ");
                  end if;
                  Append (R, "Abilities give the roll more than +5 (p. 21)");
            end case;
            Open.Warnings.Add (To_String (R));
         end;
      end loop;
   end Show_Warnings;

   --  Whether a warning has Code.
   function Warned (Code : Calc.Warning_Code) return Boolean is
      L : Calc.Warning_List renames The_Char.Warnings;
   begin
      for I in 1 .. Calc.Length (L) loop
         if Calc.Element (L, I).Code = Code then
            return True;
         end if;
      end loop;
      return False;
   end Warned;

   procedure Red (B : Widgets.Number_Box_Access; On : Boolean) is
   begin
      B.Shown.Set_Text_Color (if On then FLTK.Red_Color else FLTK.Foreground_Color);
      B.Shown.Redraw;
   end Red;

   procedure Show_If (B : Widgets.Number_Box_Access; On : Boolean) is
   begin
      if On then
         B.Show;
      else
         B.Hide;
      end if;
   end Show_If;

   --  Every number box shown again: Barrier's, Incorporeal Form's and
   --  the Reserve's only when the character has them, Scaled Cost's
   --  points (the Abilities' and the net) only under it.  A total a
   --  limit finds too high is red (p. 21): Base Zero's the Character
   --  Total, or the net points under Scaled Cost; a Power Ceiling's or
   --  the starting levels' the Abilities' levels, or their points under
   --  Scaled Cost.
   procedure Show_Numbers is
      Base_Zero : constant Boolean := Warned (Calc.Base_Zero_Broken);
      Spent     : constant Boolean := Warned (Calc.Ceiling_Broken) or else Warned (Calc.Starting_Broken);
      Scaled    : constant Boolean := The_Char.Options.Scaled_Cost;
   begin
      for B of Open.Numbers loop
         B.Display;
      end loop;
      Red (Open.Numbers (Total_Number), Base_Zero and not Scaled);
      Red (Open.Numbers (Points_Number), Base_Zero and Scaled);
      Red (Open.Numbers (Ability_Levels_Number), Spent and not Scaled);
      Red (Open.Numbers (Ability_Points_Number), Spent and Scaled);
      Show_If (Open.Numbers (Barrier_Number), The_Char.Has_Barrier);
      Show_If (Open.Numbers (Incorporeal_Number), The_Char.Has_Incorporeal);
      Show_If (Open.Numbers (Reserve_Number), The_Char.Has_Reserve);
      Show_If (Open.Numbers (Ability_Points_Number), Scaled);
      Show_If (Open.Numbers (Points_Number), Scaled);
      for R of Open.Rows loop
         R.Roll.Display;
         R.DX.Display;
         R.End_Box.Display;
      end loop;
      Open.Ability_End.Display;
      Show_Warnings;
   end Show_Numbers;

   --  After any change to the character: computed again and shown.
   procedure Changed is
   begin
      Character.Recompute (The_Char);
      Is_Modified := True;
      Show_Title;
      Show_Numbers;
      Markdown_Tab.Show (The_Char);
   end Changed;

   --  After a change on the Background tab: text alone, nothing to
   --  compute.
   procedure Background_Changed is
   begin
      Is_Modified := True;
      Show_Title;
      Markdown_Tab.Show (The_Char);
   end Background_Changed;

   --  ---- Numbers ----

   --  One of the sheet's numbers.
   type Sheet_Target is new Widgets.Target with record
      Which : Sheet_Number;
   end record;

   overriding function Get (T : Sheet_Target) return Calc.Number;
   overriding procedure Put (T : in out Sheet_Target; N : Calc.Number);

   overriding function Get (T : Sheet_Target) return Calc.Number is
      C : Character.Character_Record'Class renames The_Char.all;
   begin
      case T.Which is
         when Defense_Number         => return C.Defense;
         when Barrier_Number         => return C.Barrier;
         when Incorporeal_Number     => return C.Incorporeal;
         when Health_Number          => return C.Health;
         when Endurance_Number       => return C.Endurance;
         when Reserve_Number         => return C.Reserve;
         when TV_Number              => return C.TV;
         when Ability_Levels_Number  => return C.Ability_Levels;
         when Weakness_Levels_Number => return C.Weakness_Levels;
         when Total_Number           => return C.Total;
         when Ability_Points_Number  => return C.Ability_Points;
         when Points_Number          => return C.Points;
      end case;
   end Get;

   overriding procedure Put (T : in out Sheet_Target; N : Calc.Number) is
      C : Character.Character_Record'Class renames The_Char.all;
   begin
      case T.Which is
         when Defense_Number         => C.Defense := N;
         when Barrier_Number         => C.Barrier := N;
         when Incorporeal_Number     => C.Incorporeal := N;
         when Health_Number          => C.Health := N;
         when Endurance_Number       => C.Endurance := N;
         when Reserve_Number         => C.Reserve := N;
         when TV_Number              => C.TV := N;
         when Ability_Levels_Number  => C.Ability_Levels := N;
         when Weakness_Levels_Number => C.Weakness_Levels := N;
         when Total_Number           => C.Total := N;
         when Ability_Points_Number  => C.Ability_Points := N;
         when Points_Number          => C.Points := N;
      end case;
   end Put;

   --  An attack's ROLL, DX or END.
   type Attack_Number is (Roll_Number, DX_Number, End_Number);

   type Attack_Target is new Widgets.Target with record
      Attack : Calc.Attack;
      Which  : Attack_Number;
   end record;

   overriding function Get (T : Attack_Target) return Calc.Number is
     (case T.Which is
         when Roll_Number => T.Attack.Roll,
         when DX_Number   => T.Attack.DX,
         when End_Number  => T.Attack.End_Cost);

   overriding procedure Put (T : in out Attack_Target; N : Calc.Number);

   overriding procedure Put (T : in out Attack_Target; N : Calc.Number) is
   begin
      case T.Which is
         when Roll_Number => T.Attack.Roll := N;
         when DX_Number   => T.Attack.DX := N;
         when End_Number  => T.Attack.End_Cost := N;
      end case;
   end Put;

   --  An Ability's END.
   type Trait_Target is new Widgets.Target with record
      Trait : Calc.Trait;
   end record;

   overriding function Get (T : Trait_Target) return Calc.Number is (T.Trait.End_Cost);
   overriding procedure Put (T : in out Trait_Target; N : Calc.Number);

   overriding procedure Put (T : in out Trait_Target; N : Calc.Number) is
   begin
      T.Trait.End_Cost := N;
   end Put;

   --  A number box's text taken; refused text is said so.
   procedure Number_Changed (B : in out Widgets.Number_Box'Class; OK : Boolean) is
   begin
      if not OK then
         declare
            Label : constant String := B.Get_Label;
            Msg   : Unbounded_String := To_Unbounded_String ("Not a number");
         begin
            if Label /= "" then
               Append (Msg, " for " & Label);
            end if;
            Append (Msg, ": a whole number");
            if B.Allow_Half then
               Append (Msg, ", or 1/2");
            end if;
            if B.Allow_Plus then
               Append (Msg, ", which may end in +");
            end if;
            Append (Msg, ". The computed number is used.");
            Say (To_String (Msg));
         end;
      end if;
      Changed;
   end Number_Changed;

   procedure Sheet_Box (Which : Sheet_Number; X, Y : Integer; Label : String) is
      B : constant Widgets.Number_Box_Access := Widgets.Open_Number_Box (X, Y, Label);
   begin
      B.Set_Target (new Sheet_Target'(Which => Which));
      B.Changed := Number_Changed'Access;
      Open.Numbers (Which) := B;
   end Sheet_Box;

   --  ---- Abilities and Weaknesses ----

   --  The selected Ability's END, Perks and Flaws, and linked content:
   --  the box and buttons work only for one with them.
   procedure Show_Ability (T : Character.Trait) is
      Linked : Rules.Link := Rules.No_Link;
   begin
      if T = null then
         Open.Ability_End.Set_Target (null);
         Open.Ability_End.Deactivate;
         Open.Ability_Mods.Deactivate;
      else
         Open.Ability_End.Set_Target (new Trait_Target'(Trait => Calc.Trait (T)));
         if T.Has_End then
            Open.Ability_End.Activate;
         else
            Open.Ability_End.Deactivate;
         end if;
         Open.Ability_Mods.Activate;
         if T.Item /= null then
            Linked := T.Item.Linked;
         end if;
      end if;
      Open.Ability_Linked.Set_Label
        (case Linked is
            when Rules.No_Link => "Linked...",
            when Rules.Spells  => "Spells...",
            when Rules.Form    => "Form...",
            when Rules.Partner => "Companion...",
            when Rules.Machine => "Vehicle...");
      if Linked = Rules.No_Link then
         Open.Ability_Linked.Deactivate;
      else
         Open.Ability_Linked.Activate;
      end if;
      Open.Ability_End.Display;
   end Show_Ability;

   procedure Ability_Selected (P : in out Trait_Panel.Trait_Panel'Class; T : Character.Trait) is
      pragma Unreferenced (P);
   begin
      Show_Ability (T);
   end Ability_Selected;

   procedure Panel_Changed (P : in out Trait_Panel.Trait_Panel'Class) is
      pragma Unreferenced (P);
   begin
      Changed;
   end Panel_Changed;

   function Open_Trait_Panel (X : Integer; Kind : Rules.Kind; Title : String)
     return Trait_Panel.Trait_Panel_Access
   is
      P : constant Trait_Panel.Trait_Panel_Access := Trait_Panel.Open (X, Top + 65, 305, 220, Kind, Title);
   begin
      P.Set_Handlers ((if Kind = Rules.Ability then Ability_Selected'Access else null),
                      Panel_Changed'Access);
      return P;
   end Open_Trait_Panel;

   procedure Mods_Done (Changed_It : Boolean) is
   begin
      if Changed_It then
         Changed;
      end if;
      Open.Abilities.Refresh (Open.Abilities.Browser.Selected_Index);
   end Mods_Done;

   procedure Mods_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      T : constant Character.Trait := Open.Abilities.Selected;
   begin
      if T /= null and then Attack_Dialog.Dialog = null then
         Attack_Dialog.Edit_Mods (The_Char, T, Mods_Done'Access);
      end if;
   end Mods_Action;

   --  After the linked dialog: what it changed is in the character
   --  already.
   procedure Linked_Done is
   begin
      Open.Abilities.Refresh (Open.Abilities.Browser.Selected_Index);
   end Linked_Done;

   procedure Linked_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      T : constant Character.Trait := Open.Abilities.Selected;
   begin
      if T /= null and then T.Item /= null and then T.Item.Linked /= Rules.No_Link
        and then Linked_Dialog.Dialog = null
      then
         Linked_Dialog.Edit (The_Char, T, Linked_Done'Access);
      end if;
   end Linked_Action;

   --  ---- The combat box ----

   procedure Attack_Done (Changed_It : Boolean) is
   begin
      if Changed_It then
         Changed;
      end if;
      Show_Rows;
   end Attack_Done;

   --  The row whose Edit or Remove button W is; null for none.
   function Row_Of (W : FLTK.Widgets.Widget'Class) return Attack_Row_Access is
   begin
      for R of Open.Rows loop
         if W'Address = R.Edit.all'Address or else W'Address = R.Remove.all'Address then
            return R;
         end if;
      end loop;
      return null;
   end Row_Of;

   procedure Edit_Action (W : in out FLTK.Widgets.Widget'Class) is
      R : constant Attack_Row_Access := Row_Of (W);
   begin
      if R /= null and then Attack_Dialog.Dialog = null then
         Attack_Dialog.Edit_Attack (The_Char, R.Attack, False, Attack_Done'Access);
      end if;
   end Edit_Action;

   procedure Rebuild_Action is
   begin
      Show_Rows;
   end Rebuild_Action;

   --  The row is made again later, from a timeout: a button can't be
   --  freed inside its own callback (AGENTS.md).  The attack is freed
   --  then too, once no row points to it.
   procedure Remove_Action (W : in out FLTK.Widgets.Widget'Class) is
      R : constant Attack_Row_Access := Row_Of (W);
   begin
      if R /= null then
         Character.Remove_Attack (The_Char, Calc.Attack (R.Attack));
         Removed_Attacks.Append (Calc.Attack (R.Attack));
         Changed;
         if not FLTK.Static.Has_Timeout (Rebuild_Action'Access) then
            FLTK.Static.Add_Timeout (0.0, Rebuild_Action'Access);
         end if;
      end if;
   end Remove_Action;

   procedure Add_Attack_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      A : Character.Attack;
   begin
      if Attack_Dialog.Dialog /= null then
         return;
      end if;
      A := Character.New_Attack (To_Unbounded_String ("New attack"));
      Calc.Add_Attack (Calc.Sheet (The_Char), Calc.Attack (A));
      Character.Recompute (The_Char);
      Attack_Dialog.Edit_Attack (The_Char, A, True, Attack_Done'Access);
   end Add_Attack_Action;

   function Row_Number_Box (A : Calc.Attack; Which : Attack_Number; X, Y : Integer)
     return Widgets.Number_Box_Access
   is
      B : constant Widgets.Number_Box_Access := Widgets.Open_Number_Box (X, Y, "");
   begin
      B.Set_Target (new Attack_Target'(Attack => A, Which => Which));
      B.Changed := Number_Changed'Access;
      return B;
   end Row_Number_Box;

   procedure Free_Rows is
      procedure Free_Output is new Ada.Unchecked_Deallocation (Outputs.Output'Class, Widgets.Output_Access);
      procedure Free_Button is new Ada.Unchecked_Deallocation (Buttons.Button'Class, Widgets.Button_Access);
      procedure Free_Row is new Ada.Unchecked_Deallocation (Attack_Row'Class, Attack_Row_Access);
   begin
      for R of Open.Rows loop
         Free_Output (R.Name);
         Widgets.Free (R.Roll);
         Widgets.Free (R.DX);
         Widgets.Free (R.End_Box);
         Free_Button (R.Edit);
         Free_Button (R.Remove);
         Free_Row (R);
      end loop;
      Open.Rows.Clear;
      for A of Removed_Attacks loop
         Calc.Free_Attacks (A);
      end loop;
      Removed_Attacks.Clear;
   end Free_Rows;

   function Round (X : Float) return Integer is (Integer (Float'Floor (X + 0.5)));

   --  The combat box's rows made again, one for each attack, stretched
   --  as the box is: FLTK's Scroll moves its children when it is
   --  resized, but doesn't stretch them.  Each row is made at the
   --  window's first size, then resized, and FLTK stretches what is in
   --  it.
   procedure Show_Rows is
      Box : Scrolls.Scroll'Class renames Open.Attack_Box.all;
      SX  : constant Float := Float (Box.Get_W) / Float (Column_W);
      SY  : constant Float := Float (Box.Get_H) / Float (Attack_Rows * Row_Step + 4);
      Y0  : constant Integer := Box.Get_Y + Round (2.0 * SY);
      A   : Calc.Attack := The_Char.Attacks;
      I   : Natural := 0;
      X, Y : Integer;
      R   : Attack_Row_Access;
   begin
      Free_Rows;
      Box.Begin_Current;
      while A /= null loop
         Y := Y0 + Round (Float (I * Row_Step) * SY);
         R := new Attack_Row'
           (Groups.Group'(Groups.Forge.Create (Box.Get_X + 2, Y, Column_W - 20, Row_Height)) with
            Attack => Character.Attack (A), others => <>);
         R.Begin_Current;
         X := Box.Get_X + 2;
         R.Name := new Outputs.Output'(Outputs.Forge.Create (X, Y, Name_W, Row_Height, ""));
         R.Name.Set_Value (To_String (R.Attack.Name));
         X := X + Name_W + 8;
         R.Roll := Row_Number_Box (A, Roll_Number, X, Y);
         X := X + Widgets.Width + 8;
         R.DX := Row_Number_Box (A, DX_Number, X, Y);
         R.DX.Allow_Half := True;
         X := X + Widgets.Width + 8;
         R.End_Box := Row_Number_Box (A, End_Number, X, Y);
         X := X + Widgets.Width + 8;
         R.Edit := new Buttons.Button'(Buttons.Forge.Create (X, Y, 50, Row_Height, "Edit"));
         R.Edit.Set_Callback (Edit_Action'Access);
         R.Remove := new Buttons.Button'(Buttons.Forge.Create (X + 55, Y, 65, Row_Height, "Remove"));
         R.Remove.Set_Callback (Remove_Action'Access);
         R.End_Current;
         R.Resize (Box.Get_X + Round (2.0 * SX), Y, Round (Float (Column_W - 20) * SX),
                   Round (Float (Row_Height) * SY));
         Open.Rows.Append (R);
         I := I + 1;
         A := A.Next;
      end loop;
      Box.End_Current;
      Show_Numbers;
      Box.Redraw;
   end Show_Rows;

   --  What FLTK doesn't stretch, fitted to the window's size: the combat
   --  box's rows, the traits' columns, and the portrait.
   procedure Fit_Action is
   begin
      Show_Rows;
      Open.Abilities.Fit;
      Open.Weaknesses.Fit;
      Background.Fit;
   end Fit_Action;

   --  FLTK stretches the window's widgets; the rest is fitted later,
   --  from a timeout, when the window has its new size.
   overriding procedure Resize (This : in out Watcher; X, Y, W, H : Integer) is
      Sized : constant Boolean := W /= This.Get_W or else H /= This.Get_H;
   begin
      Boxes.Box (This).Resize (X, Y, W, H);
      if Sized and then Open.Main /= null and then not FLTK.Static.Has_Timeout (Fit_Action'Access) then
         FLTK.Static.Add_Timeout (0.0, Fit_Action'Access);
      end if;
   end Resize;

   --  ---- The names and the Combat Notes ----

   procedure Text_Action (W : in out FLTK.Widgets.Widget'Class) is
      C : Character.Character_Record'Class renames The_Char.all;
   begin
      if W'Address = Open.Name_In.all'Address then
         C.Name := To_Unbounded_String (Character.Trim (Open.Name_In.Get_Value));
         Show_Characters;
      elsif W'Address = Open.Player_In.all'Address then
         Character.Set_Text (C.Has_Player, C.Player,
                             To_Unbounded_String (Character.Trim (Open.Player_In.Get_Value)));
      elsif W'Address = Open.Tagline_In.all'Address then
         Character.Set_Text (C.Has_Tagline, C.Tagline,
                             To_Unbounded_String (Character.Trim (Open.Tagline_In.Get_Value)));
      elsif W'Address = Open.Combat_Notes.all'Address then
         Character.Set_Text (C.Has_Combat_Notes, C.Combat_Notes,
                             To_Unbounded_String (Open.Combat_Notes.Get_Value));
      end if;
      Is_Modified := True;
      Show_Title;
      Markdown_Tab.Show (The_Char);
   end Text_Action;

   function Text_Input (X, Y, W : Integer; Label : String) return Widgets.Input_Access is
      I : constant Widgets.Input_Access := new Texts.Text_Input'(Texts.Forge.Create (X, Y, W, Row_Height, Label));
   begin
      I.Set_When (FLTK.When_Changed);
      I.Set_Callback (Text_Action'Access);
      return I;
   end Text_Input;

   --  ---- The NPC type ----

   --  The NPC type chosen: the sheet's kind, so its Health, Endurance and
   --  TV, follow it (p. 123-124).  Item 1 is none, item K + 2 NPC_Kind'Val (K).
   procedure NPC_Type_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      I : constant FLTK.Widgets.Menus.Extended_Index := Open.NPC_Type_In.Chosen_Index;
   begin
      if I <= 1 then
         Character.Set_NPC_Type (The_Char, False, Ova_Fmt.Entities.Heroic);
      else
         Character.Set_NPC_Type (The_Char, True, Ova_Fmt.Entities.NPC_Kind'Val (I - 2));
      end if;
      Changed;
   end NPC_Type_Action;

   procedure Show_NPC_Type is
   begin
      Open.NPC_Type_In.Set_Chosen
        (if The_Char.Has_NPC_Type then Ova_Fmt.Entities.NPC_Kind'Pos (The_Char.NPC_Type) + 2 else 1);
   end Show_NPC_Type;

   --  ---- Limits and the transformed form ----

   --  Character > Limits...: Ova_Cg.Settings, which tells Limits_Changed
   --  each change.  Cancel puts the options back, and the title's mark
   --  as it was.
   procedure Limits_Changed is
   begin
      Changed;
      --  The lists show Scaled Cost's points only under it.
      Open.Abilities.Refresh (Open.Abilities.Browser.Selected_Index);
      Open.Weaknesses.Refresh (Open.Weaknesses.Browser.Selected_Index);
   end Limits_Changed;

   procedure Limits_Done (Accepted : Boolean) is
   begin
      if not Accepted then
         Is_Modified := Was_Modified;
         Show_Title;
      end if;
   end Limits_Done;

   procedure Limits_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if Settings.Dialog = null then
         Was_Modified := Is_Modified;
         Settings.Edit (The_Char, Limits_Done'Access);
      end if;
   end Limits_Action;

   --  Character > Transformed form: the sheet shown, and computed, in
   --  the Transformation's form (p. 63); the combat key transformed.
   procedure Transformed_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      The_Char.Transformed := Open.Bar.Get_Flags (Open.Items.Transformed_Item).Value;
      Changed;
   end Transformed_Action;

   --  The menu's toggle set from the character.
   procedure Show_Transformed is
      F : FLTK.Menu_Flag := Open.Bar.Get_Flags (Open.Items.Transformed_Item);
   begin
      F.Value := The_Char.Transformed;
      Open.Bar.Set_Flags (Open.Items.Transformed_Item, F);
   end Show_Transformed;

   --  ---- The file's characters ----

   --  Character I's label in the Choice: its number and name, any "&"
   --  doubled so that FLTK shows it.
   function Character_Label (I : Positive) return String is
      Name : constant String := To_String (Chars (I).Name);
      R    : Unbounded_String := To_Unbounded_String (Image (I) & ". ");
   begin
      if Name = "" then
         Append (R, "(no name)");
      else
         for Ch of Name loop
            if Ch = '&' then
               Append (R, '&');
            end if;
            Append (R, Ch);
         end loop;
      end if;
      return To_String (R);
   end Character_Label;

   --  Item I of the menu bar active if On.
   procedure Activate (I : Item_Index; On : Boolean) is
      F : FLTK.Menu_Flag := Open.Bar.Get_Flags (I);
   begin
      F.Inactive := not On;
      Open.Bar.Set_Flags (I, F);
   end Activate;

   --  The Choice lists the characters again, the one shown chosen, and
   --  the Character menu's items are active where they can do something.
   --  Each item is added as "-" and then labelled, so that a "/" in a
   --  name isn't taken for a submenu.
   procedure Show_Characters is
      N : constant Natural := Count;
   begin
      Open.Character_Choice.Clear;
      for I in 1 .. N loop
         Open.Character_Choice.Add ("-", null);
         Open.Character_Choice.Set_Label (I, Character_Label (I));
      end loop;
      Open.Character_Choice.Set_Chosen (Cur);
      Activate (Open.Items.Remove_Character_Item, N > 1);
      Activate (Open.Items.Move_Up_Item, Cur > 1);
      Activate (Open.Items.Previous_Item, Cur > 1);
      Activate (Open.Items.Move_Down_Item, Cur < N);
      Activate (Open.Items.Next_Item, Cur < N);
   end Show_Characters;

   --  Shows character I.
   procedure Show_Character (I : Positive) is
   begin
      Cur := I;
      The_Char := Chars (I);
      Character.Recompute (The_Char);
      Show_All;
   end Show_Character;

   procedure Character_Choice_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      I : constant FLTK.Widgets.Menus.Extended_Index := Open.Character_Choice.Chosen_Index;
   begin
      if I >= 1 and then I /= Cur then
         Show_Character (I);
      end if;
   end Character_Choice_Action;

   --  Adds C after the last character, and shows it.
   procedure Append_Character (C : not null Character.Character_Access) is
   begin
      Chars.Append (C);
      Is_Modified := True;
      Show_Character (Count);
   end Append_Character;

   --  Character > Add Character: a new character, last.
   procedure Add_Character_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Append_Character (Character.New_Character);
   end Add_Character_Action;

   --  Character > Duplicate Character: a copy of the one shown, last.
   procedure Duplicate_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      C : constant Character.Character_Access := Save.Copy (The_Char);
   begin
      if C = null then
         Say ("The character couldn't be copied.");
      else
         Append_Character (C);
      end if;
   end Duplicate_Action;

   --  Character > Remove Character...: the one shown, once the user says
   --  so; not the only one, since a file holds at least one.  The one
   --  after it is shown, or the one before if it was last; then the one
   --  removed is freed, once nothing shows it.
   procedure Remove_Character_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if Count > 1
        and then Confirm ("Remove " & (if The_Char.Name /= "" then To_String (The_Char.Name)
                                       else "this character") & " from the file?",
                          "Remove")
      then
         declare
            Gone : Character.Characters := Character.One (The_Char);
         begin
            Chars.Delete (Cur);
            Is_Modified := True;
            Show_Character (Positive'Min (Cur, Count));
            Character.Free_All (Gone);
         end;
      end if;
   end Remove_Character_Action;

   --  The character shown swapped with the one D after it, and still
   --  shown.
   procedure Move (D : Integer) is
   begin
      if Cur + D >= 1 and then Cur + D <= Count then
         Chars.Swap (Cur, Cur + D);
         Cur := Cur + D;
         Is_Modified := True;
         Show_Characters;
         Show_Title;
      end if;
   end Move;

   procedure Move_Up_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Move (-1);
   end Move_Up_Action;

   procedure Move_Down_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Move (1);
   end Move_Down_Action;

   procedure Next_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if Cur < Count then
         Show_Character (Cur + 1);
      end if;
   end Next_Action;

   procedure Previous_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if Cur > 1 then
         Show_Character (Cur - 1);
      end if;
   end Previous_Action;

   --  ---- Everything shown ----

   procedure Show_All is
   begin
      Open.Name_In.Set_Value (To_String (The_Char.Name));
      Open.Player_In.Set_Value (To_String (The_Char.Player));
      Open.Tagline_In.Set_Value (To_String (The_Char.Tagline));
      Open.Combat_Notes.Set_Value (To_String (The_Char.Combat_Notes));
      Show_NPC_Type;
      Open.Abilities.Show (Calc.Sheet (The_Char), null, The_Char);
      Open.Weaknesses.Show (Calc.Sheet (The_Char), null, The_Char);
      Show_Transformed;
      Show_Rows;
      Background.Show (The_Char, (if The_Path /= "" then Paths.Dir (To_String (The_Path)) else ""));
      Show_Characters;
      Show_Title;
      Markdown_Tab.Show (The_Char);
   end Show_All;

   --  ---- Files ----

   --  Shows the characters Cs, from the file P ("": none), the first of
   --  them; then frees the ones shown before, once nothing shows them.
   procedure Take (Cs : Character.Characters; P : String) is
      Old : Character.Characters := Chars;
   begin
      Chars := Cs;
      Cur := 1;
      The_Char := Chars (1);
      The_Path := To_Unbounded_String (P);
      Is_Modified := False;
      Character.Recompute (The_Char);
      Show_All;
      Character.Free_All (Old);
   end Take;

   procedure Adopt (Cs : Character.Characters; Path : String) is
      Notices : constant Character.Text_Vectors.Vector := Character.Notices;
      R       : Unbounded_String;
   begin
      Take (Cs, Path);
      if not Notices.Is_Empty then
         R := To_Unbounded_String ("Numbers the file gives differently from the rules, kept as overrides:");
         for N of Notices loop
            Append (R, ASCII.LF & N);
         end loop;
         Say (To_String (R));
      end if;
   end Adopt;

   function Load (Path : String) return Boolean is
      Cs  : Character.Characters;
      Msg : Unbounded_String;
   begin
      if not Character.Load_All (Path, Cs, Msg) then
         Say (To_String (Msg));
         return False;
      end if;
      Adopt (Cs, Path);
      return True;
   end Load;

   --  Saves every character to P; False, said why, if it can't.  Each
   --  portrait's path, relative to the file, is rebased to P's directory
   --  first (Ova_Cg.Paths), and put back if the save fails.
   function Save_To (P : String) return Boolean is
      Old  : array (1 .. Count) of Unbounded_String;
      From : constant String := (if The_Path /= "" then Paths.Dir (To_String (The_Path)) else "");
      To   : constant String := Paths.Dir (P);
      Msg  : Unbounded_String;
   begin
      for I in Old'Range loop
         Old (I) := Chars (I).Portrait;
         Chars (I).Portrait := To_Unbounded_String (Paths.Rebase (To_String (Old (I)), From, To));
      end loop;
      if not Save.Save_All (Chars, P, Msg) then
         for I in Old'Range loop
            Chars (I).Portrait := Old (I);
         end loop;
         Say (To_String (Msg));
         return False;
      end if;
      The_Path := To_Unbounded_String (P);
      Is_Modified := False;
      Show_Title;
      Background.Set_Dir (To);
      return True;
   end Save_To;

   function Save_As return Boolean is
      P : Unbounded_String;
   begin
      return Choose_Path (True, P) and then Save_To (To_String (P));
   end Save_As;

   function Save_Now return Boolean is
     (if The_Path = "" then Save_As else Save_To (To_String (The_Path)));

   --  Whether the characters may be put away: saved, or the user doesn't
   --  want them saved.  The question names the file, or the character if
   --  it is the only one and has no file.
   function May_Leave return Boolean is
   begin
      if not Is_Modified then
         return True;
      end if;
      case Ask ("Save the changes to "
                & (if The_Path /= "" then File_Name
                   elsif Count > 1 then "the characters"
                   elsif The_Char.Name /= "" then To_String (The_Char.Name)
                   else "the character")
                & " first?")
      is
         when Save_First => return Save_Now;
         when Discard    => return True;
         when Cancel     => return False;
      end case;
   end May_Leave;

   procedure New_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if May_Leave then
         Take (Character.One (Character.New_Character), "");
      end if;
   end New_Action;

   procedure Open_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      P : Unbounded_String;
   begin
      if May_Leave and then Choose_Path (False, P) then
         declare
            Ignore : constant Boolean := Load (To_String (P));  --  a failure is said
         begin
            null;
         end;
      end if;
   end Open_Action;

   procedure Save_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Ignore : constant Boolean := Save_Now;  --  a failure is said
   begin
      null;
   end Save_Action;

   procedure Save_As_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      Ignore : constant Boolean := Save_As;  --  a failure is said
   begin
      null;
   end Save_As_Action;

   procedure Quit is
   begin
      if May_Leave then
         Open.Main.Hide;
      end if;
   end Quit;

   procedure Quit_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Quit;
   end Quit_Action;

   --  ---- Building ----

   procedure Label (X, Y, W : Integer; Text : String) is
      B : constant Box_Access := new Boxes.Box'(Boxes.Forge.Create (X, Y, W, Row_Height, Text));
   begin
      B.Set_Alignment (FLTK."+" (FLTK.Align_Left, FLTK.Align_Inside));
      B.Set_Label_Font (FLTK.Helvetica_Bold);
      Open.Labels.Append (B);
   end Label;

   procedure Heading (X, Y, W : Integer; Text : String; Left : Boolean := False) is
      B : constant Box_Access := new Boxes.Box'(Boxes.Forge.Create (X, Y, W, Row_Height, Text));
   begin
      if Left then
         B.Set_Alignment (FLTK."+" (FLTK.Align_Left, FLTK.Align_Inside));
      end if;
      Open.Labels.Append (B);
   end Heading;

   procedure Build_Sheet_Tab is
      Y, X : Integer;
   begin
      Open.Sheet_Tab := new Groups.Group'
        (Groups.Forge.Create (0, Bar_Height + Tab_Height, Width, Height - Bar_Height - Tab_Height, "Character"));
      Open.Sheet_Tab.Begin_Current;
      --  The column: names, Abilities, Weaknesses, totals, warnings,
      --  Combat Notes.
      Open.Name_In := Text_Input (Left_X + 110, Top, 250, "Character Name");
      Open.Player_In := Text_Input (Left_X + 460, Top, 160, "Player Name");
      Open.Tagline_In := Text_Input (Left_X + 110, Top + 30, 290, "Tagline");
      Open.NPC_Type_In := new Choices.Choice'
        (Choices.Forge.Create (Left_X + 470, Top + 30, 150, Row_Height, "NPC Type"));
      Open.NPC_Type_In.Add ("none", null);
      for K in Ova_Fmt.Entities.NPC_Kind loop
         Open.NPC_Type_In.Add (Rules.Page_Label (Ova_Fmt.Entities.NPC_Kind_Name (K), Rules.NPC_Types_Page),
                               null);
      end loop;
      Open.NPC_Type_In.Set_Callback (NPC_Type_Action'Access);
      Open.Abilities := Open_Trait_Panel (Left_X, Rules.Ability, "Abilities");
      Open.Weaknesses := Open_Trait_Panel (Left_X + 315, Rules.Weakness, "Weaknesses");
      Y := Open.Abilities.Bottom + 5;
      Open.Ability_Mods := new Buttons.Button'
        (Buttons.Forge.Create (Left_X, Y, 140, Row_Height, "Perks and Flaws..."));
      Open.Ability_Mods.Set_Callback (Mods_Action'Access);
      Open.Ability_Linked := new Buttons.Button'
        (Buttons.Forge.Create (Left_X + 305 + 10, Y, 140, Row_Height, "Linked..."));
      Open.Ability_Linked.Set_Callback (Linked_Action'Access);
      Open.Ability_End := Widgets.Open_Number_Box (Left_X + 190, Y, "END");
      Open.Ability_End.Set_Alignment (FLTK.Align_Left);
      Open.Ability_End.Changed := Number_Changed'Access;
      Y := Y + Row_Height + 25;
      Sheet_Box (Ability_Levels_Number, Left_X, Y, "Abilities");
      Sheet_Box (Weakness_Levels_Number, Left_X + 120, Y, "Weaknesses");
      Sheet_Box (Total_Number, Left_X + 240, Y, "Character Total");
      Sheet_Box (Ability_Points_Number, Left_X + 375, Y, "Ability points");
      Sheet_Box (Points_Number, Left_X + 500, Y, "Scaled Cost points");
      Y := Y + Row_Height + 25;
      Open.Warnings := new Hold.Hold_Browser'(Hold.Forge.Create (Left_X, Y, Column_W, 85, "Warnings"));
      Open.Warnings.Set_Alignment (FLTK.Align_Top_Left);
      Open.Warnings.Set_Format_Character (Standard.Character'Val (0));  --  names are text, never format codes
      Y := Y + 85 + 20;
      Open.Combat_Notes := new Multiline.Multiline_Input'
        (Multiline.Forge.Create (Left_X, Y, Column_W, Height - Y - 10, "Combat Notes"));
      Open.Combat_Notes.Set_Alignment (FLTK.Align_Top_Left);
      Open.Combat_Notes.Set_When (FLTK.When_Changed);
      Open.Combat_Notes.Set_Callback (Text_Action'Access);
      Open.Combat_Notes.Set_Wrap (True);
      Open.Sheet_Tab.End_Current;

      --  The second tab: the combat box and the sheet's numbers.
      Open.Attacks_Tab := new Groups.Group'
        (Groups.Forge.Create (0, Bar_Height + Tab_Height, Width, Height - Bar_Height - Tab_Height, "Attacks"));
      Open.Attacks_Tab.Begin_Current;
      Label (Left_X, Top, 200, "Attacks");
      X := Left_X + 2 + Name_W + 8;
      Y := Top + 25;
      Heading (Left_X + 2, Y, Name_W, "Name", Left => True);
      Heading (X, Y, Widgets.Width, "ROLL");
      Heading (X + Widgets.Width + 8, Y, Widgets.Width, "DX");
      Heading (X + 2 * (Widgets.Width + 8), Y, Widgets.Width, "END");
      Y := Y + Row_Height;
      Open.Attack_Box := new Scrolls.Scroll'
        (Scrolls.Forge.Create (Left_X, Y, Column_W, Attack_Rows * Row_Step + 4));
      Open.Attack_Box.Set_Kind (Scrolls.Vertical);
      Open.Attack_Box.Set_Box (FLTK.Down_Box);
      Y := Y + Attack_Rows * Row_Step + 10;
      Open.Add_Attack := new Buttons.Button'(Buttons.Forge.Create (Left_X, Y, 120, Row_Height, "Add attack..."));
      Open.Add_Attack.Set_Callback (Add_Attack_Action'Access);
      Y := Y + Row_Height + 30;
      Sheet_Box (Defense_Number, Left_X, Y, "DEFENSE");
      Sheet_Box (Barrier_Number, Left_X + 100, Y, "Barrier DEFENSE");
      Sheet_Box (Incorporeal_Number, Left_X + 100, Y + 50, "Incorporeal DEFENSE");
      Sheet_Box (Health_Number, Left_X + 220, Y, "HEALTH");
      Sheet_Box (Endurance_Number, Left_X + 320, Y, "ENDURANCE");
      Sheet_Box (Reserve_Number, Left_X + 420, Y, "Reserve");
      Sheet_Box (TV_Number, Left_X + 520, Y, "TV");
      Open.Attacks_Tab.End_Current;
   end Build_Sheet_Tab;

   procedure Build is
      use FLTK;
   begin
      Open.Main := new Windows.Double_Window'(Windows.Forge.Create (Width, Height, Title));
      Open.Main.Begin_Current;
      Open.Watch := new Watcher'(Watcher'(Boxes.Box'(Boxes.Forge.Create (0, 0, Width, Height)) with null record));
      Open.Watch.Hide;
      Open.Bar := new Bars.Menu_Bar'(Bars.Forge.Create (0, 0, Width - Choice_W, Bar_Height));
      declare
         B : Bars.Menu_Bar'Class renames Open.Bar.all;
         I : Places renames Open.Items;
      begin
         I.New_Item := B.Add ("&File/&New", New_Action'Access, Mod_Command + 'n');
         I.Open_Item := B.Add ("&File/&Open...", Open_Action'Access, Mod_Command + 'o');
         I.Save_Item := B.Add ("&File/&Save", Save_Action'Access, Mod_Command + 's');
         I.Save_As_Item := B.Add ("&File/Save &As...", Save_As_Action'Access, Mod_Command + Mod_Shift + 's',
                                  Flag_Divider);
         I.Quit_Item := B.Add ("&File/&Quit", Quit_Action'Access, Mod_Command + 'q');
         --  Ctrl+E: an input takes Ctrl+L as its own (AGENTS.md).
         I.Limits_Item := B.Add ("&Character/&Limits...", Limits_Action'Access, Mod_Command + 'e');
         I.Transformed_Item := B.Add ("&Character/&Transformed form", Transformed_Action'Access,
                                      Mod_Command + 't', Flag_Toggle + Flag_Divider);
         I.Add_Character_Item := B.Add ("&Character/&Add Character", Add_Character_Action'Access);
         I.Duplicate_Item := B.Add ("&Character/&Duplicate Character", Duplicate_Action'Access);
         I.Remove_Character_Item := B.Add ("&Character/&Remove Character...", Remove_Character_Action'Access,
                                           No_Key, Flag_Divider);
         I.Move_Up_Item := B.Add ("&Character/Move &Up", Move_Up_Action'Access);
         I.Move_Down_Item := B.Add ("&Character/Move Do&wn", Move_Down_Action'Access, No_Key, Flag_Divider);
         I.Next_Item := B.Add ("&Character/&Next Character", Next_Action'Access, Mod_Command + Page_Down_Key);
         I.Previous_Item := B.Add ("&Character/&Previous Character", Previous_Action'Access,
                                   Mod_Command + Page_Up_Key);
         I.Rulebook_Item := B.Add ("&Rulebook/&Open", Rulebook_Action'Access, No_Key, Flag_Divider);
         I.Choose_Pdf_Item := B.Add ("&Rulebook/&Choose PDF...", Choose_Pdf_Action'Access);
         I.Viewer_Item := B.Add ("&Rulebook/&Viewer...", Viewer_Action'Access);
      end;
      Open.Character_Choice := new Choices.Choice'
        (Choices.Forge.Create (Width - Choice_W, 0, Choice_W, Bar_Height));
      Open.Character_Choice.Set_Tooltip ("The character shown, of the file's");
      Open.Character_Choice.Set_Callback (Character_Choice_Action'Access);
      Open.Tabs := new Tabbed.Tabbed_Group'
        (Tabbed.Forge.Create (0, Bar_Height, Width, Height - Bar_Height));
      Open.Tabs.Begin_Current;
      Build_Sheet_Tab;
      Background.Build (0, Bar_Height + Tab_Height, Width, Height - Bar_Height - Tab_Height);
      Markdown_Tab.Build (0, Bar_Height + Tab_Height, Width, Height - Bar_Height - Tab_Height);
      Open.Tabs.End_Current;
      Open.Tabs.Set_Resizable (Open.Sheet_Tab.all);
      Open.Main.End_Current;
      Open.Main.Set_Resizable (Open.Tabs.all);
      Open.Main.Set_Size_Range (Width, Height);
      Open.Main.Set_Callback (Quit_Action'Access);  --  the close button
      Take (Character.One (Character.New_Character), "");
   end Build;

   procedure Close is
      procedure Free is new Ada.Unchecked_Deallocation (Texts.Text_Input'Class, Widgets.Input_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Choices.Choice'Class, Widgets.Choice_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Buttons.Button'Class, Widgets.Button_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Hold.Hold_Browser'Class, Widgets.Browser_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Multiline.Multiline_Input'Class, Multiline_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Boxes.Box'Class, Box_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Scrolls.Scroll'Class, Scroll_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Groups.Group'Class, Group_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Tabbed.Tabbed_Group'Class, Tabs_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Bars.Menu_Bar'Class, Bar_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Watcher'Class, Watcher_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Windows.Double_Window'Class, Window_Access);
   begin
      if Attack_Dialog.Dialog /= null then
         Attack_Dialog.Cancel;
      end if;
      if Linked_Dialog.Dialog /= null then
         Linked_Dialog.Close;
      end if;
      if Settings.Dialog /= null then
         Settings.Cancel;
      end if;
      Attack_Dialog.Free_Closed;
      Linked_Dialog.Free_Closed;
      Settings.Free_Closed;
      FLTK.Static.Remove_Timeout (Fit_Action'Access);
      FLTK.Static.Remove_Timeout (Rebuild_Action'Access);
      --  Children before their groups (AGENTS.md).
      Free_Rows;
      Free (Open.Name_In);
      Free (Open.Player_In);
      Free (Open.Tagline_In);
      Free (Open.NPC_Type_In);
      Trait_Panel.Free (Open.Abilities);
      Trait_Panel.Free (Open.Weaknesses);
      Free (Open.Ability_Mods);
      Free (Open.Ability_Linked);
      Widgets.Free (Open.Ability_End);
      for B of Open.Numbers loop
         Widgets.Free (B);
      end loop;
      Free (Open.Warnings);
      Free (Open.Combat_Notes);
      for B of Open.Labels loop
         Free (B);
      end loop;
      Open.Labels.Clear;
      Free (Open.Attack_Box);
      Free (Open.Add_Attack);
      Background.Close;
      Markdown_Tab.Close;
      Free (Open.Sheet_Tab);
      Free (Open.Attacks_Tab);
      Free (Open.Tabs);
      Free (Open.Bar);
      Free (Open.Character_Choice);
      Free (Open.Watch);
      Free (Open.Main);
      Open := (others => <>);
      Character.Free_All (Chars);
      The_Char := null;
      The_Path := Null_Unbounded_String;
      Is_Modified := False;
      Free_Root;
      Prefs := null;
   end Close;

begin
   Tell := Dialog_Tell'Access;
   Ask := Dialog_Ask'Access;
   Choose_Path := Dialog_Path'Access;
   Confirm := Dialog_Confirm'Access;
   Choose_Pdf := Dialog_Pdf'Access;
   Ask_Text := Dialog_Text'Access;
   Widgets.Open_Page := Open_Page'Access;
   Trait_Panel.Tell := Say'Access;
   Attack_Dialog.Tell := Say'Access;
   Linked_Dialog.Tell := Say'Access;
   Background.Tell := Say'Access;
   Markdown_Tab.Tell := Say'Access;
   Background.Changed := Background_Changed'Access;
   Linked_Dialog.Changed := Changed'Access;
   Settings.Changed := Limits_Changed'Access;
   Ova_Cg.Viewer.Default (Viewer);
end Ova_Cg.Window;
