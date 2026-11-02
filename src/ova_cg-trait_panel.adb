with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

package body Ova_Cg.Trait_Panel is


   use type Calc.Trait;
   use type Calc.Sheet;
   use type Calc.Sheet_Kind;
   use type Rules.Item;
   use type Rules.Kind;

   --  Under Scaled Cost, the browser's columns: the points', and at
   --  least this much for the page's.
   Points_W : constant := 45;
   Page_W   : constant := 60;

   Tab : constant Standard.Character := ASCII.HT;

   --  I as OvaText.Int writes it: no blank.
   function Image (I : Integer) return String is
     (Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Left));

   procedure Set_Handlers (P : in out Trait_Panel'Class; Selected : Selected_Handler;
                           Changed : Changed_Handler) is
   begin
      P.Selected := Selected;
      P.Changed := Changed;
   end Set_Handlers;

   function Sheet (P : Trait_Panel'Class) return Calc.Sheet is (P.Sheet);
   function Owner (P : Trait_Panel'Class) return Calc.Trait is (P.Owner);
   function Top (P : Trait_Panel'Class) return Character.Character_Access is (P.Top);
   function Name_W (P : Trait_Panel'Class) return Integer is (P.Name_W);

   function List (P : Trait_Panel'Class) return Calc.Trait is
     (if P.Owner /= null then P.Owner.Form else P.Sheet.Traits);

   procedure Set_List (P : in out Trait_Panel'Class; L : Calc.Trait) is
   begin
      if P.Owner /= null then
         P.Owner.Form := L;
      else
         P.Sheet.Traits := L;
      end if;
   end Set_List;

   function Trait_At (P : Trait_Panel'Class; Line : Natural) return Character.Trait is
   begin
      if Line in 1 .. Natural (P.Shown.Length) then
         return P.Shown (Line);
      else
         return null;
      end if;
   end Trait_At;

   function Selected (P : Trait_Panel'Class) return Character.Trait is
     (Trait_At (P, P.Browser.Selected_Index));

   function Shows_Points (P : Trait_Panel'Class) return Boolean is
     (P.Sheet /= null and then P.Owner = null and then P.Sheet.Options.Scaled_Cost);

   procedure Fit (P : in out Trait_Panel'Class) is
      W : constant Integer := P.Browser.Get_W;
   begin
      if Shows_Points (P) then
         P.Name_W := W - Points_W - Page_W;
         P.Browser.Set_Column_Widths ([P.Name_W, Points_W]);
      else
         P.Name_W := W - 70;  --  as Widgets.Open_Panel
         P.Browser.Set_Column_Widths ([P.Name_W]);
      end if;
      P.Browser.Redraw;
   end Fit;

   overriding procedure Chosen (P : in out Trait_Panel) is
      It : Rules.Item;
   begin
      Widgets.Chosen (Widgets.Panel (P));
      It := P.Item;
      if It /= null and then Rules.Has (It, Rules.Boss_Only) then
         P.Spinner.Set_Value (1.0);
         P.Spinner.Deactivate;
      else
         P.Spinner.Activate;
      end if;
   end Chosen;

   --  Whether the list is a Boss's own Abilities.
   function Offers_Boss (P : Trait_Panel'Class) return Boolean is
     (P.Kind = Rules.Ability and then P.Sheet /= null and then P.Owner = null
      and then P.Sheet.Of_Kind = Calc.Boss_Sheet);

   overriding procedure Fill (P : in out Trait_Panel) is
      T      : Calc.Trait;
      X      : Character.Trait;
      Line   : Unbounded_String;
      Points : Boolean;
   begin
      P.Shown.Clear;
      if P.Sheet = null then
         return;
      end if;
      P.Offer_Boss (Offers_Boss (P));
      Points := Shows_Points (P);
      Fit (P);
      T := List (P);
      while T /= null loop
         if T.Of_Kind = P.Kind then
            X := Character.Trait (T);
            P.Shown.Append (X);
            Line := To_Unbounded_String (if X.Level > 0 then "+" else "");
            Append (Line, Image (X.Level) & " " & X.Name);
            if X.Has_Detail then
               Append (Line, " (" & X.Detail & ")");
            end if;
            Append (Line, Tab);
            if Points then
               Append (Line, Image (X.Points) & (if X.Points = 1 then " pt" else " pts") & Tab);
            end if;
            Append (Line, Rules.Page_Text (X.Item));
            P.Browser.Add (To_String (Line));
         end if;
         T := T.Next;
      end loop;
   end Fill;

   --  The line T is on.
   function Line_Of (P : Trait_Panel'Class; T : Calc.Trait) return Positive is
      I : Natural := 0;
      L : Calc.Trait := List (P);
   begin
      while L /= null and then L /= T loop
         if L.Of_Kind = P.Kind then
            I := I + 1;
         end if;
         L := L.Next;
      end loop;
      return I + 1;
   end Line_Of;

   procedure Select_Trait (P : in out Trait_Panel'Class; T : Character.Trait) is
   begin
      if P.Selected /= null then
         P.Selected (P, T);
      end if;
   end Select_Trait;

   overriding procedure Load (P : in out Trait_Panel; Line : Positive) is
      T : constant Character.Trait := P.Shown (Line);
   begin
      P.Choose (T.Item);
      P.Spinner.Set_Value (Long_Float (T.Level));
      P.Text.Set_Value (To_String (T.Detail));
      Select_Trait (P, T);
   end Load;

   --  The detail typed; "" for none.
   function Detail (P : Trait_Panel'Class) return Unbounded_String is
     (To_Unbounded_String (Character.Trim (P.Text.Get_Value)));

   overriding function Add (P : in out Trait_Panel) return Natural is
      It : constant Rules.Item := P.Item;
      T  : Character.Trait;
      L  : Calc.Trait;
   begin
      if It = null then
         Tell ("Choose a name first.");
         return 0;
      end if;
      T := Character.New_Trait (It, P.Kind, Widgets.Spin_Value (P.Spinner.all), Null_Unbounded_String,
                                Detail (P));
      L := List (P);
      Character.Insert_Trait (L, T);
      Set_List (P, L);
      Character.Recompute (P.Top);
      return Line_Of (P, Calc.Trait (T));
   end Add;

   overriding function Change (P : in out Trait_Panel; Line : Positive) return Natural is
      T  : constant Character.Trait := P.Shown (Line);
      It : Rules.Item := P.Item;
      L  : Calc.Trait;
   begin
      if It = null then
         It := T.Item;
      end if;
      L := List (P);
      Character.Change_Trait (L, T, It, Widgets.Spin_Value (P.Spinner.all), Detail (P));
      Set_List (P, L);
      Character.Recompute (P.Top);
      return Line_Of (P, Calc.Trait (T));
   end Change;

   overriding function Remove (P : in out Trait_Panel; Line : Positive) return Boolean is
      T : Calc.Trait := Calc.Trait (P.Shown (Line));
      L : Calc.Trait := List (P);
   begin
      Character.Remove_Trait (L, T);
      Set_List (P, L);
      Select_Trait (P, null);
      Character.Recompute (P.Top);
      P.Shown.Clear;  --  until Fill: none holds T
      Calc.Free_Traits (T);
      return True;
   end Remove;

   overriding procedure Changed (P : in out Trait_Panel) is
   begin
      if P.Changed /= null then
         P.Changed (P);
      end if;
   end Changed;

   procedure Show (P : in out Trait_Panel'Class; Sheet : Calc.Sheet; Owner : Calc.Trait;
                   Top : Character.Character_Access) is
   begin
      P.Sheet := Sheet;
      P.Owner := Owner;
      P.Top := Top;
      P.Refresh (0);
      Select_Trait (P, null);
   end Show;

   function Open (X, Y, W, H : Integer; Kind : Rules.Kind; Title : String)
     return not null Trait_Panel_Access is
      P : constant Trait_Panel_Access := new Trait_Panel;
   begin
      Widgets.Open_Panel (Widgets.Panel_Access (P), X, Y, W, H, Kind, Title, "level", "detail");
      P.Name_W := P.Browser.Get_W - 70;  --  as Open_Panel sets it
      if Kind = Rules.Ability then
         P.Spinner.Set_Range (1.0, 5.0);
         P.Spinner.Set_Value (1.0);
      else
         P.Spinner.Set_Range (-3.0, -1.0);
         P.Spinner.Set_Value (-1.0);
      end if;
      return P;
   end Open;

   procedure Free (P : in out Trait_Panel_Access) is
      procedure Free_Panel is new Ada.Unchecked_Deallocation (Trait_Panel'Class, Trait_Panel_Access);
   begin
      if P /= null then
         Widgets.Close_Panel (Widgets.Panel_Access (P));
         Free_Panel (P);
      end if;
   end Free;

end Ova_Cg.Trait_Panel;
