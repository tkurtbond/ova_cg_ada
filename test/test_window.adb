--  Ova_Cg.Window: the first tab, driven as a user would, and its files.
--
--  Needs a display: run by make test-gui, under make test-headless or
--  make test-sway (AGENTS.md: never on the desktop).  Widgets are
--  driven directly: a value set, then Do_Callback; a menu item picked.
--  What would wait for the user (a message, a question, a file chooser,
--  the rulebook) is answered by the subprograms here.
--
--  PLAN.md, Phase 5: the model, the numbers shown, and the page beside
--  every name shown; an override changes what is shown, saved, and
--  computed from it, and clearing it undoes that.

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with System;
with Check;
with FLTK;
with FLTK.Menu_Items;
with Ova_Cg.Attack_Dialog;
with Ova_Cg.Background;
with Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Markdown_Tab;
with Ova_Cg.Rules;
with Ova_Cg.Save;
with Ova_Cg.Trait_Panel;
with Ova_Cg.Widgets;
with Ova_Cg.Window;
with Ova_Fmt.Entities;

procedure Test_Window is

   use Ova_Cg;

   package Ch renames Ova_Cg.Character;
   package AD renames Ova_Cg.Attack_Dialog;
   package E renames Ova_Fmt.Entities;

   use type Calc.Attack, Calc.Modifier, Calc.Sheet_Kind, Calc.Trait, Rules.Item, Rules.Kind, Ch.Character_Access, Ch.Trait,
     AD.Window_Access, E.NPC_Kind, System.Address;

   Save_Path : constant String := "../obj/window.yaml";
   Tab       : constant Standard.Character := ASCII.HT;

   Tells     : Natural := 0;                   --  how many messages were shown
   Answer    : Window.Answer := Window.Cancel;  --  what Ask answers,
   Asked     : Natural := 0;                   --  and how often it was asked
   Question  : Unbounded_String;               --  what Ask or Confirm asked last
   Yes       : Boolean := False;               --  what Confirm answers,
   Confirmed : Natural := 0;                   --  and how often it was asked
   Chosen    : Unbounded_String;               --  what Choose_Path answers; "": cancelled
   Page      : Natural := 0;                   --  the last page Open_Page was asked for
   --  Changed by the handlers, through the window's callbacks, where
   --  the compiler can't see it.
   pragma Volatile (Tells);
   pragma Volatile (Asked);
   pragma Volatile (Confirmed);
   pragma Volatile (Page);

   C      : Ch.Character_Access;
   T      : Ch.Trait;
   R      : Window.Attack_Row_Access;
   A      : Calc.Attack;
   Text   : Unbounded_String;
   I, N   : Natural;
   Before : Integer;
   OK     : Boolean;

   --  ---- What would wait for the user ----

   procedure Tell (Text : String) is
   begin
      Tells := Tells + 1;
      Ada.Text_IO.Put_Line ("    told: " & Text);
   end Tell;

   function Ask (Q : String) return Window.Answer is
   begin
      Asked := Asked + 1;
      Question := To_Unbounded_String (Q);
      return Answer;
   end Ask;

   function Confirm (Q, Button : String) return Boolean is
      pragma Unreferenced (Button);
   begin
      Confirmed := Confirmed + 1;
      Question := To_Unbounded_String (Q);
      return Yes;
   end Confirm;

   function Choose_Path (Save : Boolean; P : out Unbounded_String) return Boolean is
      pragma Unreferenced (Save);
   begin
      P := Chosen;
      return Chosen /= Null_Unbounded_String;
   end Choose_Path;

   procedure Open_Page (P : Positive) is
   begin
      Page := P;
   end Open_Page;

   --  ---- Driving and looking ----

   procedure Show_It is
   begin
      Window.Main.Show;
      Window.Main.Wait_For_Expose;
      OK := FLTK.Check;
   end Show_It;

   --  Lets FLTK run what it put off: timers.
   procedure Settle is
      Ignored : Long_Float;
   begin
      for I in 1 .. 5 loop
         Ignored := FLTK.Wait (0.01);
      end loop;
   end Settle;

   function Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   --  A, B and C joined by tabs, as a browser's columns; C "" for two.
   function Columns (A, B, C : String) return String is
     (A & Tab & B & (if C /= "" then Tab & C else ""));

   --  The computed number of N, whatever its override.
   function Computed (N : Calc.Number) return Integer is (Integer'Value (Calc.Computed_Text (N)));

   --  Whether box B shows N: its computed number, and its override or
   --  "".
   function Shows (B : Widgets.Number_Box_Access; N : Calc.Number) return Boolean is
     (B.Shown.Get_Value = Calc.Computed_Text (N)
      and then B.Entry_In.Get_Value = (if Calc.Overridden (N) then Calc.Text (N) else ""));

   function Num (W : Window.Sheet_Number) return Widgets.Number_Box_Access renames Window.Number;

   --  Whether every number box of the sheet and the combat box shows the
   --  model's number.
   function All_Shown return Boolean is
      use Window;
      C  : constant Ch.Character_Access := The_Character;
      OK : Boolean :=
        Shows (Num (Defense_Number), C.Defense) and then Shows (Num (Barrier_Number), C.Barrier)
        and then Shows (Num (Health_Number), C.Health) and then Shows (Num (Endurance_Number), C.Endurance)
        and then Shows (Num (Reserve_Number), C.Reserve) and then Shows (Num (TV_Number), C.TV)
        and then Shows (Num (Ability_Levels_Number), C.Ability_Levels)
        and then Shows (Num (Weakness_Levels_Number), C.Weakness_Levels)
        and then Shows (Num (Total_Number), C.Total) and then Shows (Num (Points_Number), C.Points)
        and then Shows (Num (Incorporeal_Number), C.Incorporeal)
        and then Shows (Num (Ability_Points_Number), C.Ability_Points);
   begin
      for I in 1 .. Row_Count loop
         exit when not OK;
         declare
            R : constant Attack_Row_Access := Row (I);
         begin
            OK := Shows (R.Roll, R.Attack.Roll) and then Shows (R.DX, R.Attack.DX)
              and then Shows (R.End_Box, R.Attack.End_Cost);
         end;
      end loop;
      return OK;
   end All_Shown;

   --  Whether P's browser has a line for each trait of its kind, in the
   --  model's order: "+2 Flight (on a broom)", a tab, and its page.
   function List_Shown (P : Trait_Panel.Trait_Panel_Access) return Boolean is
      L  : Calc.Trait := Window.The_Character.Traits;
      N  : Natural := 0;
      OK : Boolean := True;
   begin
      while OK and then L /= null loop
         if L.Of_Kind = P.Kind then
            N := N + 1;
            if N > P.Browser.Number_Of_Lines then
               OK := False;
            else
               declare
                  X    : constant Ch.Trait := Ch.Trait (L);
                  Line : constant String := P.Browser.Get_Line_Text (N);
                  Want : Unbounded_String :=
                    To_Unbounded_String ((if X.Level > 0 then "+" else "") & Image (X.Level) & " ") & X.Name;
               begin
                  if X.Has_Detail then
                     Append (Want, " (" & X.Detail & ")");
                  end if;
                  Append (Want, Tab);
                  if Trait_Panel.Shows_Points (P.all) then
                     Append (Want, Image (X.Points) & (if X.Points = 1 then " pt" else " pts") & Tab);
                  end if;
                  Append (Want, Rules.Page_Text (X.Item));
                  OK := Line = To_String (Want);
                  if not OK then
                     Ada.Text_IO.Put_Line ("    line " & Image (N) & ": " & Line);
                  end if;
               end;
            end if;
         end if;
         L := L.Next;
      end loop;
      return OK and then N = P.Browser.Number_Of_Lines;
   end List_Shown;

   --  Whether every name in P's Choice is its item's label, with its
   --  page.
   function Choice_Labelled (P : Widgets.Panel'Class) return Boolean is
      OK : Boolean := True;
   begin
      for I in 0 .. Rules.Count (P.Kind) - 1 loop
         OK := OK and then P.Choice.Get_Label (I + 1) = Rules.Label (Rules.Get (P.Kind, I));
      end loop;
      return OK;
   end Choice_Labelled;

   --  Types S into box B and leaves it.
   procedure Type_In (B : Widgets.Number_Box_Access; S : String) is
   begin
      B.Entry_In.Set_Value (S);
      B.Entry_In.Do_Callback;
   end Type_In;

   --  Chooses Name in P's Choice, as the user does.
   procedure Pick (P : in out Widgets.Panel'Class; Name : String) is
      It : constant Rules.Item := Rules.Find (Name);
   begin
      pragma Assert (It /= null);
      Widgets.Choose (P, It);
      P.Choice.Do_Callback;
   end Pick;

   --  Selects P's line, as a click does.
   procedure Select_Line (P : Widgets.Panel'Class; Line : Natural) is
   begin
      P.Browser.Set_Select (Line => Line);
      P.Browser.Do_Callback;
   end Select_Line;

   --  The last line of browser B holding S; 0 if none.
   function Line_With (B : Widgets.Browser_Access; S : String) return Natural is
   begin
      for I in reverse 1 .. B.Number_Of_Lines loop
         if Ada.Strings.Fixed.Index (B.Get_Line_Text (I), S) > 0 then
            return I;
         end if;
      end loop;
      return 0;
   end Line_With;

   function Selected (P : Widgets.Panel'Class) return String is
     (if P.Browser.Selected_Index > 0 then P.Browser.Get_Line_Text (P.Browser.Selected_Index) else "");

   --  The trait named Name; null if none.
   function Trait_Named (Name : String) return Ch.Trait is
      L : Calc.Trait := Window.The_Character.Traits;
   begin
      while L /= null and then Ch.Trait (L).Name /= Name loop
         L := L.Next;
      end loop;
      return (if L = null then null else Ch.Trait (L));
   end Trait_Named;

   function Saved return String is (Save.To_Text (Window.The_Character));

   --  Every character of the file, as saved.
   function All_Saved return String is
      Cs : Ch.Characters;
   begin
      for I in 1 .. Window.Count loop
         Cs.Append (Window.Character_At (I));
      end loop;
      return Save.All_To_Text (Cs);
   end All_Saved;

   function Has (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);

   function Title return String is (Window.Main.Get_Label);

   function Last_Row return Window.Attack_Row_Access is (Window.Row (Window.Row_Count));

   --  Whether the Choice of characters lists Labels, "|" between them,
   --  and shows the one shown.
   function Listed (Labels : String) return Boolean is
      L : Unbounded_String;
   begin
      for I in 1 .. Window.Count loop
         if I > 1 then
            Append (L, "|");
         end if;
         Append (L, String'(Window.Character_Choice.Get_Label (I)));
      end loop;
      return L = Labels and then Window.Character_Choice.Chosen_Index = Window.Current
        and then Window.The_Character = Window.Character_At (Window.Current);
   end Listed;

   --  Whether item I of the menu bar is active.
   function Active (I : Window.Item_Index) return Boolean is (not Window.Bar.Get_Flags (I).Inactive);

   --  Whether the window shows the character shown: its name, and every
   --  number.
   function Shown_Now (Name : String) return Boolean is
     (Window.Name_In.Get_Value = Name and then All_Shown);

   function Load (Name : String) return Boolean is (Window.Load ("data/" & Name));

   procedure Pick_Item (Item : Window.Item_Index) is
   begin
      Window.Bar.Picked (FLTK.Menu_Items.Menu_Item (Window.Bar.Item (Item).Data.all));
   end Pick_Item;

   --  Chooses item Place (from 1) of Choice, as the user does.
   procedure Choose (Choice : Widgets.Choice_Access; Place : Positive) is
   begin
      Choice.Set_Chosen (Place => Place);
      Choice.Do_Callback;
   end Choose;

   procedure Set_Name (S : String) is
   begin
      Window.Name_In.Set_Value (S);
      Window.Name_In.Do_Callback;
   end Set_Name;

   function Name_Is (S : String) return Boolean is (Window.The_Character.Name = S);

   --  The NPC type K's item in the NPC type's Choice: after none.
   function NPC_Item (K : E.NPC_Kind) return Positive is (2 + E.NPC_Kind'Pos (K));

begin
   Window.Build;
   Window.Tell := Tell'Unrestricted_Access;
   Window.Ask := Ask'Unrestricted_Access;
   Window.Choose_Path := Choose_Path'Unrestricted_Access;
   Window.Confirm := Confirm'Unrestricted_Access;
   Widgets.Open_Page := Open_Page'Unrestricted_Access;

   --  ---- The frame ----
   declare
      use type Window.Window_Access;
   begin
      Check.Check (Window.Main /= null and then not Window.Main.Is_Shown, "the window opens, not shown until asked");
   end;
   I := Window.Bar.Find_Index ("&File/&Quit");
   Check.Check (I > 0 and then I = Window.Quit_Item, "the menu bar has File > Quit");
   Check.Check (Window.Bar.Find_Index ("&File/&New") = Window.New_Item
                and then Window.Bar.Find_Index ("&File/&Open...") = Window.Open_Item
                and then Window.Bar.Find_Index ("&File/&Save") = Window.Save_Item
                and then Window.Bar.Find_Index ("&File/Save &As...") = Window.Save_As_Item
                and then Window.Bar.Find_Index ("&Rulebook/&Open") = Window.Rulebook_Item,
                "and New, Open, Save, Save As, and Rulebook > Open");
   Check.Check (Window.Tabs.Get_Visible.all'Address = Window.Sheet_Tab.all'Address,
                "the Character tab is shown first");
   Check.Check (Window.Main.Get_W = 640 and then Window.Tabs.Number_Of_Children = 5
                and then Window.Tabs.Find (Window.Sheet_Tab.all) = 1
                and then Window.Tabs.Find (Window.Attacks_Tab.all) = 2
                and then Window.Tabs.Find (Background.Background_Tab.all) = 3
                and then Window.Tabs.Find (Background.Fluff_Tab.all) = 4
                and then Window.Tabs.Find (Markdown_Tab.Tab.all) = 5,
                "640 wide, beside the viewer: Character, Attacks, Background, Fluff and Markdown, in that order");
   Check.Check (Window.Attacks_Tab.Find (Window.Add_Attack.all) > 0
                and then Window.Sheet_Tab.Find (Window.Add_Attack.all) = 0
                and then Background.Fluff_Tab.Find (Background.Portrait.all) > 0
                and then Background.Background_Tab.Find (Background.Portrait.all) = 0,
                "the attacks on the Attacks tab, the portrait on the Fluff tab");
   Check.Check (Choice_Labelled (Window.Abilities.all) and then Choice_Labelled (Window.Weaknesses.all),
                "every name in the Choices has its page: Attack (p. 50)");
   Pick_Item (Window.Rulebook_Item);
   Check.Check (Page = 1, "Rulebook > Open opens it at page 1");
   Show_It;

   --  ---- A character loaded ----
   OK := Load ("Ai.yaml");
   Check.Check (OK and then Tells = 0, "Ai.yaml loads, with nothing to say");
   Check.Check (Window.Name_In.Get_Value = "Ai", "the name is shown");
   Check.Check (Title = "OVA Character Generator - Ai.yaml", "the title is the file's name");
   Check.Check (List_Shown (Window.Abilities) and then List_Shown (Window.Weaknesses),
                "every Ability and Weakness is listed with its page");
   Check.Check (All_Shown, "every number shown is the model's");
   Check.Check (Num (Window.Barrier_Number).Is_Visible and then not Num (Window.Reserve_Number).Is_Visible
                and then not Num (Window.Points_Number).Is_Visible
                and then not Num (Window.Incorporeal_Number).Is_Visible
                and then not Num (Window.Ability_Points_Number).Is_Visible,
                "Barrier DEFENSE shown, for Barrier; the Reserve, the Scaled Cost points and Incorporeal DEFENSE not");
   Check.Check (Window.Row_Count = 2, "a row in the combat box for each attack");
   R := Window.Row (1);
   Check.Check (R.Name.Get_Value = "Telekinetic Push", "the first is Telekinetic Push");

   --  ---- Overrides ----
   C := Window.The_Character;
   N := Computed (C.Health);
   Check.Check (not Calc.Overridden (C.Health) and then not Has (Saved, "overrides"), "Ai has no overrides");
   Type_In (Num (Window.Health_Number), "55");
   Check.Check (Calc.Overridden (C.Health) and then Calc.Value (C.Health) = 55 and then Computed (C.Health) = N,
                "an override: HEALTH 55, the computed number kept");
   Check.Check (All_Shown, "and shown, beside the computed number");
   Check.Check (Window.Modified, "a change marks the character modified");
   Check.Check (Title = "OVA Character Generator - Ai.yaml *", "and the title says so");
   Check.Check (Has (Saved, "health: 55") and then Has (Saved, "overrides"), "saved: health 55, in overrides");
   Type_In (Num (Window.Health_Number), "");
   Check.Check (not Calc.Overridden (C.Health) and then Calc.Value (C.Health) = N and then All_Shown,
                "an empty box: the computed number again");
   Check.Check (not Has (Saved, "overrides"), "and no override saved");
   Type_In (Num (Window.Health_Number), "55");
   Tells := 0;
   Type_In (Num (Window.Health_Number), "lots");
   Check.Check (Tells = 1 and then not Calc.Overridden (C.Health) and then All_Shown,
                "text that isn't a number: said so, and the box emptied");
   Type_In (R.DX, "1/2");
   Check.Check (Calc.Overridden (R.Attack.DX) and then Calc.Half (R.Attack.DX) and then All_Shown,
                "a DX may be 1/2");
   Tells := 0;
   Type_In (Num (Window.Health_Number), "1/2");
   Check.Check (Tells = 1 and then not Calc.Overridden (C.Health), "HEALTH may not");
   Type_In (R.DX, "");

   --  An override counts in what is computed from it: Braun's TV comes
   --  from his ROLL, overridden to -2.
   OK := Load ("Braun.yaml");
   C := Window.The_Character;
   R := Window.Row (1);
   Check.Check (OK and then Calc.Overridden (R.Attack.Roll) and then Calc.Value (R.Attack.Roll) = -2
                and then Calc.Value (C.TV) = 0,
                "Braun: ROLL -2, overridden, and TV 0");
   Type_In (R.Roll, "");
   Check.Check (not Calc.Overridden (R.Attack.Roll) and then Calc.Value (C.TV) /= 0 and then All_Shown,
                "ROLL's override cleared: TV computed from the rules' ROLL");
   Type_In (R.Roll, "-2");
   Check.Check (Calc.Value (C.TV) = 0 and then All_Shown, "and set again: TV 0 again");

   --  A name the rulebook's lists don't have: "p. ?", and a warning that
   --  says so.  Adopt frees the characters it replaces, so the trait
   --  goes into a copy.
   C := Save.Copy (Window.The_Character);
   T := Ch.New_Trait (null, Rules.Ability, 1, To_Unbounded_String ("Magic, Testing"), Null_Unbounded_String);
   Ch.Insert_Trait (C.Traits, T);
   Window.Adopt (Ch.One (C), "");
   I := Line_With (Window.Abilities.Browser, "Magic, Testing");
   Check.Check ((if I > 0 then Window.Abilities.Browser.Get_Line_Text (I) else "")
                  = Columns ("+1 Magic, Testing", "p. ?", "")
                and then List_Shown (Window.Abilities),
                "an unknown name: listed with p. ?");
   I := Line_With (Window.Warnings, "Magic, Testing");
   Check.Check ((if I > 0 then Window.Warnings.Get_Line_Text (I) else "")
                  = "Magic, Testing (p. ?) isn't in the rulebook's lists",
                "and a warning, with p. ?");

   Tells := 0;
   OK := Load ("Wisp.yaml");
   Check.Check (OK and then Tells = 0 and then Num (Window.Incorporeal_Number).Is_Visible
                and then not Num (Window.Barrier_Number).Is_Visible and then All_Shown,
                "Wisp.yaml: Incorporeal DEFENSE shown, its 6, and Barrier DEFENSE not");

   --  ---- Abilities and Weaknesses ----
   OK := Load ("Ai.yaml");
   C := Window.The_Character;
   Before := Computed (C.Ability_Levels);
   Pick (Window.Abilities.all, "Flight");
   Check.Check (Window.Abilities.Help.Page = 54, "choosing Flight turns ? to its page, 54");
   Window.Abilities.Help.Do_Callback;
   Check.Check (Page = 54, "and ? opens the rulebook there");
   Window.Abilities.Spinner.Set_Value (2.0);
   Window.Abilities.Text.Set_Value ("on a broom");
   Window.Abilities.Add_Button.Do_Callback;
   Check.Check (Selected (Window.Abilities.all) = Columns ("+2 Flight (on a broom)", "p. 54", ""),
                "Add: its line selected, with its page");
   Check.Check (Computed (C.Ability_Levels) = Before + 2 and then All_Shown,
                "and counted: the Abilities' levels +2");
   Check.Check (List_Shown (Window.Abilities), "the list in the model's order");
   Window.Abilities.Spinner.Set_Value (4.0);
   Window.Abilities.Change_Button.Do_Callback;
   Check.Check (Selected (Window.Abilities.all) = Columns ("+4 Flight (on a broom)", "p. 54", "")
                and then Computed (C.Ability_Levels) = Before + 4 and then List_Shown (Window.Abilities),
                "Change: Flight +4");
   Window.Abilities.Remove_Button.Do_Callback;
   Check.Check (Computed (C.Ability_Levels) = Before and then List_Shown (Window.Abilities)
                and then Window.Abilities.Browser.Selected_Index = 0 and then Trait_Named ("Flight") = null,
                "Remove");
   N := Window.Abilities.Browser.Number_Of_Lines;
   Window.Abilities.Remove_Button.Do_Callback;
   Check.Check (Window.Abilities.Browser.Number_Of_Lines = N, "Remove with nothing selected removes nothing");

   Pick (Window.Weaknesses.all, "Endurance Use");
   Window.Weaknesses.Spinner.Set_Value (-2.0);
   Window.Weaknesses.Text.Set_Value ("Telekinesis");
   Window.Weaknesses.Add_Button.Do_Callback;
   Check.Check (Selected (Window.Weaknesses.all) = Columns ("-2 Endurance Use (Telekinesis)", "p. 70", "")
                and then List_Shown (Window.Weaknesses),
                "a Weakness added: Endurance Use -2 on Telekinesis");
   T := Trait_Named ("Telekinesis");
   Select_Line (Window.Abilities.all, Line_With (Window.Abilities.Browser, "Telekinesis"));
   Check.Check (Window.Ability_End.Shown.Get_Value = "10" and then Window.Ability_End.Is_Active
                and then Shows (Window.Ability_End, T.End_Cost),
                "Telekinesis selected: its END, 10, shown, with its box");
   Check.Check (Window.Abilities.Help.Page = 62, "and ? at its page, 62");
   Type_In (Window.Ability_End, "15");
   Check.Check (Calc.Overridden (T.End_Cost) and then Calc.Value (T.End_Cost) = 15
                and then Shows (Window.Ability_End, T.End_Cost),
                "its END overridden");
   Type_In (Window.Ability_End, "");

   --  ---- An Ability's Perks and Flaws ----
   Window.Ability_Mods.Do_Callback;
   Check.Check (AD.Dialog /= null, "Perks and Flaws... opens the dialog");
   Check.Check (Choice_Labelled (AD.Perks.all) and then Choice_Labelled (AD.Flaws.all),
                "every Perk and Flaw in its Choice has its page");
   Pick (AD.Perks.all, "Area Effect");
   AD.Perks.Add_Button.Do_Callback;
   N := Calc.Value (T.End_Cost);
   Check.Check (T.Mods /= null and then N > 10 and then Shows (AD.End_Box, T.End_Cost),
                "a Perk: the Ability's END goes up, shown in the dialog");
   AD.Cancel;
   Check.Check (AD.Dialog = null and then T.Mods = null and then Calc.Value (T.End_Cost) = 10
                and then Shows (Window.Ability_End, T.End_Cost),
                "Cancel: the Perk taken out again");
   Window.Ability_Mods.Do_Callback;
   Pick (AD.Perks.all, "Area Effect");
   AD.Perks.Add_Button.Do_Callback;
   AD.OK;
   Check.Check (AD.Dialog = null and then Calc.Value (T.End_Cost) = N and then Shows (Window.Ability_End, T.End_Cost)
                and then All_Shown,
                "OK: kept, and shown in the window");

   --  ---- Attacks ----
   N := Window.Row_Count;
   Window.Add_Attack.Do_Callback;
   Check.Check (AD.Dialog /= null, "Add attack... opens the dialog");
   AD.Name_In.Set_Value ("Wind Lance");
   Pick (AD.Perks.all, "Accurate");
   AD.Perks.Spinner.Set_Value (2.0);
   AD.Perks.Add_Button.Do_Callback;
   Check.Check (Selected (AD.Perks.all) = Columns ("Accurate x2", "+10", "p. 83"),
                "a Perk listed: its count, cost and page");
   Pick (AD.Flaws.all, "Cancel");
   Check.Check (AD.Flaws.Text.Get_Value = "-20", "Cancel's cost offered: its least, -20");
   AD.Flaws.Text.Set_Value ("-15");
   AD.Flaws.Add_Button.Do_Callback;
   Check.Check (Selected (AD.Flaws.all) = Columns ("Cancel", "-15", "p. 87"), "a Flaw listed, with the cost chosen");
   A := C.Attacks;  --  its row comes with OK
   while A.Next /= null loop
      A := A.Next;
   end loop;
   Check.Check (Shows (AD.Roll, A.Roll) and then Shows (AD.End_Box, A.End_Cost),
                "the dialog's numbers are the attack's, as it changes");
   Tells := 0;
   AD.Flaws.Text.Set_Value ("a lot");
   AD.Flaws.Change_Button.Do_Callback;
   Check.Check (Tells = 1, "a cost that isn't a number: said so");
   AD.OK;
   Check.Check (Window.Row_Count = N + 1, "OK: a row for the new attack");
   R := Last_Row;
   Check.Check (R.Name.Get_Value = "Wind Lance" and then All_Shown, "its name and numbers");
   Text := To_Unbounded_String (Saved);
   Check.Check (Has (To_String (Text), "Wind Lance") and then Has (To_String (Text), "counts-as: 2")
                and then Has (To_String (Text), "cost: -15"),
                "saved with its Perks and Flaws");
   R.Edit.Do_Callback;
   Select_Line (AD.Perks.all, 1);
   AD.Perks.Remove_Button.Do_Callback;
   Check.Check (AD.Perks.Browser.Number_Of_Lines = 0 and then not Has (Saved, "counts-as: 2"),
                "Edit: a Perk removed");
   AD.Cancel;
   Check.Check (Saved = Text and then Window.Row_Count = N + 1 and then All_Shown, "Cancel: the attack as it was");
   Window.Add_Attack.Do_Callback;
   AD.Cancel;
   Check.Check (Window.Row_Count = N + 1 and then Saved = Text, "Cancel on a new attack: no attack added");
   Window.Add_Attack.Do_Callback;
   AD.Name_In.Set_Value (" ");
   Tells := 0;
   AD.OK;
   Check.Check (Tells = 1 and then AD.Dialog /= null, "OK with no name: said so, and the dialog stays");
   AD.Cancel;
   Last_Row.Remove.Do_Callback;
   Settle;
   Check.Check (Window.Row_Count = N and then not Has (Saved, "Wind Lance") and then All_Shown,
                "Remove: the row and the attack gone");

   --  ---- Names and notes ----
   Window.Player_In.Set_Value ("Sam");
   Window.Player_In.Do_Callback;
   Window.Combat_Notes.Set_Value ("Down to 10 HEALTH.");
   Window.Combat_Notes.Do_Callback;
   Check.Check (Has (Saved, "player: Sam") and then Has (Saved, "Down to 10 HEALTH."),
                "the player and Combat Notes saved");

   --  ---- The NPC type (p. 123-124) ----
   C := Window.The_Character;
   Check.Check (Window.NPC_Type_In.Chosen_Index = 1 and then Window.NPC_Type_In.Get_Label (1) = "none"
                and then Window.NPC_Type_In.Get_Label (3) = "Secondary (p. 123)",
                "the NPC type: none, each type with its page");
   Choose (Window.NPC_Type_In, NPC_Item (E.Secondary));
   Check.Check (C.Has_NPC_Type and then C.NPC_Type = E.Secondary and then C.Of_Kind = Calc.Companion_Sheet
                and then Calc.Value (C.Health) < 40 and then All_Shown and then Has (Saved, "npc-type: Secondary"),
                "Secondary chosen: a Companion's sheet, shown, and saved");
   Choose (Window.NPC_Type_In, NPC_Item (E.Extra));
   Check.Check (C.Of_Kind = Calc.Extra_Sheet and then Calc.Value (C.TV) = 1 and then All_Shown
                and then Has (Saved, "npc-type: Extra"),
                "Extra chosen: TV 1");
   Choose (Window.NPC_Type_In, 1);
   Check.Check (not C.Has_NPC_Type and then C.Of_Kind = Calc.Character_Sheet and then All_Shown
                and then not Has (Saved, "npc-type"),
                "none chosen: a character's sheet, no npc-type saved");

   --  ---- Files ----
   Chosen := To_Unbounded_String (Save_Path);
   Pick_Item (Window.Save_As_Item);
   Check.Check (not Window.Modified and then Title = "OVA Character Generator - window.yaml",
                "Save As: saved, the title its name");
   --  Load frees the character it replaces: what it saved is kept to
   --  compare.
   Text := To_Unbounded_String (Saved);
   Tells := 0;
   OK := Window.Load (To_String (Chosen));
   Check.Check (OK and then Tells = 0 and then Saved = Text, "loaded again: the same, with nothing to say");
   Asked := 0;
   Pick_Item (Window.New_Item);
   Check.Check (Asked = 0 and then Name_Is ("") and then Window.Abilities.Browser.Number_Of_Lines = 0
                and then Window.Row_Count = 0 and then All_Shown,
                "New: nothing unsaved, nothing asked, an empty sheet");
   Set_Name ("Someone");
   Check.Check (Name_Is ("Someone") and then Window.Modified, "a name typed");
   Answer := Window.Cancel;
   Pick_Item (Window.New_Item);
   Check.Check (Asked = 1 and then Name_Is ("Someone"), "New with changes: asked; Cancel keeps them");
   Pick_Item (Window.Quit_Item);
   Check.Check (Asked = 2 and then Window.Main.Is_Shown, "Quit with changes: asked; Cancel stays");
   Answer := Window.Discard;
   Pick_Item (Window.Quit_Item);
   OK := FLTK.Check;
   Check.Check (Asked = 3 and then not Window.Main.Is_Shown, "Don't save: the window goes, which ends Fl.Run");
   Show_It;
   Window.Main.Do_Callback;  --  what the window's close button does
   OK := FLTK.Check;
   Check.Check (Asked = 4 and then not Window.Main.Is_Shown, "the close button asks too");

   --  ---- A Sample NPC loaded ----
   Tells := 0;
   OK := Load ("Jiro.yaml");
   Check.Check (OK and then Tells = 0 and then Window.NPC_Type_In.Chosen_Index = NPC_Item (E.Secondary)
                and then All_Shown,
                "Jiro.yaml: his type shown, and his numbers the rules' for it, so nothing to say");

   --  ---- Several characters in a file ----
   Tells := 0;
   OK := Load ("Acacia.yaml");
   Check.Check (OK and then Tells = 1 and then Window.Count = 3 and then Window.Current = 1
                and then Title = "OVA Character Generator - Acacia.yaml (1 of 3)" and then Shown_Now ("Acacia"),
                "Acacia.yaml: her and her demons, the first shown, the title saying which of how many");
   Check.Check (Listed ("1. Acacia|2. Sazza and Fraz|3. High Fructo Cezar"),
                "the Choice beside the menus lists them, by number and name, the first chosen");
   Check.Check (not Active (Window.Previous_Item) and then not Active (Window.Move_Up_Item)
                and then Active (Window.Next_Item) and then Active (Window.Move_Down_Item)
                and then Active (Window.Remove_Character_Item),
                "Previous and Move Up inactive at the first; Next, Move Down and Remove active");
   Choose (Window.Character_Choice, 3);
   Check.Check (Window.Current = 3 and then Shown_Now ("High Fructo Cezar") and then not Window.Modified
                and then Title = "OVA Character Generator - Acacia.yaml (3 of 3)"
                and then not Active (Window.Next_Item) and then not Active (Window.Move_Down_Item)
                and then Active (Window.Previous_Item),
                "the third chosen: shown, nothing changed, Next and Move Down inactive at the last");
   Pick_Item (Window.Previous_Item);
   Check.Check (Window.Current = 2 and then Shown_Now ("Sazza and Fraz")
                and then Listed ("1. Acacia|2. Sazza and Fraz|3. High Fructo Cezar"),
                "Character > Previous Character: the second");
   Pick_Item (Window.Next_Item);
   Check.Check (Window.Current = 3 and then Shown_Now ("High Fructo Cezar"), "Next Character: the third again");
   Set_Name ("Cezar");
   Check.Check (Listed ("1. Acacia|2. Sazza and Fraz|3. Cezar") and then Window.Modified
                and then Title = "OVA Character Generator - Acacia.yaml (3 of 3) *",
                "renamed: the Choice follows, the file modified");

   Pick_Item (Window.Add_Character_Item);
   Check.Check (Window.Count = 4 and then Window.Current = 4 and then Shown_Now ("")
                and then Window.Abilities.Browser.Number_Of_Lines = 0 and then Window.Row_Count = 0
                and then Listed ("1. Acacia|2. Sazza and Fraz|3. Cezar|4. (no name)"),
                "Character > Add Character: a new one, last, shown");
   Set_Name ("Imp & Co");
   Check.Check (Listed ("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Imp && Co"),
                "an & in a name doubled, so FLTK shows it");

   Choose (Window.Character_Choice, 1);
   Pick_Item (Window.Duplicate_Item);
   C := Window.The_Character;
   Check.Check (Window.Count = 5 and then Window.Current = 5 and then Shown_Now ("Acacia")
                and then C /= Window.Character_At (1)
                and then Save.To_Text (C) = Save.To_Text (Window.Character_At (1)),
                "Duplicate Character: a copy of Acacia, last, shown, the same when saved");
   Type_In (Num (Window.Health_Number), "55");
   Check.Check (Calc.Overridden (C.Health) and then not Calc.Overridden (Window.Character_At (1).Health),
                "the copy's HEALTH overridden, the first's not: they share nothing");
   Pick_Item (Window.Move_Up_Item);
   Check.Check (Window.Current = 4 and then Window.Character_At (4) = C
                and then Title = "OVA Character Generator - Acacia.yaml (4 of 5) *"
                and then Listed ("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Acacia|5. Imp && Co")
                and then Shown_Now ("Acacia"),
                "Move Up: the copy fourth, still shown");
   Pick_Item (Window.Move_Down_Item);
   Check.Check (Window.Current = 5 and then Window.Character_At (5) = C
                and then Listed ("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Imp && Co|5. Acacia"),
                "Move Down: last again");

   Confirmed := 0;
   Yes := False;
   Pick_Item (Window.Remove_Character_Item);
   Check.Check (Confirmed = 1 and then Question = "Remove Acacia from the file?" and then Window.Count = 5,
                "Remove Character...: asked first; Cancel removes nothing");
   Yes := True;
   Pick_Item (Window.Remove_Character_Item);
   Check.Check (Window.Count = 4 and then Window.Current = 4 and then Shown_Now ("Imp & Co")
                and then Listed ("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Imp && Co"),
                "removed, the last: the one before it shown");
   Choose (Window.Character_Choice, 2);
   Pick_Item (Window.Remove_Character_Item);
   Check.Check (Window.Current = 2 and then Shown_Now ("Cezar") and then Listed ("1. Acacia|2. Cezar|3. Imp && Co"),
                "removed from the middle: the one after it shown");

   --  Saved: every character, in order; each portrait rebased.
   Ch.Set_Text (Window.Character_At (3).Has_Portrait, Window.Character_At (3).Portrait,
                To_Unbounded_String ("images/imp.png"));
   Chosen := To_Unbounded_String ("../obj/several.yaml");
   Pick_Item (Window.Save_As_Item);
   Check.Check (not Window.Modified and then Title = "OVA Character Generator - several.yaml (2 of 3)"
                and then Window.Character_At (3).Portrait = "../test/data/images/imp.png",
                "Save As: saved, and a portrait not shown rebased too");
   Text := To_Unbounded_String (All_Saved);
   Tells := 0;
   OK := Load ("../../obj/several.yaml");
   Check.Check (OK and then Tells = 0 and then Title = "OVA Character Generator - several.yaml (1 of 3)"
                and then Listed ("1. Acacia|2. Cezar|3. Imp && Co") and then All_Saved = Text,
                "loaded again: all three, in order, the same, with nothing to say");
   Set_Name ("Acacia II");
   Answer := Window.Cancel;
   Asked := 0;
   Pick_Item (Window.New_Item);
   Check.Check (Asked = 1 and then Question = "Save the changes to several.yaml first?",
                "New with changes: the question names the file");
   Yes := True;
   Pick_Item (Window.Remove_Character_Item);
   Pick_Item (Window.Remove_Character_Item);
   Check.Check (Window.Count = 1 and then not Active (Window.Remove_Character_Item)
                and then Title = "OVA Character Generator - several.yaml *" and then Listed ("1. Imp && Co"),
                "down to one: Remove inactive, and the title without a count");
   Confirmed := 0;
   Pick_Item (Window.Remove_Character_Item);
   Check.Check (Confirmed = 0 and then Window.Count = 1, "and Remove does nothing: a file holds at least one");
   Answer := Window.Discard;
   Pick_Item (Window.New_Item);
   Check.Check (Window.Count = 1 and then Listed ("1. (no name)"), "New: one new character");

   Window.Close;
   --  As test_markdown's: fltkada keeps no count of the widgets open.
   declare
      use type Window.Window_Access, Window.Tabs_Access, Background.Box_Access,
        Markdown_Tab.Group_Access;
   begin
      Check.Check (Window.Main = null and then Window.Tabs = null and then Background.Portrait = null
                   and then Markdown_Tab.Tab = null and then AD.Dialog = null,
                   "every widget is deleted");
   end;
   Check.Summary;
end Test_Window;
