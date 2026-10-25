with Ada.Unchecked_Deallocation;
with System;

package body Ova_Cg.Widgets is


   use type Rules.Item;
   use type System.Address;

   --  The box's tooltip: what an empty box means.
   Tooltip : constant String := "empty: use the computed value";

   procedure Free_Target is new Ada.Unchecked_Deallocation (Target'Class, Target_Access);

   procedure Free (T : in out Target_Access) is
   begin
      Free_Target (T);
   end Free;

   --  ---- Number_Box ----

   procedure Entry_Action (W : in out FLTK.Widgets.Widget'Class) is
   begin
      Entry_Input'Class (W).Box.Take;
   end Entry_Action;

   function Open_Number_Box (X, Y : Integer; Label : String) return not null Number_Box_Access is
      B : constant Number_Box_Access :=
        new Number_Box'(Groups.Forge.Create (X, Y, Width, Height, Label) with others => <>);
   begin
      B.Set_Alignment (FLTK.Align_Top);
      B.Shown := new Outputs.Output'(Outputs.Forge.Create (B.all, X, Y, Shown_Width, Height));
      B.Shown.Set_Tooltip ("computed");
      B.Entry_In := new Entry_Input'
        (Texts.Forge.Create (B.all, X + Shown_Width + Gap, Y, Entry_Width, Height) with Box => B);
      B.Entry_In.Set_Tooltip (Tooltip);
      B.Entry_In.Set_When (FLTK."+" (FLTK.When_Release, FLTK.When_Enter_Key));
      B.Entry_In.Set_Callback (Entry_Action'Access);
      return B;
   end Open_Number_Box;

   procedure Set_Target (B : in out Number_Box'Class; T : Target_Access) is
   begin
      if B.Target /= T then
         Free (B.Target);
         B.Target := T;
      end if;
   end Set_Target;

   procedure Display (B : in out Number_Box'Class) is
   begin
      if B.Target = null then
         B.Shown.Set_Value ("");
         B.Entry_In.Set_Value ("");
      else
         declare
            N : constant Calc.Number := B.Target.Get;
         begin
            B.Shown.Set_Value (Calc.Computed_Text (N));
            B.Entry_In.Set_Value ((if Calc.Overridden (N) then Calc.Text (N) else ""));
         end;
      end if;
   end Display;

   procedure Take (B : in out Number_Box'Class) is
      N  : Calc.Number;
      OK : Boolean;
   begin
      if B.Target = null then
         return;
      end if;
      N := B.Target.Get;
      OK := Calc.Parse (B.Entry_In.Get_Value, B.Allow_Half, B.Allow_Plus, N);
      if not OK then
         Calc.Clear (N);
      end if;
      B.Target.Put (N);
      B.Display;
      if B.Changed /= null then
         B.Changed (B, OK);
      end if;
   end Take;

   procedure Free (B : in out Number_Box_Access) is
      procedure Free_Output is new Ada.Unchecked_Deallocation (Outputs.Output'Class, Output_Access);
      procedure Free_Entry is new Ada.Unchecked_Deallocation (Entry_Input'Class, Entry_Access);
      procedure Free_Box is new Ada.Unchecked_Deallocation (Number_Box'Class, Number_Box_Access);
   begin
      if B /= null then
         Free_Output (B.Shown);
         Free_Entry (B.Entry_In);
         Free (B.Target);
         Free_Box (B);
      end if;
   end Free;

   --  ---- Help_Button ----

   procedure Help_Action (W : in out FLTK.Widgets.Widget'Class) is
      B : Help_Button'Class renames Help_Button'Class (W);
   begin
      if B.Page > 0 and Open_Page /= null then
         Open_Page (B.Page);
      end if;
   end Help_Action;

   function Open_Help_Button (X, Y : Integer; Page : Natural) return not null Help_Button_Access is
      B : constant Help_Button_Access :=
        new Help_Button'(Buttons.Forge.Create (X, Y, 25, 25, "?") with Page => Page);
   begin
      B.Set_Tooltip ("open the rulebook at this page");
      B.Set_Callback (Help_Action'Access);
      return B;
   end Open_Help_Button;

   procedure Free (B : in out Help_Button_Access) is
      procedure Free_Button is new Ada.Unchecked_Deallocation (Help_Button'Class, Help_Button_Access);
   begin
      Free_Button (B);
   end Free;

   --  ---- Panel ----

   Panels : Panel_Access;  --  the open ones

   function Item (P : Panel'Class) return Rules.Item is
      I : constant Natural := P.Choice.Chosen_Index;  --  1-based; 0: none
   begin
      if I in 1 .. Rules.Count (P.Kind) then
         return Rules.Get (P.Kind, I - 1);
      else
         return null;
      end if;
   end Item;

   procedure Chosen (P : in out Panel) is
      It : constant Rules.Item := Item (P);
   begin
      P.Help.Page := (if It /= null then It.Page else 0);
   end Chosen;

   procedure Changed (P : in out Panel) is null;

   procedure Choose (P : in out Panel'Class; It : Rules.Item) is
      use type Rules.Kind;
   begin
      if It /= null and then It.Of_Kind = P.Kind then
         for I in 0 .. Rules.Count (P.Kind) - 1 loop
            if Rules.Get (P.Kind, I) = It then
               P.Choice.Set_Chosen (Place => I + 1);
            end if;
         end loop;
      else
         P.Choice.Clear_Chosen;
      end if;
      P.Chosen;
   end Choose;

   procedure Refresh (P : in out Panel'Class; Line : Natural) is
   begin
      P.Browser.Clear;
      P.Fill;
      if Line > 0 and Line <= P.Browser.Number_Of_Lines then
         P.Browser.Set_Select (Line => Line);
         P.Load (Line);
      end if;
   end Refresh;

   --  The open panel W is one of the controls of; null if none.
   function Panel_Of (W : FLTK.Widgets.Widget'Class) return Panel_Access is
      A : constant System.Address := W'Address;
      P : Panel_Access := Panels;
   begin
      while P /= null
        and then A /= P.Browser.all'Address and then A /= P.Choice.all'Address
        and then A /= P.Add_Button.all'Address and then A /= P.Change_Button.all'Address
        and then A /= P.Remove_Button.all'Address
      loop
         P := P.Next;
      end loop;
      return P;
   end Panel_Of;

   procedure Browser_Action (W : in out FLTK.Widgets.Widget'Class) is
      P : constant Panel_Access := Panel_Of (W);
   begin
      if P /= null and then P.Browser.Selected_Index > 0 then
         P.Load (P.Browser.Selected_Index);
      end if;
   end Browser_Action;

   procedure Choice_Action (W : in out FLTK.Widgets.Widget'Class) is
      P : constant Panel_Access := Panel_Of (W);
   begin
      if P /= null then
         P.Chosen;
      end if;
   end Choice_Action;

   --  Add and Change leave their item's line selected; Remove, none.
   --  Change and Remove need a line selected.
   procedure Button_Action (W : in out FLTK.Widgets.Widget'Class) is
      P    : constant Panel_Access := Panel_Of (W);
      Line : Natural;
      Done : Boolean;
   begin
      if P = null then
         return;
      end if;
      Line := P.Browser.Selected_Index;
      if W'Address = P.Add_Button.all'Address then
         Line := P.Add;
         Done := Line > 0;
      elsif Line = 0 then
         Done := False;
      elsif W'Address = P.Change_Button.all'Address then
         Line := P.Change (Line);
         Done := Line > 0;
      else
         Done := P.Remove (Line);
         Line := 0;
      end if;
      if Done then
         P.Refresh (Line);
         P.Changed;
      end if;
   end Button_Action;

   procedure Open_Panel (P : not null Panel_Access; X, Y, W, H : Integer; Kind : Rules.Kind;
                         Title, Spin_Label, Text_Label : String) is
      Row     : constant := 25;
      Gap     : constant := 5;
      Label_W : constant := 50;
      YY      : Integer;

      function Button (X : Integer; Label : String) return Button_Access is
         B : constant Button_Access := new Buttons.Button'(Buttons.Forge.Create (X, YY, 70, Row, Label));
      begin
         B.Set_Callback (Button_Action'Access);
         return B;
      end Button;

   begin
      P.Kind := Kind;
      P.Browser := new Hold.Hold_Browser'(Hold.Forge.Create (X, Y + 20, W, H - 20, Title));
      P.Browser.Set_Alignment (FLTK.Align_Top_Left);
      P.Browser.Set_Format_Character (Character'Val (0));  --  names are text, never format codes
      P.Browser.Set_Column_Widths ([W - 70]);  --  then the page's
      P.Browser.Set_Callback (Browser_Action'Access);
      YY := Y + H + Gap;
      P.Choice := new Choices.Choice'(Choices.Forge.Create (X, YY, W - 30, Row));
      for I in 0 .. Rules.Count (Kind) - 1 loop
         P.Choice.Add (Rules.Label (Rules.Get (Kind, I)), null);
      end loop;
      P.Choice.Set_Callback (Choice_Action'Access);
      P.Help := Open_Help_Button (X + W - 25, YY, 0);
      YY := YY + Row + Gap;
      P.Spinner := new Spinners.Spinner'(Spinners.Forge.Create (X + Label_W, YY, 60, Row, Spin_Label));
      P.Text := new Texts.Text_Input'
        (Texts.Forge.Create (X + Label_W + 60 + Label_W, YY, W - 2 * Label_W - 60, Row, Text_Label));
      YY := YY + Row + Gap;
      P.Add_Button := Button (X, "Add");
      P.Change_Button := Button (X + 75, "Change");
      P.Remove_Button := Button (X + 150, "Remove");
      P.Bottom := YY + Row;
      P.Next := Panels;
      Panels := P;
   end Open_Panel;

   procedure Close_Panel (P : not null Panel_Access) is
      procedure Free_Browser is new Ada.Unchecked_Deallocation (Hold.Hold_Browser'Class, Browser_Access);
      procedure Free_Choice is new Ada.Unchecked_Deallocation (Choices.Choice'Class, Choice_Access);
      procedure Free_Spinner is new Ada.Unchecked_Deallocation (Spinners.Spinner'Class, Spinner_Access);
      procedure Free_Input is new Ada.Unchecked_Deallocation (Texts.Text_Input'Class, Input_Access);
      procedure Free_Button is new Ada.Unchecked_Deallocation (Buttons.Button'Class, Button_Access);
      Q : Panel_Access;
   begin
      if Panels = P then
         Panels := P.Next;
      else
         Q := Panels;
         while Q /= null and then Q.Next /= P loop
            Q := Q.Next;
         end loop;
         if Q /= null then
            Q.Next := P.Next;
         end if;
      end if;
      P.Next := null;
      Free_Browser (P.Browser);
      Free_Choice (P.Choice);
      Free (P.Help);
      Free_Spinner (P.Spinner);
      Free_Input (P.Text);
      Free_Button (P.Add_Button);
      Free_Button (P.Change_Button);
      Free_Button (P.Remove_Button);
   end Close_Panel;

   --  ---- Helpers ----

   function Spin_Value (S : Spinners.Spinner'Class) return Integer is
   begin
      return Integer (Long_Float'Floor (S.Get_Value));
   end Spin_Value;

end Ova_Cg.Widgets;
