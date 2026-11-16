with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with FLTK.Static;
with Ova_Cg.Calc;
with Ova_Cg.Rules;

package body Ova_Cg.Attack_Dialog is

   package Buttons renames Widgets.Buttons;
   package Texts renames Widgets.Texts;

   use type Calc.Modifier;
   use type Character.Attack;
   use type Rules.Cost_Kind_Type;
   use type Rules.Item;

   Width     : constant := 700;
   Height    : constant := 550;
   Row       : constant := 25;
   Max_Count : constant := 10;  --  the count's bound for an item taken as often as wanted

   Tab : constant Standard.Character := ASCII.HT;

   function Image (I : Integer) return String is
     (Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Left));

   --  The dialog's widgets: what Finish hands to Collect.
   type Parts is record
      Dialog                : Window_Access;
      Name_In, Affinity_In  : Widgets.Input_Access;
      Description_In        : Multiline_Access;
      Telekinetic           : Check_Access;
      Transformed           : Check_Access;
      Perks, Flaws          : Mod_Panel_Access;
      Roll, DX, End_Box     : Widgets.Number_Box_Access;
      OK_Button, Cancel_Button : Widgets.Button_Access;
   end record;

   package Parts_Vectors is new Ada.Containers.Vectors (Positive, Parts);

   Open    : Parts;                 --  the dialog open, if any
   Closed  : Parts_Vectors.Vector;  --  closed, for Collect to free

   The_Character : Character.Character_Access;
   The_Attack    : Character.Attack;  --  what is edited: an attack,
   The_Trait     : Character.Trait;   --  or an Ability's Perks and Flaws
   New_Attack    : Boolean := False;
   Saved_Attack  : Character.Attack_Record;
   Saved_End     : Calc.Number;
   Saved_Mods    : Calc.Modifier;
   On_Done       : Done_Handler;

   function Dialog return Window_Access is (Open.Dialog);
   function Name_In return Widgets.Input_Access is (Open.Name_In);
   function Affinity_In return Widgets.Input_Access is (Open.Affinity_In);
   function Description_In return Multiline_Access is (Open.Description_In);
   function Telekinetic return Check_Access is (Open.Telekinetic);
   function Transformed return Check_Access is (Open.Transformed);
   function Perks return Mod_Panel_Access is (Open.Perks);
   function Flaws return Mod_Panel_Access is (Open.Flaws);
   function Roll return Widgets.Number_Box_Access is (Open.Roll);
   function DX return Widgets.Number_Box_Access is (Open.DX);
   function End_Box return Widgets.Number_Box_Access is (Open.End_Box);
   function OK_Button return Widgets.Button_Access is (Open.OK_Button);
   function Cancel_Button return Widgets.Button_Access is (Open.Cancel_Button);

   procedure Say (Text : String) is
   begin
      if Tell /= null then
         Tell (Text);
      end if;
   end Say;

   --  The list edited.
   function Mods return Calc.Modifier is
     (if The_Attack /= null then The_Attack.Mods else The_Trait.Mods);

   procedure Set_Mods (List : Calc.Modifier) is
   begin
      if The_Attack /= null then
         The_Attack.Mods := List;
      else
         The_Trait.Mods := List;
      end if;
   end Set_Mods;

   procedure Show_Numbers is
   begin
      if The_Attack /= null then
         Open.Roll.Display;
         Open.DX.Display;
      end if;
      Open.End_Box.Display;
   end Show_Numbers;

   procedure Recompute is
   begin
      Character.Recompute (The_Character);
      Show_Numbers;
   end Recompute;

   --  ---- Numbers ----

   type Which_Number is (Roll_Number, DX_Number, End_Number);

   --  The attack's ROLL, DX or END, or the Ability's END.
   type Number_Target is new Widgets.Target with record
      Which : Which_Number;
   end record;

   overriding function Get (T : Number_Target) return Calc.Number;
   overriding procedure Put (T : in out Number_Target; N : Calc.Number);

   overriding function Get (T : Number_Target) return Calc.Number is
   begin
      if The_Attack = null then
         return The_Trait.End_Cost;
      end if;
      case T.Which is
         when Roll_Number => return The_Attack.Roll;
         when DX_Number   => return The_Attack.DX;
         when End_Number  => return The_Attack.End_Cost;
      end case;
   end Get;

   overriding procedure Put (T : in out Number_Target; N : Calc.Number) is
   begin
      if The_Attack = null then
         The_Trait.End_Cost := N;
         return;
      end if;
      case T.Which is
         when Roll_Number => The_Attack.Roll := N;
         when DX_Number   => The_Attack.DX := N;
         when End_Number  => The_Attack.End_Cost := N;
      end case;
   end Put;

   procedure Number_Changed (B : in out Widgets.Number_Box'Class; Good : Boolean) is
   begin
      if not Good then
         Say ("Not a number for " & B.Get_Label & ". The computed number is used.");
      end if;
      Recompute;
   end Number_Changed;

   function Number_Box (Which : Which_Number; X, Y : Integer; Label : String)
     return Widgets.Number_Box_Access is
      B : constant Widgets.Number_Box_Access := Widgets.Open_Number_Box (X, Y, Label);
   begin
      B.Set_Target (new Number_Target'(Which => Which));
      B.Changed := Number_Changed'Access;
      return B;
   end Number_Box;

   --  ---- The Perks and Flaws ----

   function Modifier_Of (M : Calc.Modifier) return Character.Modifier is
     (Character.Modifier (M));

   --  The cost M adds: its own, or its item's, each time.
   function Cost (M : Character.Modifier) return Integer is
     (if M.Item = null or else M.Item.Cost_Kind /= Rules.Fixed_Cost then M.Times * M.Cost
      else M.Times * M.Item.Cost);

   overriding procedure Fill (P : in out Mod_Panel) is
      L    : Calc.Modifier := Mods;
      M    : Character.Modifier;
      Line : Unbounded_String;
      C    : Integer;
   begin
      P.Shown.Clear;
      while L /= null loop
         M := Modifier_Of (L);
         if M.Is_Flaw = P.Is_Flaw then
            P.Shown.Append (M);
            Line := M.Name;
            if M.Has_Detail then
               Append (Line, " (" & M.Detail & ")");
            end if;
            if M.Times /= 1 then
               Append (Line, " x" & Image (M.Times));
            end if;
            C := Cost (M);
            Append (Line, Tab & (if C > 0 then "+" else "") & Image (C) & Tab);
            Append (Line, Rules.Page_Text (M.Item));
            P.Browser.Add (To_String (Line));
         end if;
         L := L.Next;
      end loop;
   end Fill;

   --  The line M is on.
   function Line_Of (P : Mod_Panel'Class; M : Calc.Modifier) return Positive is
      I : Natural := 0;
      L : Calc.Modifier := Mods;
   begin
      while L /= null and then L /= M loop
         if Modifier_Of (L).Is_Flaw = P.Is_Flaw then
            I := I + 1;
         end if;
         L := L.Next;
      end loop;
      return I + 1;
   end Line_Of;

   --  The count's bounds and the cost's field, for the item chosen.
   overriding procedure Chosen (P : in out Mod_Panel) is
      It  : Rules.Item;
      Max : Positive;
   begin
      Widgets.Chosen (Widgets.Panel (P));
      It := P.Item;
      if It = null then
         return;
      end if;
      Max := Integer'Min (It.Max_Times, Max_Count);
      P.Spinner.Set_Range (1.0, Long_Float (Max));
      if P.Spinner.Get_Integer_Value > Max then
         P.Spinner.Set_Value (Long_Float (Max));
      end if;
      if Max > 1 then
         P.Spinner.Activate;
      else
         P.Spinner.Set_Value (1.0);
         P.Spinner.Deactivate;
      end if;
      if It.Cost_Kind = Rules.Fixed_Cost then
         P.Text.Set_Value ("");
         P.Text.Deactivate;
      else
         P.Text.Activate;
         if It.Cost_Kind = Rules.Range_Cost and then P.Text.Get_Value = "" then
            P.Text.Set_Value (Image (It.Min_Cost));
         end if;
      end if;
   end Chosen;

   overriding procedure Load (P : in out Mod_Panel; Line : Positive) is
      M : constant Character.Modifier := P.Shown (Line);
   begin
      P.Choose (M.Item);
      P.Spinner.Set_Value (Long_Float (M.Times));
      if M.Item = null or else M.Item.Cost_Kind /= Rules.Fixed_Cost then
         P.Text.Set_Value (Image (M.Cost));
      else
         P.Text.Set_Value ("");
      end if;
   end Load;

   --  The controls' count and cost; False, said why, if the cost isn't
   --  an integer where one is needed.
   function Read (P : Mod_Panel'Class; It : not null Rules.Item; Times, Cost : out Integer)
     return Boolean is
      N    : Calc.Number;
      Good : Boolean := True;
   begin
      Times := P.Spinner.Get_Integer_Value;
      Cost := 0;
      if It.Cost_Kind /= Rules.Fixed_Cost then
         Calc.Clear (N);
         Good := Calc.Parse (P.Text.Get_Value, False, False, N) and then Calc.Overridden (N);
         if Good then
            Cost := Calc.Value (N);
         else
            Say ("The cost must be a whole number, such as -10.");
         end if;
      end if;
      return Good;
   end Read;

   overriding function Add (P : in out Mod_Panel) return Natural is
      It          : constant Rules.Item := P.Item;
      Times, Cost : Integer;
      M           : Character.Modifier;
      List        : Calc.Modifier;
   begin
      if It = null then
         Say ("Choose a name first.");
         return 0;
      end if;
      if not Read (P, It, Times, Cost) then
         return 0;
      end if;
      M := Character.New_Modifier (It, P.Is_Flaw, Times, Cost);
      List := Mods;
      Character.Insert_Modifier (List, M);
      Set_Mods (List);
      Recompute;
      return Line_Of (P, Calc.Modifier (M));
   end Add;

   overriding function Change (P : in out Mod_Panel; Line : Positive) return Natural is
      M           : constant Character.Modifier := P.Shown (Line);
      It          : Rules.Item := P.Item;
      Times, Cost : Integer;
      List        : Calc.Modifier;
   begin
      if It = null then
         It := M.Item;
      end if;
      if It = null then
         return 0;  --  a name the tables don't have: only Remove
      end if;
      if not Read (P, It, Times, Cost) then
         return 0;
      end if;
      List := Mods;
      Character.Remove_Modifier (List, Calc.Modifier (M));
      if It /= M.Item then
         M.Item := It;
         M.Name := It.Name;
         M.Has_Detail := False;
         M.Detail := Null_Unbounded_String;
      end if;
      M.Times := Times;
      M.Cost := Cost;
      M.Has_Cost := It.Cost_Kind /= Rules.Fixed_Cost;
      Character.Insert_Modifier (List, M);
      Set_Mods (List);
      Recompute;
      return Line_Of (P, Calc.Modifier (M));
   end Change;

   --  Frees the Perk or Flaw removed.
   overriding function Remove (P : in out Mod_Panel; Line : Positive) return Boolean is
      M    : Calc.Modifier := Calc.Modifier (P.Shown (Line));
      List : Calc.Modifier := Mods;
   begin
      Character.Remove_Modifier (List, M);
      Set_Mods (List);
      Recompute;
      P.Shown.Clear;  --  until Fill: none holds M
      Calc.Free_Mods (M);
      return True;
   end Remove;

   function Panel (X, Y : Integer; Is_Flaw : Boolean) return Mod_Panel_Access is
      P : constant Mod_Panel_Access := new Mod_Panel;
   begin
      P.Is_Flaw := Is_Flaw;
      Widgets.Open_Panel (Widgets.Panel_Access (P), X, Y, 335, 200,
                          (if Is_Flaw then Rules.Flaw else Rules.Perk),
                          (if Is_Flaw then "Flaws" else "Perks"), "times", "cost");
      P.Browser.Set_Column_Widths ([-1, 50, 60]);  --  the name takes what the cost's and page's leave
      P.Spinner.Set_Range (1.0, 1.0);
      P.Spinner.Set_Value (1.0);
      P.Refresh (0);
      return P;
   end Panel;

   --  ---- Opening and closing ----

   --  Frees the closed dialogs' widgets, each group's children first.
   procedure Collect is
      procedure Free_Window is new Ada.Unchecked_Deallocation (Windows.Double_Window'Class, Window_Access);
      procedure Free_Input is new Ada.Unchecked_Deallocation (Texts.Text_Input'Class, Widgets.Input_Access);
      procedure Free_Multiline is
        new Ada.Unchecked_Deallocation (Multiline.Multiline_Input'Class, Multiline_Access);
      procedure Free_Check is new Ada.Unchecked_Deallocation (Checks.Check_Button'Class, Check_Access);
      procedure Free_Panel is new Ada.Unchecked_Deallocation (Mod_Panel'Class, Mod_Panel_Access);
      procedure Free_Button is new Ada.Unchecked_Deallocation (Buttons.Button'Class, Widgets.Button_Access);
   begin
      for D of Closed loop
         Free_Input (D.Name_In);
         Free_Input (D.Affinity_In);
         Free_Multiline (D.Description_In);
         Free_Check (D.Telekinetic);
         Free_Check (D.Transformed);
         Widgets.Close_Panel (Widgets.Panel_Access (D.Perks));
         Free_Panel (D.Perks);
         Widgets.Close_Panel (Widgets.Panel_Access (D.Flaws));
         Free_Panel (D.Flaws);
         Widgets.Free (D.Roll);
         Widgets.Free (D.DX);
         Widgets.Free (D.End_Box);
         Free_Button (D.OK_Button);
         Free_Button (D.Cancel_Button);
         Free_Window (D.Dialog);
      end loop;
      Closed.Clear;
   end Collect;

   procedure Free_Closed is
   begin
      FLTK.Static.Remove_Timeout (Collect'Access);
      Collect;
   end Free_Closed;

   procedure Finish (Changed : Boolean) is
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
      The_Attack := null;
      The_Trait := null;
      Saved_Mods := null;
      if D /= null then
         D (Changed);
      end if;
   end Finish;

   procedure OK_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if The_Attack /= null then
         declare
            Name : constant String := Character.Trim (Open.Name_In.Get_Value);
         begin
            if Name = "" then
               Say ("The attack needs a name.");
               return;
            end if;
            The_Attack.Name := To_Unbounded_String (Name);
         end;
         Character.Set_Text (The_Attack.Has_Affinity, The_Attack.Affinity,
                             To_Unbounded_String (Character.Trim (Open.Affinity_In.Get_Value)));
         Character.Set_Text (The_Attack.Has_Description, The_Attack.Description,
                             To_Unbounded_String (Open.Description_In.Get_Value));
         The_Attack.Telekinetic := Open.Telekinetic.Is_On;
         The_Attack.Transformed := Open.Transformed.Is_On;
      end if;
      Calc.Free_Mods (Saved_Mods);
      Character.Recompute (The_Character);
      Finish (True);
   end OK_Action;

   --  Everything put back as it was.
   procedure Cancel_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
      List : Calc.Modifier;
      Next : Calc.Attack;
      Gone : Calc.Attack;
   begin
      if The_Attack = null then
         List := The_Trait.Mods;
         Calc.Free_Mods (List);
         The_Trait.Mods := Saved_Mods;
         The_Trait.End_Cost := Saved_End;
      elsif New_Attack then
         Character.Remove_Attack (The_Character, Calc.Attack (The_Attack));
         Calc.Free_Mods (Saved_Mods);
         Gone := Calc.Attack (The_Attack);
         Calc.Free_Attacks (Gone);
      else
         List := The_Attack.Mods;
         Calc.Free_Mods (List);
         Next := The_Attack.Next;
         Character.Attack_Record (The_Attack.all) := Saved_Attack;
         The_Attack.Next := Next;
         The_Attack.Mods := Saved_Mods;
      end if;
      Saved_Mods := null;
      Character.Recompute (The_Character);
      Finish (False);
   end Cancel_Action;

   procedure Flag_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      The_Attack.Telekinetic := Open.Telekinetic.Is_On;
      The_Attack.Transformed := Open.Transformed.Is_On;
      Recompute;
   end Flag_Action;

   procedure Build (Title : String) is
      function Input (Y : Integer; Label : String) return Widgets.Input_Access is
        (new Texts.Text_Input'(Texts.Forge.Create (100, Y, 300, Row, Label)));

      function Check (Y : Integer; Label : String) return Check_Access is
         B : constant Check_Access := new Checks.Check_Button'(Checks.Forge.Create (420, Y, 260, Row, Label));
      begin
         B.Set_Callback (Flag_Action'Access);
         return B;
      end Check;

      function Button (X : Integer; Label : String) return Widgets.Button_Access is
        (new Buttons.Button'(Buttons.Forge.Create (X, Height - 35, 85, Row, Label)));

      Y : Integer;
   begin
      Open.Dialog := new Windows.Double_Window'(Windows.Forge.Create (Width, Height, Title));
      Open.Dialog.Begin_Current;
      Open.Name_In := Input (10, "Name");
      Open.Affinity_In := Input (40, "Affinity");
      Open.Telekinetic := Check (10, "made with Telekinesis");
      Open.Transformed := Check (40, "made in the transformed form");
      Open.Description_In :=
        new Multiline.Multiline_Input'(Multiline.Forge.Create (100, 70, 590, 60, "Description"));
      Open.Perks := Panel (10, 140, Is_Flaw => False);
      Open.Flaws := Panel (355, 140, Is_Flaw => True);
      Y := Open.Perks.Bottom + 30;
      Open.Roll := Number_Box (Roll_Number, 10, Y, "ROLL");
      Open.DX := Number_Box (DX_Number, 110, Y, "DX");
      Open.DX.Allow_Half := True;
      Open.End_Box := Number_Box (End_Number, 210, Y, "END");
      Open.OK_Button := Button (Width - 190, "OK");
      Open.OK_Button.Set_Callback (OK_Action'Access);
      Open.Cancel_Button := Button (Width - 95, "Cancel");
      Open.Cancel_Button.Set_Callback (Cancel_Action'Access);
      Open.Dialog.End_Current;
      Open.Dialog.Set_Callback (Cancel_Action'Access);  --  the close button
      Open.Dialog.Set_Modal;
   end Build;

   procedure Edit_Attack (C : not null Character.Character_Access; A : not null Character.Attack;
                          Is_New : Boolean; Done : Done_Handler) is
   begin
      The_Character := C;
      The_Attack := A;
      The_Trait := null;
      New_Attack := Is_New;
      On_Done := Done;
      Saved_Attack := Character.Attack_Record (A.all);
      Saved_Mods := Character.Copy_Modifiers (A.Mods);
      Build ("Attack");
      Open.Name_In.Set_Value (To_String (A.Name));
      Open.Affinity_In.Set_Value (To_String (A.Affinity));
      Open.Description_In.Set_Value (To_String (A.Description));
      Open.Telekinetic.Set_State (if A.Telekinetic then Buttons.On else Buttons.Off);
      Open.Transformed.Set_State (if A.Transformed then Buttons.On else Buttons.Off);
      Open.Perks.Refresh (0);
      Open.Flaws.Refresh (0);
      Character.Recompute (The_Character);
      Show_Numbers;
      Open.Dialog.Show;
   end Edit_Attack;

   procedure Edit_Mods (C : not null Character.Character_Access; T : not null Character.Trait;
                        Done : Done_Handler) is
   begin
      The_Character := C;
      The_Attack := null;
      The_Trait := T;
      New_Attack := False;
      On_Done := Done;
      Saved_End := T.End_Cost;
      Saved_Mods := Character.Copy_Modifiers (T.Mods);
      Build ((if T.Item /= null then Rules.Label (T.Item) else "an Ability"));
      Open.Name_In.Hide;
      Open.Affinity_In.Hide;
      Open.Description_In.Hide;
      Open.Telekinetic.Hide;
      Open.Transformed.Hide;
      Open.Roll.Hide;
      Open.DX.Hide;
      Open.Perks.Refresh (0);
      Open.Flaws.Refresh (0);
      Character.Recompute (The_Character);
      Show_Numbers;
      Open.Dialog.Show;
   end Edit_Mods;

   procedure OK is
   begin
      OK_Action (Open.OK_Button.all);
   end OK;

   procedure Cancel is
   begin
      Cancel_Action (Open.Cancel_Button.all);
   end Cancel;

end Ova_Cg.Attack_Dialog;
