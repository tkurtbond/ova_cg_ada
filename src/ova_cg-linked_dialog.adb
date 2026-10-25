with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with FLTK.Static;
with FLTK.Widgets.Menus.Choices.Extra;
with Ova_Cg.Attack_Dialog;
with Ova_Cg.Calc;
with System;

package body Ova_Cg.Linked_Dialog is

   package Buttons renames Widgets.Buttons;
   package Texts renames Widgets.Texts;
   package Hold renames Widgets.Hold;
   package Choices renames Widgets.Choices;
   package Spinners renames Widgets.Spinners;

   use type Calc.Attack;
   use type Calc.Spell;
   use type Calc.Trait;
   use type Character.Spell;
   use type Character.Attack;
   use type Character.Character_Access;
   use type Character.Trait;
   use type Rules.Item;
   use type Rules.Kind;
   use type Rules.Link;
   use type System.Address;
   use type Trait_Panel.Trait_Panel_Access;
   use type Widgets.Help_Button_Access;
   use type Widgets.Number_Box_Access;
   use type Calc.Sheet;
   use type Attack_Dialog.Window_Access;

   Width    : constant := 760;
   Row      : constant := 25;
   --  The dialog's height in each shape.
   Form_H    : constant := 450;
   Spells_H  : constant := 500;
   Partner_H : constant := 640;

   Tab : constant Standard.Character := ASCII.HT;

   function Image (I : Integer) return String is
     (Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Left));

   function Signed (I : Integer) return String is
     ((if I > 0 then "+" else "") & Image (I));

   type Number_Boxes is array (Sheet_Number) of Widgets.Number_Box_Access;

   --  The dialog's widgets: what Finish hands to Collect.
   type Parts is record
      Dialog       : Window_Access;
      Info         : Box_Access;
      Close_Button : Widgets.Button_Access;
      Abilities, Weaknesses : Trait_Panel.Trait_Panel_Access;
      Mods_Button  : Widgets.Button_Access;
      End_Box      : Widgets.Number_Box_Access;
      Spells       : Widgets.Browser_Access;
      Spell_Name   : Widgets.Input_Access;
      Spell_Ability : Widgets.Choice_Access;
      Spell_Level  : Widgets.Spinner_Access;
      Spell_Help   : Widgets.Help_Button_Access;
      Add_Spell_Button, Change_Spell_Button, Remove_Spell_Button : Widgets.Button_Access;
      Spell_End    : Widgets.Number_Box_Access;
      Partner_Name : Widgets.Input_Access;
      Fragment, Combat : Check_Access;
      Attacks      : Widgets.Browser_Access;
      Add_Attack_Button, Edit_Attack_Button, Remove_Attack_Button : Widgets.Button_Access;
      Numbers      : Number_Boxes;
   end record;

   package Parts_Vectors is new Ada.Containers.Vectors (Positive, Parts);

   Open   : Parts;                 --  the dialog open, if any
   Closed : Parts_Vectors.Vector;  --  closed, for Collect to free

   The_Mode      : Rules.Link := Rules.Form;
   The_Cast_Kind : Rules.Kind := Rules.Ability;
   The_Character : Character.Character_Access;  --  the window's, recomputed after a change
   The_Trait     : Character.Trait;             --  the Ability whose content this is
   The_Partner   : Character.Character_Access;  --  its partner's sheet, in Partner and Machine
   On_Done       : Done_Handler;

   function Dialog return Window_Access is (Open.Dialog);
   function Mode return Rules.Link is (The_Mode);
   function Info return Box_Access is (Open.Info);
   function Close_Button return Widgets.Button_Access is (Open.Close_Button);
   function Abilities return Trait_Panel.Trait_Panel_Access is (Open.Abilities);
   function Weaknesses return Trait_Panel.Trait_Panel_Access is (Open.Weaknesses);
   function Mods_Button return Widgets.Button_Access is (Open.Mods_Button);
   function End_Box return Widgets.Number_Box_Access is (Open.End_Box);
   function Spells return Widgets.Browser_Access is (Open.Spells);
   function Spell_Name return Widgets.Input_Access is (Open.Spell_Name);
   function Spell_Ability return Widgets.Choice_Access is (Open.Spell_Ability);
   function Spell_Level return Widgets.Spinner_Access is (Open.Spell_Level);
   function Spell_Help return Widgets.Help_Button_Access is (Open.Spell_Help);
   function Add_Spell_Button return Widgets.Button_Access is (Open.Add_Spell_Button);
   function Change_Spell_Button return Widgets.Button_Access is (Open.Change_Spell_Button);
   function Remove_Spell_Button return Widgets.Button_Access is (Open.Remove_Spell_Button);
   function Spell_End return Widgets.Number_Box_Access is (Open.Spell_End);
   function Cast_Kind return Rules.Kind is (The_Cast_Kind);
   function Partner_Name return Widgets.Input_Access is (Open.Partner_Name);
   function Fragment return Check_Access is (Open.Fragment);
   function Combat return Check_Access is (Open.Combat);
   function Attacks return Widgets.Browser_Access is (Open.Attacks);
   function Add_Attack_Button return Widgets.Button_Access is (Open.Add_Attack_Button);
   function Edit_Attack_Button return Widgets.Button_Access is (Open.Edit_Attack_Button);
   function Remove_Attack_Button return Widgets.Button_Access is (Open.Remove_Attack_Button);
   function Number (Which : Sheet_Number) return Widgets.Number_Box_Access is (Open.Numbers (Which));

   procedure Say (Text : String) is
   begin
      if Tell /= null then
         Tell (Text);
      end if;
   end Say;

   procedure Show_All;

   --  After a change here: the character recomputed and shown, here and
   --  in the window.
   procedure Something_Changed is
   begin
      if Changed /= null then
         Changed.all;
      else
         Character.Recompute (The_Character);
      end if;
      Show_All;
   end Something_Changed;

   --  ---- Numbers ----

   --  A partner's number.
   type Sheet_Target is new Widgets.Target with record
      Which : Sheet_Number;
   end record;

   overriding function Get (T : Sheet_Target) return Calc.Number;
   overriding procedure Put (T : in out Sheet_Target; N : Calc.Number);

   overriding function Get (T : Sheet_Target) return Calc.Number is
      P : Character.Character_Record'Class renames The_Partner.all;
   begin
      case T.Which is
         when Defense_Number     => return P.Defense;
         when Barrier_Number     => return P.Barrier;
         when Incorporeal_Number => return P.Incorporeal;
         when Health_Number      => return P.Health;
         when Endurance_Number   => return P.Endurance;
         when Reserve_Number     => return P.Reserve;
         when TV_Number          => return P.TV;
      end case;
   end Get;

   overriding procedure Put (T : in out Sheet_Target; N : Calc.Number) is
      P : Character.Character_Record'Class renames The_Partner.all;
   begin
      case T.Which is
         when Defense_Number     => P.Defense := N;
         when Barrier_Number     => P.Barrier := N;
         when Incorporeal_Number => P.Incorporeal := N;
         when Health_Number      => P.Health := N;
         when Endurance_Number   => P.Endurance := N;
         when Reserve_Number     => P.Reserve := N;
         when TV_Number          => P.TV := N;
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

   --  A spell's END.
   type Spell_Target is new Widgets.Target with record
      Spell : Calc.Spell;
   end record;

   overriding function Get (T : Spell_Target) return Calc.Number is (T.Spell.End_Cost);
   overriding procedure Put (T : in out Spell_Target; N : Calc.Number);

   overriding procedure Put (T : in out Spell_Target; N : Calc.Number) is
   begin
      T.Spell.End_Cost := N;
   end Put;

   procedure Number_Changed (B : in out Widgets.Number_Box'Class; Good : Boolean) is
   begin
      if not Good then
         Say ("Not a number for " & B.Get_Label & ". The computed number is used.");
      end if;
      Something_Changed;
   end Number_Changed;

   function Number_Box (X, Y : Integer; Label : String) return Widgets.Number_Box_Access is
      B : constant Widgets.Number_Box_Access := Widgets.Open_Number_Box (X, Y, Label);
   begin
      B.Changed := Number_Changed'Access;
      return B;
   end Number_Box;

   --  ---- Abilities and Weaknesses: a form's or a partner's ----

   --  The selected Ability's END and Perks and Flaws.
   procedure Show_Ability (T : Character.Trait) is
   begin
      if T = null then
         Open.End_Box.Set_Target (null);
         Open.End_Box.Deactivate;
         Open.Mods_Button.Deactivate;
      else
         Open.End_Box.Set_Target (new Trait_Target'(Trait => Calc.Trait (T)));
         if T.Has_End then
            Open.End_Box.Activate;
         else
            Open.End_Box.Deactivate;
         end if;
         Open.Mods_Button.Activate;
      end if;
      Open.End_Box.Display;
   end Show_Ability;

   procedure Ability_Selected (P : in out Trait_Panel.Trait_Panel'Class; T : Character.Trait) is
      pragma Unreferenced (P);
   begin
      Show_Ability (T);
   end Ability_Selected;

   procedure Panel_Changed (P : in out Trait_Panel.Trait_Panel'Class) is
      pragma Unreferenced (P);
   begin
      Something_Changed;
   end Panel_Changed;

   procedure Mods_Done (Changed : Boolean) is
   begin
      if Open.Dialog = null then
         return;  --  closed while the attack dialog was open (Close)
      end if;
      if Changed then
         Something_Changed;
      end if;
      Open.Abilities.Refresh (Open.Abilities.Browser.Selected_Index);
   end Mods_Done;

   procedure Mods_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      T : constant Character.Trait := Open.Abilities.Selected;
   begin
      if T /= null and then Attack_Dialog.Dialog = null then
         Attack_Dialog.Edit_Mods
           ((if The_Partner /= null then The_Partner else The_Character), T, Mods_Done'Access);
      end if;
   end Mods_Action;

   --  The two panels at Y, each browser H high, and the Ability's
   --  controls under them.
   procedure Panels (Y, H : Integer) is
      YY : Integer;
   begin
      Open.Abilities := Trait_Panel.Open (10, Y, 365, H, Rules.Ability, "Abilities");
      Open.Abilities.Set_Handlers (Ability_Selected'Access, Panel_Changed'Access);
      Open.Weaknesses := Trait_Panel.Open (385, Y, 365, H, Rules.Weakness, "Weaknesses");
      Open.Weaknesses.Set_Handlers (null, Panel_Changed'Access);
      YY := Open.Abilities.Bottom + 5;
      Open.Mods_Button := new Buttons.Button'(Buttons.Forge.Create (10, YY, 140, Row, "Perks and Flaws..."));
      Open.Mods_Button.Set_Callback (Mods_Action'Access);
      Open.End_Box := Number_Box (200, YY, "END");
      Open.End_Box.Set_Alignment (FLTK.Align_Left);
   end Panels;

   --  The form's levels, against what the Transformation pays for: 2 a
   --  level (p. 63).
   procedure Show_Form_Levels is
      F : Calc.Trait := The_Trait.Form;
      N : Integer := 0;
   begin
      while F /= null loop
         N := N + F.Level;
         F := F.Next;
      end loop;
      Open.Info.Set_Label
        ("The form's Abilities and Weaknesses come to " & Signed (N) & " levels; Transformation +"
         & Image (The_Trait.Level) & " pays for " & Image (2 * The_Trait.Level) & " (p. 63).");
      Open.Info.Set_Label_Color (if N > 2 * The_Trait.Level then FLTK.Red_Color else FLTK.Foreground_Color);
      Open.Info.Redraw;
   end Show_Form_Levels;

   --  ---- Spells ----

   --  The spell on line Line (from 1); null for none.
   function Spell_At (Line : Natural) return Character.Spell is
      Sp : Calc.Spell;
      L  : Natural := Line;
   begin
      if L < 1 then
         return null;
      end if;
      Sp := The_Trait.Spells;
      while Sp /= null and then L > 1 loop
         Sp := Sp.Next;
         L := L - 1;
      end loop;
      return Character.Spell (Sp);
   end Spell_At;

   --  The spells listed again, line Line selected (0: none), and its END.
   procedure Show_Spells (Line : Natural) is
      Sp : Calc.Spell := The_Trait.Spells;
      X  : Character.Spell;
   begin
      Open.Spells.Clear;
      while Sp /= null loop
         X := Character.Spell (Sp);
         Open.Spells.Add
           (To_String (X.Name) & Tab & To_String (X.Ability) & " " & Signed (X.Level)
            & " (" & Rules.Page_Text (X.Item) & ")" & Tab & "END " & Calc.Text (X.End_Cost));
         Sp := Sp.Next;
      end loop;
      X := Spell_At (Line);
      if X /= null then
         Open.Spells.Set_Select (Line => Line);
         Open.Spell_End.Set_Target (new Spell_Target'(Spell => Calc.Spell (X)));
         Open.Spell_End.Activate;
      else
         Open.Spell_End.Set_Target (null);
         Open.Spell_End.Deactivate;
      end if;
      Open.Spell_End.Display;
   end Show_Spells;

   --  The Ability (or Weakness) chosen; null for none.
   function Spell_Item return Rules.Item is
      I : constant Natural := Open.Spell_Ability.Chosen_Index;  --  1-based; 0: none
   begin
      if I in 1 .. Rules.Count (The_Cast_Kind) then
         return Rules.Get (The_Cast_Kind, I - 1);
      else
         return null;
      end if;
   end Spell_Item;

   --  Chooses It in the Choice; none for null, or an item of the other
   --  kind (a spell the Magic can't cast, from a file).
   procedure Choose_Spell_Item (It : Rules.Item) is
      Found : Boolean := False;
   begin
      if It /= null and then It.Of_Kind = The_Cast_Kind then
         for I in 0 .. Rules.Count (The_Cast_Kind) - 1 loop
            if Rules.Get (The_Cast_Kind, I) = It then
               Open.Spell_Ability.Set_Chosen (Place => I + 1);
               Found := True;
            end if;
         end loop;
      end if;
      if not Found then
         FLTK.Widgets.Menus.Choices.Extra.Choose_None (Open.Spell_Ability.all);
      end if;
      Open.Spell_Help.Page := (if It /= null then It.Page else 0);
   end Choose_Spell_Item;

   procedure Spell_Ability_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Choose_Spell_Item (Spell_Item);
   end Spell_Ability_Action;

   procedure Spells_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      X : constant Character.Spell := Spell_At (Open.Spells.Selected_Index);
   begin
      if X /= null then
         Open.Spell_Name.Set_Value (To_String (X.Name));
         Choose_Spell_Item (X.Item);
         Open.Spell_Level.Set_Value (Long_Float (X.Level));
         Show_Spells (Open.Spells.Selected_Index);
      end if;
   end Spells_Action;

   --  Add puts the spell last; Change and Remove need one selected.  A
   --  spell needs a name and an Ability (a Weakness, Witchcraft's); one
   --  changed keeps one the Choice doesn't have if none is chosen.
   procedure Spell_Button_Action (W : in out FLTK.Widgets.Widget'Class) is
      Is_Add    : constant Boolean := W'Address = Open.Add_Spell_Button.all'Address;
      Is_Remove : constant Boolean := W'Address = Open.Remove_Spell_Button.all'Address;
      Line      : Natural := Open.Spells.Selected_Index;
      X         : constant Character.Spell := Spell_At (Line);
      Name      : constant String := Character.Trim (Open.Spell_Name.Get_Value);
      It        : constant Rules.Item := Spell_Item;
      Sp        : Character.Spell;
      P         : Calc.Spell;
      Gone      : Calc.Spell;
   begin
      if Is_Remove then
         if X = null then
            return;
         end if;
         Character.Remove_Spell (Calc.Trait (The_Trait), Calc.Spell (X));
         Open.Spell_End.Set_Target (null);  --  none holds X
         Gone := Calc.Spell (X);
         Calc.Free_Spells (Gone);
         Line := 0;
      elsif Name = "" or else (It = null and then (Is_Add or else X = null or else X.Item /= null)) then
         if The_Cast_Kind = Rules.Weakness then
            Say ("A curse needs a name and the Weakness it casts.");
         else
            Say ("A spell needs a name and the Ability it mimics.");
         end if;
         return;
      elsif Is_Add then
         Sp := Character.New_Spell (To_Unbounded_String (Name), It.Name, It,
                                    Widgets.Spin_Value (Open.Spell_Level.all));
         Calc.Add_Spell (Calc.Trait (The_Trait), Calc.Spell (Sp));
         Line := 1;
         P := The_Trait.Spells;
         while P /= Calc.Spell (Sp) loop
            Line := Line + 1;
            P := P.Next;
         end loop;
      elsif X = null then
         return;
      else
         X.Name := To_Unbounded_String (Name);
         if It /= null then
            X.Item := It;
            X.Ability := It.Name;
         end if;
         X.Level := Widgets.Spin_Value (Open.Spell_Level.all);
      end if;
      Something_Changed;
      Show_Spells (Line);
   end Spell_Button_Action;

   --  ---- A partner's sheet ----

   procedure Partner_Text_Action (W : in out FLTK.Widgets.Widget'Class) is
   begin
      if W'Address = Open.Partner_Name.all'Address then
         declare
            Name : constant String := Character.Trim (Open.Partner_Name.Get_Value);
         begin
            --  The file needs one.
            The_Partner.Name := (if Name = "" then The_Partner.Label else To_Unbounded_String (Name));
         end;
      elsif W'Address = Open.Fragment.all'Address then
         The_Partner.Is_Fragment := Open.Fragment.Is_On;
      elsif W'Address = Open.Combat.all'Address then
         The_Partner.Has_Combat := Open.Combat.Is_On;
      end if;
      Something_Changed;
   end Partner_Text_Action;

   --  The attack on line Line (from 1); null for none.
   function Attack_At (Line : Natural) return Character.Attack is
      A : Calc.Attack;
      L : Natural := Line;
   begin
      if L < 1 then
         return null;
      end if;
      A := The_Partner.Attacks;
      while A /= null and then L > 1 loop
         A := A.Next;
         L := L - 1;
      end loop;
      return Character.Attack (A);
   end Attack_At;

   procedure Show_Attacks (Line : Natural) is
      A : Calc.Attack := The_Partner.Attacks;
   begin
      Open.Attacks.Clear;
      while A /= null loop
         Open.Attacks.Add
           (To_String (Character.Attack (A).Name) & Tab & "ROLL " & Calc.Text (A.Roll) & Tab
            & "DX " & Calc.Text (A.DX) & Tab & "END " & Calc.Text (A.End_Cost));
         A := A.Next;
      end loop;
      if Line > 0 and then Line <= Open.Attacks.Number_Of_Lines then
         Open.Attacks.Set_Select (Line => Line);
      end if;
   end Show_Attacks;

   procedure Attack_Done (Changed : Boolean) is
      pragma Unreferenced (Changed);
   begin
      if Open.Dialog /= null then
         Something_Changed;
      end if;
   end Attack_Done;

   procedure Attack_Button_Action (W : in out FLTK.Widgets.Widget'Class) is
      A    : Character.Attack;
      Gone : Calc.Attack;
   begin
      if Attack_Dialog.Dialog /= null then
         return;
      end if;
      if W'Address = Open.Add_Attack_Button.all'Address then
         A := Character.New_Attack (To_Unbounded_String ("New attack"));
         Calc.Add_Attack (Calc.Sheet (The_Partner), Calc.Attack (A));
         Character.Recompute (The_Character);
         Attack_Dialog.Edit_Attack (The_Partner, A, True, Attack_Done'Access);
      else
         A := Attack_At (Open.Attacks.Selected_Index);
         if A = null then
            return;
         end if;
         if W'Address = Open.Edit_Attack_Button.all'Address then
            Attack_Dialog.Edit_Attack (The_Partner, A, False, Attack_Done'Access);
         else
            Character.Remove_Attack (The_Partner, Calc.Attack (A));
            Gone := Calc.Attack (A);
            Calc.Free_Attacks (Gone);
            Something_Changed;
         end if;
      end if;
   end Attack_Button_Action;

   --  ---- Everything shown ----

   procedure Show_All is
   begin
      if Open.Dialog = null then
         return;
      end if;
      case The_Mode is
         when Rules.Form =>
            Show_Form_Levels;
            Open.End_Box.Display;
         when Rules.Spells =>
            Show_Spells (Open.Spells.Selected_Index);
         when Rules.Partner | Rules.Machine =>
            Open.End_Box.Display;
            Show_Attacks (Open.Attacks.Selected_Index);
            for B of Open.Numbers loop
               B.Display;
            end loop;
            --  With no combat stats, nothing of combat is saved: all of
            --  it inactive.  Barrier's and Incorporeal Form's Defense and
            --  the Reserve only with them.
            if The_Partner.Has_Combat then
               Open.Attacks.Activate;
               Open.Add_Attack_Button.Activate;
               Open.Edit_Attack_Button.Activate;
               Open.Remove_Attack_Button.Activate;
               for B of Open.Numbers loop
                  B.Activate;
               end loop;
               if not The_Partner.Has_Barrier then
                  Open.Numbers (Barrier_Number).Deactivate;
               end if;
               if not The_Partner.Has_Incorporeal then
                  Open.Numbers (Incorporeal_Number).Deactivate;
               end if;
               if not The_Partner.Has_Reserve then
                  Open.Numbers (Reserve_Number).Deactivate;
               end if;
            else
               Open.Attacks.Deactivate;
               Open.Add_Attack_Button.Deactivate;
               Open.Edit_Attack_Button.Deactivate;
               Open.Remove_Attack_Button.Deactivate;
               for B of Open.Numbers loop
                  B.Deactivate;
               end loop;
            end if;
         when Rules.No_Link =>
            null;
      end case;
   end Show_All;

   --  ---- Opening and closing ----

   --  Frees the closed dialogs' widgets, each group's children first.
   procedure Collect is
      procedure Free_Window is new Ada.Unchecked_Deallocation (Windows.Double_Window'Class, Window_Access);
      procedure Free_Box is new Ada.Unchecked_Deallocation (Boxes.Box'Class, Box_Access);
      procedure Free_Input is new Ada.Unchecked_Deallocation (Texts.Text_Input'Class, Widgets.Input_Access);
      procedure Free_Check is new Ada.Unchecked_Deallocation (Checks.Check_Button'Class, Check_Access);
      procedure Free_Button is new Ada.Unchecked_Deallocation (Buttons.Button'Class, Widgets.Button_Access);
      procedure Free_Browser is
        new Ada.Unchecked_Deallocation (Hold.Hold_Browser'Class, Widgets.Browser_Access);
      procedure Free_Choice is new Ada.Unchecked_Deallocation (Choices.Choice'Class, Widgets.Choice_Access);
      procedure Free_Spinner is
        new Ada.Unchecked_Deallocation (Spinners.Spinner'Class, Widgets.Spinner_Access);
   begin
      for D of Closed loop
         Free_Box (D.Info);
         if D.Abilities /= null then
            Trait_Panel.Free (D.Abilities);
            Trait_Panel.Free (D.Weaknesses);
            Free_Button (D.Mods_Button);
            Widgets.Free (D.End_Box);
         end if;
         Free_Browser (D.Spells);
         Free_Input (D.Spell_Name);
         Free_Choice (D.Spell_Ability);
         Free_Spinner (D.Spell_Level);
         if D.Spell_Help /= null then
            Widgets.Free (D.Spell_Help);
         end if;
         Free_Button (D.Add_Spell_Button);
         Free_Button (D.Change_Spell_Button);
         Free_Button (D.Remove_Spell_Button);
         if D.Spell_End /= null then
            Widgets.Free (D.Spell_End);
         end if;
         Free_Input (D.Partner_Name);
         Free_Check (D.Fragment);
         Free_Check (D.Combat);
         Free_Browser (D.Attacks);
         Free_Button (D.Add_Attack_Button);
         Free_Button (D.Edit_Attack_Button);
         Free_Button (D.Remove_Attack_Button);
         for B of D.Numbers loop
            if B /= null then
               Widgets.Free (B);
            end if;
         end loop;
         Free_Button (D.Close_Button);
         Free_Window (D.Dialog);
      end loop;
      Closed.Clear;
   end Collect;

   procedure Free_Closed is
   begin
      FLTK.Static.Remove_Timeout (Collect'Access);
      Collect;
   end Free_Closed;

   procedure Finish is
      D : constant Done_Handler := On_Done;
   begin
      Open.Dialog.Hide;
      Closed.Append (Open);
      Open := (others => <>);
      if not FLTK.Static.Has_Timeout (Collect'Access) then
         FLTK.Static.Add_Timeout (0.0, Collect'Access);
      end if;
      On_Done := null;
      The_Character := null;
      The_Trait := null;
      The_Partner := null;
      if D /= null then
         D.all;
      end if;
   end Finish;

   procedure Close_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if Attack_Dialog.Dialog /= null then
         return;  --  it is above this one: it closes first
      end if;
      Finish;
   end Close_Action;

   procedure Build_Form is
   begin
      Panels (40, 300);
      Open.Abilities.Show (Calc.Sheet (The_Character), Calc.Trait (The_Trait), The_Character);
      Open.Weaknesses.Show (Calc.Sheet (The_Character), Calc.Trait (The_Trait), The_Character);
   end Build_Form;

   procedure Build_Spells is
      Y : Integer;

      function Button (X : Integer; Label : String) return Widgets.Button_Access is
         B : constant Widgets.Button_Access := new Buttons.Button'(Buttons.Forge.Create (X, Y, 70, Row, Label));
      begin
         B.Set_Callback (Spell_Button_Action'Access);
         return B;
      end Button;

   begin
      Open.Spells := new Hold.Hold_Browser'(Hold.Forge.Create (10, 60, Width - 20, 300, "Spells"));
      Open.Spells.Set_Alignment (FLTK.Align_Top_Left);
      Open.Spells.Set_Format_Character (Standard.Character'Val (0));  --  names are text, never format codes
      Open.Spells.Set_Callback (Spells_Action'Access);
      Open.Spells.Set_Column_Widths ([260, 320]);
      Y := 370;
      Open.Spell_Name := new Texts.Text_Input'(Texts.Forge.Create (70, Y, 250, Row, "Name"));
      The_Cast_Kind :=
        (if Rules.Has (The_Trait.Item, Rules.Casts_Weaknesses) then Rules.Weakness else Rules.Ability);
      Open.Spell_Ability := new Choices.Choice'
        (Choices.Forge.Create (400, Y, 290, Row,
                               (if The_Cast_Kind = Rules.Weakness then "Weakness" else "Ability")));
      for I in 0 .. Rules.Count (The_Cast_Kind) - 1 loop
         Open.Spell_Ability.Add (Rules.Label (Rules.Get (The_Cast_Kind, I)), null);
      end loop;
      Open.Spell_Ability.Set_Callback (Spell_Ability_Action'Access);
      Open.Spell_Help := Widgets.Open_Help_Button (695, Y, 0);
      Y := Y + Row + 5;
      Open.Spell_Level := new Spinners.Spinner'(Spinners.Forge.Create (70, Y, 60, Row, "level"));
      if The_Cast_Kind = Rules.Weakness then
         Open.Spell_Level.Set_Range (-3.0, -1.0);
         Open.Spell_Level.Set_Value (-1.0);
      else
         Open.Spell_Level.Set_Range (1.0, 5.0);
         Open.Spell_Level.Set_Value (1.0);
      end if;
      Open.Spell_End := Number_Box (200, Y, "END");
      Open.Spell_End.Set_Alignment (FLTK.Align_Left);
      Open.Spell_End.Allow_Plus := True;
      Y := Y + Row + 5;
      Open.Add_Spell_Button := Button (10, "Add");
      Open.Change_Spell_Button := Button (85, "Change");
      Open.Remove_Spell_Button := Button (160, "Remove");
      Show_Spells (0);
   end Build_Spells;

   procedure Build_Partner is
      Y : Integer;

      function Check (X : Integer; Label : String; On : Boolean) return Check_Access is
         B : constant Check_Access := new Checks.Check_Button'(Checks.Forge.Create (X, 40, 200, Row, Label));
      begin
         B.Set_State (if On then Buttons.On else Buttons.Off);
         B.Set_Callback (Partner_Text_Action'Access);
         return B;
      end Check;

      function Button (X : Integer; Label : String) return Widgets.Button_Access is
         B : constant Widgets.Button_Access := new Buttons.Button'(Buttons.Forge.Create (X, Y, 70, Row, Label));
      begin
         B.Set_Callback (Attack_Button_Action'Access);
         return B;
      end Button;

      procedure Number (Which : Sheet_Number; X, Y : Integer; Label : String) is
      begin
         Open.Numbers (Which) := Number_Box (X, Y, Label);
         Open.Numbers (Which).Set_Target (new Sheet_Target'(Which => Which));
      end Number;

   begin
      Open.Partner_Name := new Texts.Text_Input'(Texts.Forge.Create (60, 40, 250, Row, "Name"));
      Open.Partner_Name.Set_When (FLTK.When_Changed);
      Open.Partner_Name.Set_Callback (Partner_Text_Action'Access);
      Open.Partner_Name.Set_Value (To_String (The_Partner.Name));
      Open.Fragment := Check (330, "a Fragment", The_Partner.Is_Fragment);
      Open.Combat := Check (540, "combat stats", The_Partner.Has_Combat);
      Panels (70, 170);
      Open.Abilities.Show (Calc.Sheet (The_Partner), null, The_Character);
      Open.Weaknesses.Show (Calc.Sheet (The_Partner), null, The_Character);
      Y := Open.Mods_Button.Get_Y + Row + 10;
      Open.Attacks := new Hold.Hold_Browser'(Hold.Forge.Create (10, Y + 20, Width - 20, 100, "Attacks"));
      Open.Attacks.Set_Alignment (FLTK.Align_Top_Left);
      Open.Attacks.Set_Format_Character (Standard.Character'Val (0));
      Open.Attacks.Set_Column_Widths ([300, 100, 100]);
      Y := Y + 125;
      Open.Add_Attack_Button := Button (10, "Add...");
      Open.Edit_Attack_Button := Button (85, "Edit...");
      Open.Remove_Attack_Button := Button (160, "Remove");
      Y := Y + Row + 25;
      Number (Defense_Number, 10, Y, "DEFENSE");
      Number (Barrier_Number, 130, Y, "Barrier DEFENSE");
      Number (Incorporeal_Number, 130, Y + 50, "Incorporeal DEFENSE");
      Number (Health_Number, 250, Y, "HEALTH");
      Number (Endurance_Number, 370, Y, "ENDURANCE");
      Number (Reserve_Number, 490, Y, "Reserve");
      Number (TV_Number, 610, Y, "TV");
      Show_Attacks (0);
   end Build_Partner;

   procedure Edit (C : not null Character.Character_Access; T : not null Character.Trait;
                   Done : Done_Handler) is
      H : Integer;
   begin
      The_Character := C;
      The_Trait := T;
      On_Done := Done;
      The_Mode := T.Item.Linked;
      The_Partner := null;
      if The_Mode in Rules.Partner | Rules.Machine then
         if T.Partner = null then
            T.Partner := Calc.Sheet (Character.New_Partner (T));
            if Changed /= null then
               Changed.all;
            end if;
         end if;
         The_Partner := Character.Character_Access (T.Partner);
      end if;
      H := (case The_Mode is
              when Rules.Form   => Form_H,
              when Rules.Spells => Spells_H,
              when others       => Partner_H);
      Open.Dialog := new Windows.Double_Window'(Windows.Forge.Create (Width, H, Rules.Label (T.Item)));
      Open.Dialog.Begin_Current;
      Open.Info := new Boxes.Box'(Boxes.Forge.Create (10, 5, Width - 20, Row, ""));
      Open.Info.Set_Alignment (FLTK."+" (FLTK.Align_Left, FLTK.Align_Inside));
      case The_Mode is
         when Rules.Form =>
            Build_Form;
         when Rules.Spells =>
            Open.Info.Set_Label
              ("Magic +" & Image (T.Level)
               & (if Rules.Has (T.Item, Rules.Casts_Weaknesses)
                  then ": a curse casts a Weakness; its END is by the Magic's level and the Weakness's size (p. 58)."
                  else ": a spell's END is by the Magic's level and its own (p. 58), more for Barrier."));
            Build_Spells;
         when Rules.Partner | Rules.Machine =>
            Open.Info.Set_Label
              (if The_Mode = Rules.Partner then "A Companion's sheet: a Secondary NPC's (p. 52, 123)."
               else "A Vehicle's sheet (p. 64).");
            Build_Partner;
         when Rules.No_Link =>
            null;
      end case;
      Open.Close_Button := new Buttons.Button'(Buttons.Forge.Create (Width - 95, H - 35, 85, Row, "Close"));
      Open.Close_Button.Set_Callback (Close_Action'Access);
      Open.Dialog.End_Current;
      Open.Dialog.Set_Callback (Close_Action'Access);  --  the close button
      Open.Dialog.Set_Modal;
      Show_All;
      Open.Dialog.Show;
   end Edit;

   procedure Close is
   begin
      Finish;
   end Close;

end Ova_Cg.Linked_Dialog;
