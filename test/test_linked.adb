--  Ova_Cg.Linked_Dialog: a Transformation's form, a Magic's spells, a
--  Companion's and a Vehicle's sheets.
--
--  Needs a display: run by make test-gui, as test_window is.  Each kind
--  of linked content opened from the window's button, as the user opens
--  it; shown with each name's page; edited, live, and checked in the
--  model, in the numbers computed from it, and in what is saved; and
--  the window's Character > Transformed form.

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Check;
with FLTK;
with FLTK.Menu_Items;
with Ova_Cg.Attack_Dialog;
with Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Linked_Dialog;
with Ova_Cg.Rules;
with Ova_Cg.Save;
with Ova_Cg.Trait_Panel;
with Ova_Cg.Widgets;
with Ova_Cg.Window;

procedure Test_Linked is

   use Ova_Cg;

   package Ch renames Ova_Cg.Character;
   package L renames Ova_Cg.Linked_Dialog;

   use type FLTK.Color, Calc.Trait, Calc.Spell, Calc.Sheet, Calc.Sheet_Kind, Rules.Item, Rules.Link,
     Rules.Kind, Ch.Trait, Linked_Dialog.Window_Access, Attack_Dialog.Window_Access;

   Tab : constant Standard.Character := ASCII.HT;

   Tells  : Natural := 0;
   C      : Ch.Character_Access;
   T      : Ch.Trait;
   P      : Ch.Character_Access;
   Text   : Unbounded_String;
   I, N   : Natural;
   Before : Integer;
   OK     : Boolean;

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

   procedure No_Page (Page : Positive) is null;

   function Saved return String is (Save.To_Text (Window.The_Character));

   function Has (S : String; Part : String) return Boolean is
     (Ada.Strings.Fixed.Index (S, Part) > 0);

   function Load (Name : String) return Boolean is (Window.Load ("data/" & Name));

   function Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   --  The last line of browser B holding S; 0 if none.
   function Line_With (B : Widgets.Browser_Access; S : String) return Natural is
   begin
      for I in reverse 1 .. B.Number_Of_Lines loop
         if Has (B.Get_Line_Text (I), S) then
            return I;
         end if;
      end loop;
      return 0;
   end Line_With;

   --  Selects B's line holding S, as a click does.
   procedure Click (B : Widgets.Browser_Access; S : String) is
   begin
      B.Set_Select (Line_With (B, S));
      B.Do_Callback;
   end Click;

   --  Selects B's line Line, as a click does.
   procedure Click_Line (B : Widgets.Browser_Access; Line : Positive) is
   begin
      B.Set_Select (Line);
      B.Do_Callback;
   end Click_Line;

   --  Chooses Name in P's Choice, as the user does.
   procedure Pick (P : Trait_Panel.Trait_Panel_Access; Name : String) is
      It : constant Rules.Item := Rules.Find (Name);
   begin
      pragma Assert (It /= null);
      Widgets.Choose (P.all, It);
      P.Choice.Do_Callback;
   end Pick;

   --  Name's place among the items of its kind.
   function Index_Of (Name : String) return Natural is
      It : constant Rules.Item := Rules.Find (Name);
   begin
      for I in 0 .. Rules.Count (It.Of_Kind) - 1 loop
         if Rules.Get (It.Of_Kind, I) = It then
            return I;
         end if;
      end loop;
      raise Program_Error;
   end Index_Of;

   --  Chooses Name, an Ability or a Weakness, in a Choice of its kind's
   --  names.
   procedure Pick_Ability (Choice : Widgets.Choice_Access; Name : String) is
   begin
      Choice.Set_Chosen (Place => Index_Of (Name) + 1);
      Choice.Do_Callback;
   end Pick_Ability;

   procedure Type_In (B : Widgets.Number_Box_Access; S : String) is
   begin
      B.Entry_In.Set_Value (S);
      B.Entry_In.Do_Callback;
   end Type_In;

   procedure Pick_Item (Item : Window.Item_Index) is
   begin
      Window.Bar.Picked (FLTK.Menu_Items.Menu_Item (Window.Bar.Item (Item).Data.all));
   end Pick_Item;

   --  Selects the window's Ability holding Name, and opens its linked
   --  content.
   procedure Open_Linked (Name : String) is
   begin
      Click (Window.Abilities.Browser, Name);
      Window.Ability_Linked.Do_Callback;
   end Open_Linked;

   --  Whether panel P lists List's traits of its kind, each with its
   --  page.
   function Listed (P : Trait_Panel.Trait_Panel_Access; List : Calc.Trait) return Boolean is
      T : Calc.Trait := List;
      N : Natural := 0;
   begin
      while T /= null loop
         if T.Of_Kind = P.Kind then
            N := N + 1;
            declare
               X    : constant Ch.Trait := Ch.Trait (T);
               Want : Unbounded_String :=
                 To_Unbounded_String ((if X.Level > 0 then "+" else "") & Image (X.Level) & " ") & X.Name;
            begin
               if X.Has_Detail then
                  Append (Want, " (" & X.Detail & ")");
               end if;
               Append (Want, Tab & Rules.Page_Text (X.Item));
               if N > P.Browser.Number_Of_Lines or else P.Browser.Get_Line_Text (N) /= To_String (Want) then
                  return False;
               end if;
            end;
         end if;
         T := T.Next;
      end loop;
      return N = P.Browser.Number_Of_Lines;
   end Listed;

   --  The trait of List named Name; null if none.
   function Named (List : Calc.Trait; Name : String) return Ch.Trait is
      T : Calc.Trait := List;
   begin
      while T /= null and then Ch.Trait (T).Name /= Name loop
         T := T.Next;
      end loop;
      return (if T = null then null else Ch.Trait (T));
   end Named;

   function Spell_Count (T : Calc.Trait) return Natural is
      Sp : Calc.Spell := T.Spells;
      N  : Natural := 0;
   begin
      while Sp /= null loop
         N := N + 1;
         Sp := Sp.Next;
      end loop;
      return N;
   end Spell_Count;

   function Attack_Count (S : Ch.Character_Access) return Natural is
      use type Calc.Attack;
      A : Calc.Attack := S.Attacks;
      N : Natural := 0;
   begin
      while A /= null loop
         N := N + 1;
         A := A.Next;
      end loop;
      return N;
   end Attack_Count;

   --  Whether box B shows N: its computed number, and its override or
   --  "".
   function Shows (B : Widgets.Number_Box_Access; N : Calc.Number) return Boolean is
     (B.Shown.Get_Value = Calc.Computed_Text (N)
      and then B.Entry_In.Get_Value = (if Calc.Overridden (N) then Calc.Text (N) else ""));

   function Partner_Shown (P : Ch.Character_Access) return Boolean is
     (Shows (L.Number (L.Defense_Number), P.Defense) and then Shows (L.Number (L.Barrier_Number), P.Barrier)
      and then Shows (L.Number (L.Health_Number), P.Health)
      and then Shows (L.Number (L.Endurance_Number), P.Endurance)
      and then Shows (L.Number (L.Reserve_Number), P.Reserve) and then Shows (L.Number (L.TV_Number), P.TV)
      and then Shows (L.Number (L.Incorporeal_Number), P.Incorporeal));

   function Columns (A, B, C : String) return String is (A & Tab & B & Tab & C);

   function Modified return Boolean is
      Title : constant String := Window.Main.Get_Label;
   begin
      return Window.Modified and then Title'Length > 2 and then Title (Title'Last) = '*';
   end Modified;

   function Info return String is (L.Info.Get_Label);

   function Linked_Label return String is (Window.Ability_Linked.Get_Label);

   function Partner_Of (T : Ch.Trait) return Ch.Character_Access is (Ch.Character_Access (T.Partner));

begin
   Window.Build;
   Window.Tell := Tell'Unrestricted_Access;
   Window.Ask := Ask'Unrestricted_Access;
   Widgets.Open_Page := No_Page'Unrestricted_Access;
   Window.Main.Show;
   Window.Main.Wait_For_Expose;
   OK := FLTK.Check;

   --  ---- The button ----
   OK := Load ("Fukiko.yaml");
   C := Window.The_Character;
   Click (Window.Abilities.Browser, "Cute!");
   Check.Check (OK and then not Window.Ability_Linked.Is_Active,
                "an Ability with no linked content: the button inactive");
   Click (Window.Abilities.Browser, "Transformation");
   Check.Check (Window.Ability_Linked.Is_Active and then Linked_Label = "Form...", "Transformation: Form...");
   Click (Window.Abilities.Browser, "Companion");
   Check.Check (Linked_Label = "Companion...", "Companion: Companion...");

   --  ---- A Transformation's form ----
   T := Named (C.Traits, "Transformation");
   Open_Linked ("Transformation");
   Check.Check (L.Dialog /= null and then L.Mode = Rules.Form, "Form...: the dialog, for the form");
   Check.Check (Listed (L.Abilities, T.Form) and then Listed (L.Weaknesses, T.Form)
                and then L.Abilities.Browser.Number_Of_Lines = 4,
                "the form's Abilities and Weaknesses listed, with pages");
   Check.Check (Info = "The form's Abilities and Weaknesses come to +8 levels; Transformation +4 pays for 8 (p. 63)."
                and then L.Info.Get_Label_Color = FLTK.Foreground_Color,
                "its levels against what Transformation +4 pays for");
   Before := Calc.Value (C.Health);
   Pick (L.Abilities, "Tough");
   L.Abilities.Spinner.Set_Value (1.0);
   L.Abilities.Add_Button.Do_Callback;
   Check.Check (Named (T.Form, "Tough") /= null and then Listed (L.Abilities, T.Form) and then Modified,
                "a form Ability added: in the form, listed, the character modified");
   Check.Check (C.Transformed and then Calc.Value (C.Health) = Before + 10,
                "Fukiko shown transformed: her HEALTH counts the form's Tough");
   Check.Check (Info = "The form's Abilities and Weaknesses come to +9 levels; Transformation +4 pays for 8 (p. 63)."
                and then L.Info.Get_Label_Color = FLTK.Red_Color,
                "the levels again, over what it pays for: in red");
   Check.Check (Has (Saved, "- name: Tough"), "saved");
   Click (L.Abilities.Browser, "Barrier");
   Check.Check (L.Mods_Button.Is_Active and then L.End_Box.Is_Active,
                "the form's Barrier: its Perks and Flaws, its END");
   L.Mods_Button.Do_Callback;
   Check.Check (Attack_Dialog.Dialog /= null, "Perks and Flaws...: the dialog over this one");
   L.Close_Button.Do_Callback;
   Check.Check (L.Dialog /= null, "Close waits for the dialog above it");
   Attack_Dialog.Cancel;
   L.Close_Button.Do_Callback;
   Check.Check (L.Dialog = null, "Close");

   --  ---- Character > Transformed form ----
   Check.Check (Window.Bar.Item (Window.Transformed_Item).Get_State,
                "Character > Transformed form: on, as Fukiko's file says");
   Pick_Item (Window.Transformed_Item);
   Check.Check (not C.Transformed and then Calc.Value (C.Health) = Before
                and then Shows (Window.Number (Window.Health_Number), C.Health)
                and then not Has (Saved, "transformed: true"),
                "off: the form not counted, in the combat box too, and not saved as shown transformed");
   Pick_Item (Window.Transformed_Item);
   Check.Check (C.Transformed and then Calc.Value (C.Health) = Before + 10
                and then Shows (Window.Number (Window.Health_Number), C.Health)
                and then Has (Saved, "transformed: true"),
                "on again");

   --  ---- A Companion's sheet ----
   T := Named (C.Traits, "Companion");
   P := Partner_Of (T);
   Open_Linked ("Companion");
   Check.Check (L.Mode = Rules.Partner and then L.Partner_Name.Get_Value = "Azyrus" and then L.Fragment.Is_On
                and then not L.Combat.Is_On,
                "Companion...: Azyrus, a Fragment, no combat stats");
   Check.Check (Listed (L.Abilities, P.Traits) and then Listed (L.Weaknesses, P.Traits),
                "its Abilities and Weaknesses, with pages");
   Check.Check (not L.Add_Attack_Button.Is_Active and then not L.Number (L.Health_Number).Is_Active
                and then Partner_Shown (P),
                "no combat stats: its attacks and numbers inactive, but computed: a Companion's 20 less Frail");
   L.Partner_Name.Set_Value ("Azyrus II");
   L.Partner_Name.Do_Callback;
   Check.Check (P.Name = "Azyrus II" and then Has (Saved, "name: Azyrus II"), "renamed, and saved");
   L.Partner_Name.Set_Value (" ");
   L.Partner_Name.Do_Callback;
   Check.Check (P.Name = "Companion", "a blank name: Companion, since the file needs one");
   L.Combat.Set_State (Widgets.Buttons.On);
   L.Combat.Do_Callback;
   Check.Check (P.Has_Combat and then L.Add_Attack_Button.Is_Active and then L.Number (L.Health_Number).Is_Active
                and then not L.Number (L.Barrier_Number).Is_Active
                and then not L.Number (L.Reserve_Number).Is_Active
                and then not L.Number (L.Incorporeal_Number).Is_Active,
                "combat stats on: its attacks and numbers, Barrier's, Incorporeal Form's and Reserve's not, having none");
   Before := Calc.Value (P.Health);
   Pick (L.Abilities, "Tough");
   L.Abilities.Add_Button.Do_Callback;
   Check.Check (Calc.Value (P.Health) = Before + 10 and then Partner_Shown (P),
                "a Companion's Tough +1: its HEALTH 10 more, shown");
   Type_In (L.Number (L.Health_Number), "35");
   Check.Check (Calc.Overridden (P.Health) and then Calc.Value (P.Health) = 35 and then Partner_Shown (P),
                "its HEALTH overridden");
   Text := To_Unbounded_String (Saved);
   Check.Check (Has (To_String (Text), "health: 35") and then Has (To_String (Text), "- health"),
                "and saved, in its combat block, listed in overrides");
   L.Add_Attack_Button.Do_Callback;
   Check.Check (Attack_Dialog.Dialog /= null, "Add...: the attack dialog, for the Companion");
   Attack_Dialog.Name_In.Set_Value ("Claw");
   Attack_Dialog.OK;
   Check.Check (Attack_Count (P) = 1 and then L.Attacks.Number_Of_Lines = 1 and then Attack_Count (C) = 4,
                "OK: the Companion's attack, not Fukiko's");
   Check.Check (Ada.Strings.Fixed.Index (L.Attacks.Get_Line_Text (1), "Claw") = 1, "listed, with its numbers");
   Check.Check (Has (Saved, "name: Claw"), "and saved");
   L.Attacks.Set_Select (Line => 1);
   L.Remove_Attack_Button.Do_Callback;
   Check.Check (Attack_Count (P) = 0 and then not Has (Saved, "name: Claw"), "Remove");
   L.Close_Button.Do_Callback;

   --  ---- A Magic's spells ----
   OK := Load ("Auren.yaml");
   C := Window.The_Character;
   T := Named (C.Traits, "Magic, Arcane");
   Open_Linked ("Magic, Arcane");
   Check.Check (Linked_Label = "Spells..." and then L.Mode = Rules.Spells
                and then L.Spells.Number_Of_Lines = Spell_Count (Calc.Trait (T)) and then Spell_Count (Calc.Trait (T)) = 6,
                "Spells...: Auren's six spells");
   Check.Check (L.Spells.Get_Line_Text (1) = Columns ("Mana Shield", "Barrier +2 (p. 51)", "END 10+"),
                "each with its Ability's page and its END: Barrier's 10+");
   Check.Check (L.Cast_Kind = Rules.Ability and then L.Spell_Ability.Get_Label = "Ability"
                and then L.Spell_Level.Get_Minimum = 1.0 and then L.Spell_Level.Get_Maximum = 5.0,
                "Arcane's spells: Abilities, +1 to +5");
   N := Spell_Count (Calc.Trait (T));
   L.Spell_Name.Set_Value ("Glow");
   Pick_Ability (L.Spell_Ability, "Healer");
   Check.Check (L.Spell_Help.Page = 54, "the Ability chosen: ? at its page");
   L.Spell_Level.Set_Value (1.0);
   L.Add_Spell_Button.Do_Callback;
   I := L.Spells.Selected_Index;
   Check.Check (Spell_Count (Calc.Trait (T)) = N + 1 and then I = N + 1
                and then L.Spells.Get_Line_Text (I) = Columns ("Glow", "Healer +1 (p. 54)", "END 5"),
                "Add: last, selected, its END by Magic +3 and its level 1: 5 (p. 58)");
   Check.Check (Has (Saved, "name: Glow") and then Has (Saved, "ability: Healer") and then Modified, "saved");
   L.Spell_Level.Set_Value (2.0);
   L.Change_Spell_Button.Do_Callback;
   Check.Check (L.Spells.Get_Line_Text (N + 1) = Columns ("Glow", "Healer +2 (p. 54)", "END 10"),
                "Change: level 2, END 10");
   Type_In (L.Spell_End, "15");
   Check.Check (L.Spells.Get_Line_Text (N + 1) = Columns ("Glow", "Healer +2 (p. 54)", "END 15")
                and then L.Spell_End.Is_Active,
                "its END overridden: 15, listed");
   Tells := 0;
   L.Spell_Name.Set_Value (" ");
   L.Add_Spell_Button.Do_Callback;
   Check.Check (Tells = 1 and then Spell_Count (Calc.Trait (T)) = N + 1, "a spell with no name: said so, not added");
   Click_Line (L.Spells, N + 1);
   Check.Check (L.Spell_Name.Get_Value = "Glow", "a spell selected: its name, Ability and level to edit");
   L.Remove_Spell_Button.Do_Callback;
   Check.Check (Spell_Count (Calc.Trait (T)) = N and then not Has (Saved, "name: Glow")
                and then L.Spells.Number_Of_Lines = N,
                "Remove");
   L.Close_Button.Do_Callback;

   --  A change to an Ability of another kind drops what the file
   --  couldn't hold.
   Click (Window.Abilities.Browser, "Magic, Arcane");
   Pick (Window.Abilities, "Magic, Witchcraft");
   Window.Abilities.Change_Button.Do_Callback;
   Check.Check (Spell_Count (Calc.Trait (T)) = N, "Magic, Arcane to Magic, Witchcraft: the spells kept");
   Pick (Window.Abilities, "Flight");
   Window.Abilities.Change_Button.Do_Callback;
   Check.Check (T.Spells = null and then not Has (Saved, "spells:"), "to Flight: the spells dropped");

   --  ---- Witchcraft's curses: Weaknesses (p. 58) ----
   OK := Load ("Cora.yaml");
   C := Window.The_Character;
   T := Named (C.Traits, "Magic, Witchcraft");
   Open_Linked ("Magic, Witchcraft");
   Check.Check (OK and then L.Cast_Kind = Rules.Weakness and then L.Spell_Ability.Get_Label = "Weakness"
                and then L.Spell_Level.Get_Minimum = -3.0 and then L.Spell_Level.Get_Maximum = -1.0
                and then L.Spell_Level.Get_Value = -1.0 and then L.Spells.Number_Of_Lines = 0,
                "Cora's Witchcraft: its spells are Weaknesses, -1 to -3, none yet");
   L.Spell_Name.Set_Value ("Hex");
   Pick_Ability (L.Spell_Ability, "Frail");
   Check.Check (L.Spell_Help.Page = 71, "the Weakness chosen: ? at its page, Frail's 71");
   L.Spell_Level.Set_Value (-2.0);
   L.Add_Spell_Button.Do_Callback;
   Check.Check (Spell_Count (Calc.Trait (T)) = 1
                and then L.Spells.Get_Line_Text (1) = Columns ("Hex", "Frail -2 (p. 71)", "END 20"),
                "Add: Frail -2, its END by Witchcraft +2 and its size 2: 20");
   Check.Check (Has (Saved, "ability: Frail") and then Has (Saved, "level: -2"), "saved");
   Tells := 0;
   L.Spell_Name.Set_Value (" ");
   L.Add_Spell_Button.Do_Callback;
   Check.Check (Tells = 1 and then Spell_Count (Calc.Trait (T)) = 1, "a curse with no name: said so, not added");
   L.Close_Button.Do_Callback;
   Open_Linked ("Magic, Witchcraft");
   Click_Line (L.Spells, 1);
   Check.Check (L.Spell_Name.Get_Value = "Hex" and then L.Spell_Ability.Chosen_Index - 1 = Index_Of ("Frail")
                and then L.Spell_Level.Get_Value = -2.0,
                "opened again and selected: its name, Weakness and level");
   L.Close_Button.Do_Callback;

   --  ---- A new Companion, and a Vehicle ----
   Pick_Item (Window.New_Item);
   C := Window.The_Character;
   Pick (Window.Abilities, "Companion");
   Window.Abilities.Text.Set_Value ("Rex");
   Window.Abilities.Add_Button.Do_Callback;
   T := Named (C.Traits, "Companion");
   Check.Check (T /= null and then T.Partner = null, "a Companion added: no sheet yet");
   Window.Ability_Linked.Do_Callback;
   Check.Check (T.Partner /= null and then T.Partner.Of_Kind = Calc.Companion_Sheet
                and then L.Partner_Name.Get_Value = "Rex" and then L.Combat.Is_On,
                "Companion...: its sheet made, a Companion's, named its detail, with combat stats");
   P := Partner_Of (T);
   Check.Check (Calc.Value (P.Health) = 20 and then Calc.Value (P.Endurance) = 20 and then Partner_Shown (P),
                "a Companion's 20 and 20 (p. 52)");
   Check.Check (Has (Saved, "companion:") and then Has (Saved, "name: Rex"), "saved as companion:");
   L.Close_Button.Do_Callback;
   Pick (Window.Abilities, "Vehicle (Mecha)");
   Window.Abilities.Text.Set_Value ("");
   Window.Abilities.Add_Button.Do_Callback;
   Open_Linked ("Vehicle (Mecha)");
   T := Named (C.Traits, "Vehicle (Mecha)");
   Check.Check (T.Partner /= null and then T.Partner.Of_Kind = Calc.Character_Sheet and then L.Mode = Rules.Machine
                and then L.Partner_Name.Get_Value = "Vehicle" and then Has (Saved, "vehicle:")
                and then Has (Saved, "name: Vehicle"),
                "a Vehicle with no detail: a character's sheet, named Vehicle, saved as vehicle:");
   L.Close_Button.Do_Callback;
   OK := Load ("Vehicle.yaml");
   C := Window.The_Character;
   Open_Linked ("Vehicle");
   Check.Check (Linked_Label = "Vehicle..." and then L.Mode = Rules.Machine
                and then L.Partner_Name.Get_Value = "Thunderhawk" and then L.Attacks.Number_Of_Lines = 1,
                "Vehicle...: Thunderhawk's sheet, its attack");
   T := Named (C.Traits, "Vehicle");
   P := Partner_Of (T);
   Check.Check (Partner_Shown (P) and then Calc.Value (P.Endurance) = 40, "its numbers: a character's 40 (p. 64)");
   L.Close_Button.Do_Callback;

   Window.Close;
   --  As test_markdown's: fltkada keeps no count of the widgets open.
   declare
      use type Window.Window_Access;
   begin
      Check.Check (Window.Main = null and then L.Dialog = null and then Attack_Dialog.Dialog = null,
                   "every widget is deleted");
   end;
   Check.Summary;
end Test_Linked;
