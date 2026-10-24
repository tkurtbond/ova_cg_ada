with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with FLTK.Static;
with FLTK.Widgets.Buttons.Enter;
with Ova_Cg.Calc;
with Ova_Cg.Rules;

package body Ova_Cg.Settings is

   package Buttons renames Widgets.Buttons;
   package Spinners renames Widgets.Spinners;
   package Enter renames FLTK.Widgets.Buttons.Enter;

   Width  : constant := 560;
   Height : constant := 300;
   Row    : constant := 25;

   Base_Zero_Default : constant := 5;
   Ceiling_Default   : constant := 15;
   Starting_Default  : constant := 5;
   Half_Cost_Page    : constant := 57;

   type Help_Buttons is array (1 .. 6) of Widgets.Help_Button_Access;

   --  The dialog's widgets: what Finish hands to Collect.
   type Parts is record
      Dialog : Window_Access;
      Base_Zero, Power_Ceiling, Starting_Levels, Scaled_Cost, Half_Cost, Combined : Check_Access;
      Base_Zero_Range, Ceiling, Starting : Widgets.Spinner_Access;
      Helps : Help_Buttons;
      OK_Button, Cancel_Button : Widgets.Button_Access;
   end record;

   package Parts_Vectors is new Ada.Containers.Vectors (Positive, Parts);

   Open   : Parts;                 --  the dialog open, if any
   Closed : Parts_Vectors.Vector;  --  closed, for Collect to free

   The_Character : Character.Character_Access;
   Old           : Calc.Options_Record;  --  as they were, for Cancel
   Old_Has       : Boolean := False;
   On_Done       : Done_Handler;

   function Dialog return Window_Access is (Open.Dialog);
   function Base_Zero return Check_Access is (Open.Base_Zero);
   function Power_Ceiling return Check_Access is (Open.Power_Ceiling);
   function Starting_Levels return Check_Access is (Open.Starting_Levels);
   function Scaled_Cost return Check_Access is (Open.Scaled_Cost);
   function Half_Cost return Check_Access is (Open.Half_Cost);
   function Combined return Check_Access is (Open.Combined);
   function Base_Zero_Range return Widgets.Spinner_Access is (Open.Base_Zero_Range);
   function Ceiling return Widgets.Spinner_Access is (Open.Ceiling);
   function Starting return Widgets.Spinner_Access is (Open.Starting);
   function OK_Button return Widgets.Button_Access is (Open.OK_Button);
   function Cancel_Button return Widgets.Button_Access is (Open.Cancel_Button);

   --  Whether A and B are the same limits: a rule's number counts only
   --  while the rule is on, since only then is it used or saved.
   function Same (A, B : Calc.Options_Record) return Boolean is
     (A.Base_Zero = B.Base_Zero and then (not A.Base_Zero or else A.Base_Zero_Range = B.Base_Zero_Range)
      and then A.Power_Ceiling = B.Power_Ceiling and then (not A.Power_Ceiling or else A.Ceiling = B.Ceiling)
      and then A.Starting_Levels = B.Starting_Levels
      and then (not A.Starting_Levels or else A.Starting = B.Starting)
      and then A.Scaled_Cost = B.Scaled_Cost and then A.Half_Cost_Knowledge = B.Half_Cost_Knowledge
      and then A.Combined_Effectiveness = B.Combined_Effectiveness);

   procedure Set_Active (W : in out FLTK.Widgets.Widget'Class; Active : Boolean) is
   begin
      if Active then
         W.Activate;
      else
         W.Deactivate;
      end if;
   end Set_Active;

   --  The spinners active only with their rule, half cost only with one
   --  of the rules it applies under (p. 57).
   procedure Show_Active is
   begin
      Set_Active (Open.Base_Zero_Range.all, Open.Base_Zero.Is_On);
      Set_Active (Open.Ceiling.all, Open.Power_Ceiling.Is_On);
      Set_Active (Open.Starting.all, Open.Starting_Levels.Is_On);
      Set_Active (Open.Half_Cost.all,
                  Open.Base_Zero.Is_On or else Open.Power_Ceiling.Is_On or else Open.Scaled_Cost.Is_On);
   end Show_Active;

   --  The character's options set from the dialog.  The block is saved
   --  while any rule is on, or if the file had one and nothing changed.
   procedure Take is
      O : constant Calc.Options_Record :=
        (Base_Zero              => Open.Base_Zero.Is_On,
         Base_Zero_Range        => Widgets.Spin_Value (Open.Base_Zero_Range.all),
         Power_Ceiling          => Open.Power_Ceiling.Is_On,
         Ceiling                => Widgets.Spin_Value (Open.Ceiling.all),
         Starting_Levels        => Open.Starting_Levels.Is_On,
         Starting               => Widgets.Spin_Value (Open.Starting.all),
         Scaled_Cost            => Open.Scaled_Cost.Is_On,
         Half_Cost_Knowledge    => Open.Half_Cost.Is_On,
         Combined_Effectiveness => Open.Combined.Is_On);
   begin
      if Same (O, The_Character.Options) then
         return;
      end if;
      The_Character.Options := O;
      The_Character.Has_Options := O.Base_Zero or else O.Power_Ceiling or else O.Starting_Levels
        or else O.Scaled_Cost or else O.Half_Cost_Knowledge or else O.Combined_Effectiveness
        or else (Old_Has and then Same (O, Old));
      if Changed /= null then
         Changed.all;
      end if;
   end Take;

   procedure Change_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Show_Active;
      Take;
   end Change_Action;

   --  Frees the closed dialogs' widgets, the window's children first.
   procedure Collect is
      procedure Free_Window is new Ada.Unchecked_Deallocation (Windows.Double_Window'Class, Window_Access);
      procedure Free_Check is new Ada.Unchecked_Deallocation (Checks.Check_Button'Class, Check_Access);
      procedure Free_Spinner is
        new Ada.Unchecked_Deallocation (Spinners.Spinner'Class, Widgets.Spinner_Access);
      procedure Free_Button is new Ada.Unchecked_Deallocation (Buttons.Button'Class, Widgets.Button_Access);
   begin
      for D of Closed loop
         Free_Check (D.Base_Zero);
         Free_Check (D.Power_Ceiling);
         Free_Check (D.Starting_Levels);
         Free_Check (D.Scaled_Cost);
         Free_Check (D.Half_Cost);
         Free_Check (D.Combined);
         Free_Spinner (D.Base_Zero_Range);
         Free_Spinner (D.Ceiling);
         Free_Spinner (D.Starting);
         for H of D.Helps loop
            Widgets.Free (H);
         end loop;
         Free_Button (D.OK_Button);
         Free_Button (D.Cancel_Button);
         Free_Window (D.Dialog);
      end loop;
      Closed.Clear;
   end Collect;

   procedure Finish (Accepted : Boolean) is
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
      if D /= null then
         D (Accepted);
      end if;
   end Finish;

   procedure OK_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      Finish (True);
   end OK_Action;

   procedure Cancel_Action (W : in out FLTK.Widgets.Widget'Class) is
      pragma Unreferenced (W);
   begin
      if not Same (The_Character.Options, Old) or else The_Character.Has_Options /= Old_Has then
         The_Character.Options := Old;
         The_Character.Has_Options := Old_Has;
         if Changed /= null then
            Changed.all;
         end if;
      end if;
      Finish (False);
   end Cancel_Action;

   procedure Edit (C : not null Character.Character_Access; Done : Done_Handler) is
      O : constant Calc.Options_Record := C.Options;
      Y : Integer := 10;
      H : Natural := 0;

      function Check (Label : String; On : Boolean) return Check_Access is
         B : constant Check_Access := new Checks.Check_Button'(Checks.Forge.Create (10, Y, 330, Row, Label));
      begin
         B.Set_State (if On then Buttons.On else Buttons.Off);
         B.Set_Callback (Change_Action'Access);
         return B;
      end Check;

      --  A spinner from Low to High showing Value, or Default if the
      --  rule is off.
      function Spinner (Label : String; Low, High : Integer; On : Boolean; Value, Default : Integer)
        return Widgets.Spinner_Access is
         S : constant Widgets.Spinner_Access :=
           new Spinners.Spinner'(Spinners.Forge.Create (440, Y, 70, Row, Label));
      begin
         S.Set_Range (Long_Float (Low), Long_Float (High));
         S.Set_Value (Long_Float (if On then Value else Default));
         S.Set_Callback (Change_Action'Access);
         return S;
      end Spinner;

      procedure Help (Page : Positive) is
      begin
         H := H + 1;
         Open.Helps (H) := Widgets.Open_Help_Button (Width - 35, Y, Page);
         Y := Y + Row + 10;
      end Help;

   begin
      The_Character := C;
      On_Done := Done;
      Old := C.Options;
      Old_Has := C.Has_Options;
      Open.Dialog := new Windows.Double_Window'(Windows.Forge.Create (Width, Height, "Limits"));
      Open.Dialog.Begin_Current;
      Open.Base_Zero := Check ("Base Zero: the Character Total within", O.Base_Zero);
      Open.Base_Zero_Range := Spinner ("+/-", 0, 99, O.Base_Zero, O.Base_Zero_Range, Base_Zero_Default);
      Help (Rules.Limits_Page);
      Open.Starting_Levels := Check ("Starting levels, plus the Weaknesses'", O.Starting_Levels);
      Open.Starting := Spinner ("levels", 0, 999, O.Starting_Levels, O.Starting, Starting_Default);
      Help (Rules.Limits_Page);
      Open.Power_Ceiling := Check ("Power Ceiling: the Abilities at most", O.Power_Ceiling);
      Open.Ceiling := Spinner ("levels", 1, 999, O.Power_Ceiling, O.Ceiling, Ceiling_Default);
      Help (Rules.Limits_Page);
      Open.Scaled_Cost := Check ("Scaled Cost: +1 to +5 cost 1, 2, 4, 8, 15", O.Scaled_Cost);
      Help (Rules.Limits_Page);
      Open.Half_Cost := Check ("Knowledge and Ineptitude at half cost", O.Half_Cost_Knowledge);
      Help (Half_Cost_Page);
      Open.Combined := Check ("Combined Effectiveness: at most +5 to a roll", O.Combined_Effectiveness);
      Help (Rules.Limits_Page);
      Open.OK_Button := new Enter.Enter_Button'(Enter.Forge.Create (Width - 190, Height - 35, 85, Row, "OK"));
      Open.OK_Button.Set_Callback (OK_Action'Access);
      Open.Cancel_Button := new Buttons.Button'(Buttons.Forge.Create (Width - 95, Height - 35, 85, Row, "Cancel"));
      Open.Cancel_Button.Set_Callback (Cancel_Action'Access);
      Open.Dialog.End_Current;
      Open.Dialog.Set_Callback (Cancel_Action'Access);  --  the close button
      Open.Dialog.Set_Modal;
      Show_Active;
      Open.Dialog.Show;
   end Edit;

   procedure Cancel is
   begin
      Cancel_Action (Open.Cancel_Button.all);
   end Cancel;

end Ova_Cg.Settings;
