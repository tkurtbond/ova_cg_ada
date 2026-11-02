with Ada.Unchecked_Deallocation;

package body Ova_Cg.Calc is

   use type Rules.Item;
   use all type Rules.Kind;
   use all type Rules.Flag;
   use all type Rules.Cost_Kind_Type;

   Combined_Limit : constant := 5;  --  Combined Effectiveness: at most +5 to a roll
   Character_Base : constant := 40;
   Companion_Base : constant := 20;
   Minion_Base    : constant := 10;
   Companion_TV   : constant := 4;  --  taken off a Secondary NPC's TV
   Boss_TV        : constant := 5;  --  added for each Boss Ability (p. 124)
   Max_Level      : constant := 5;
   Min_Weakness   : constant := -3;
   Cost_Step      : constant := 5;

   Redirectable : Rules.Item;

   --  ---- Numbers ----

   procedure Set_Computed (N : in out Number; Value : Integer; Half, Plus : Boolean) is
   begin
      N.Value := Value;
      N.Half := Half;
      N.Plus := Plus;
   end Set_Computed;

   procedure Set (N : in out Number; Value : Integer) is
   begin
      Set_Computed (N, Value, False, False);
   end Set;

   procedure Override (N : in out Number; Value : Integer; Half, Plus : Boolean) is
   begin
      N.Overridden := True;
      N.Ov_Value := (if Half then 0 else Value);
      N.Ov_Half := Half;
      N.Ov_Plus := Plus;
   end Override;

   procedure Clear (N : in out Number) is
   begin
      N.Overridden := False;
      N.Ov_Value := 0;
      N.Ov_Half := False;
      N.Ov_Plus := False;
   end Clear;

   function Overridden (N : Number) return Boolean is (N.Overridden);

   function Value (N : Number) return Integer is (if N.Overridden then N.Ov_Value else N.Value);

   function Half (N : Number) return Boolean is (if N.Overridden then N.Ov_Half else N.Half);

   function Plus (N : Number) return Boolean is (if N.Overridden then N.Ov_Plus else N.Plus);

   --  N in decimal.
   function Image (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      return (if N < 0 then S else S (S'First + 1 .. S'Last));
   end Image;

   function Format (Value : Integer; Half, Plus : Boolean) return String is
     ((if Half then "1/2" else Image (Value)) & (if Plus then "+" else ""));

   function Text (N : Number) return String is (Format (Value (N), Half (N), Plus (N)));

   function Computed_Text (N : Number) return String is (Format (N.Value, N.Half, N.Plus));

   function Parse (S : String; Allow_Half, Allow_Plus : Boolean; N : in out Number) return Boolean is
      function Blank (C : Character) return Boolean is (C = ' ' or C = ASCII.HT);
      I       : Positive := S'First;
      J       : Natural := S'Last;
      V       : Integer := 0;
      Count  : Natural := 0;
      Neg, Is_Plus : Boolean := False;
   begin
      while I <= S'Last and then Blank (S (I)) loop
         I := I + 1;
      end loop;
      while J >= I and then Blank (S (J)) loop
         J := J - 1;
      end loop;
      if J < I then
         Clear (N);
         return True;
      end if;
      if Allow_Half and then S (I .. J) = "1/2" then
         Override (N, 0, True, False);
         return True;
      end if;
      if Allow_Plus and then S (J) = '+' then
         Is_Plus := True;
         J := J - 1;
      end if;
      if I <= J and then S (I) = '-' then
         Neg := True;
         I := I + 1;
      end if;
      while I <= J and then S (I) in '0' .. '9' and then Count < 6 loop
         V := 10 * V + Character'Pos (S (I)) - Character'Pos ('0');
         I := I + 1;
         Count := Count + 1;
      end loop;
      if Count = 0 or else I <= J then
         return False;
      end if;
      Override (N, (if Neg then -V else V), False, Is_Plus);
      return True;
   end Parse;

   procedure Init_Number (N : out Number) is
   begin
      N := (others => <>);
   end Init_Number;

   --  ---- Warnings ----

   function Length (L : Warning_List) return Natural is (Natural (L.V.Length));

   function Element (L : Warning_List; I : Positive) return Warning is (L.V (I));

   procedure Warn (S : not null Sheet; Code : Warning_Code; T : Trait; A : Attack; M : Modifier; Sp : Spell) is
   begin
      S.Warnings.V.Append (Warning'(Code, T, A, M, Sp));
   end Warn;

   --  ---- Building a sheet ----

   procedure Init_Sheet (S : not null Sheet; Of_Kind : Sheet_Kind) is
   begin
      S.Of_Kind := Of_Kind;
      S.Traits := null;
      S.Attacks := null;
      S.Transformed := False;
      S.Options := (others => <>);
      Init_Number (S.Defense);
      Init_Number (S.Barrier);
      Init_Number (S.Incorporeal);
      Init_Number (S.Health);
      Init_Number (S.Endurance);
      Init_Number (S.Reserve);
      Init_Number (S.TV);
      S.Has_Barrier := False;
      S.Has_Incorporeal := False;
      S.Has_Reserve := False;
      Init_Number (S.Ability_Levels);
      Init_Number (S.Weakness_Levels);
      Init_Number (S.Total);
      Init_Number (S.Ability_Points);
      Init_Number (S.Points);
      S.Weakness_Points := 0;
      S.Warnings.V.Clear;
   end Init_Sheet;

   procedure Init_Trait (T : not null Trait; Item : Rules.Item; Of_Kind : Rules.Kind; Level : Integer) is
   begin
      T.Next := null;
      T.Item := Item;
      T.Of_Kind := Of_Kind;
      T.Level := Level;
      T.Half_TV := Item /= null and then Rules.Has (Item, Half_TV);
      T.Mods := null;
      T.Use_Level := 0;
      T.Form := null;
      T.Spells := null;
      T.Partner := null;
      T.Has_End := False;
      Init_Number (T.End_Cost);
      T.Points := 0;
   end Init_Trait;

   procedure Init_Mod (M : not null Modifier; Item : Rules.Item; Times, Cost : Integer) is
   begin
      M.Next := null;
      M.Item := Item;
      M.Times := Times;
      M.Cost := Cost;
   end Init_Mod;

   procedure Init_Spell (Sp : not null Spell; Item : Rules.Item; Level : Integer) is
   begin
      Sp.Next := null;
      Sp.Item := Item;
      Sp.Level := Level;
      Init_Number (Sp.End_Cost);
   end Init_Spell;

   procedure Init_Attack (A : not null Attack) is
   begin
      A.Next := null;
      A.Mods := null;
      A.Telekinetic := False;
      A.Transformed := False;
      A.Use_Level := 0;
      Init_Number (A.Roll);
      Init_Number (A.DX);
      Init_Number (A.End_Cost);
      A.In_TV := False;
      A.TV_Roll := 0;
      A.TV_DX := 0;
   end Init_Attack;

   procedure Add_Trait (List : in out Trait; T : not null Trait) is
      P : Trait := List;
   begin
      T.Next := null;
      if P = null then
         List := T;
      else
         while P.Next /= null loop
            P := P.Next;
         end loop;
         P.Next := T;
      end if;
   end Add_Trait;

   procedure Add_Mod (List : in out Modifier; M : not null Modifier) is
      P : Modifier := List;
   begin
      M.Next := null;
      if P = null then
         List := M;
      else
         while P.Next /= null loop
            P := P.Next;
         end loop;
         P.Next := M;
      end if;
   end Add_Mod;

   procedure Add_Spell (T : not null Trait; Sp : not null Spell) is
      P : Spell := T.Spells;
   begin
      Sp.Next := null;
      if P = null then
         T.Spells := Sp;
      else
         while P.Next /= null loop
            P := P.Next;
         end loop;
         P.Next := Sp;
      end if;
   end Add_Spell;

   procedure Add_Attack (S : not null Sheet; A : not null Attack) is
      P : Attack := S.Attacks;
   begin
      A.Next := null;
      if P = null then
         S.Attacks := A;
      else
         while P.Next /= null loop
            P := P.Next;
         end loop;
         P.Next := A;
      end if;
   end Add_Attack;

   --  ---- Freeing ----

   procedure Dispose is new Ada.Unchecked_Deallocation (Sheet_Record'Class, Sheet);
   procedure Dispose is new Ada.Unchecked_Deallocation (Trait_Record'Class, Trait);
   procedure Dispose is new Ada.Unchecked_Deallocation (Modifier_Record'Class, Modifier);
   procedure Dispose is new Ada.Unchecked_Deallocation (Spell_Record'Class, Spell);
   procedure Dispose is new Ada.Unchecked_Deallocation (Attack_Record'Class, Attack);

   procedure Free_Mods (List : in out Modifier) is
      Next : Modifier;
   begin
      while List /= null loop
         Next := List.Next;
         Dispose (List);
         List := Next;
      end loop;
   end Free_Mods;

   procedure Free_Spells (List : in out Spell) is
      Next : Spell;
   begin
      while List /= null loop
         Next := List.Next;
         Dispose (List);
         List := Next;
      end loop;
   end Free_Spells;

   procedure Free_Attacks (List : in out Attack) is
      Next : Attack;
   begin
      while List /= null loop
         Next := List.Next;
         Free_Mods (List.Mods);
         Dispose (List);
         List := Next;
      end loop;
   end Free_Attacks;

   procedure Free_Traits (List : in out Trait) is
      Next : Trait;
   begin
      while List /= null loop
         Next := List.Next;
         Free_Mods (List.Mods);
         Free_Traits (List.Form);
         Free_Spells (List.Spells);
         if List.Partner /= null then
            Free (List.Partner);
         end if;
         Dispose (List);
         List := Next;
      end loop;
   end Free_Traits;

   procedure Free (S : in out Sheet) is
   begin
      if S /= null then
         Free_Traits (S.Traits);
         Free_Attacks (S.Attacks);
         Dispose (S);
      end if;
   end Free;

   --  ---- Traits ----

   function Has (T : not null Trait; Which : Rules.Flag) return Boolean is
     (T.Item /= null and then Rules.Has (T.Item, Which));

   --  The signed levels of S's Traits that have Which, with their forms'
   --  when Form (a Transformation's form adds to the same Abilities).
   function Sum (S : not null Sheet; Which : Rules.Flag; Form : Boolean) return Integer is
      N : Integer := 0;
      T : Trait := S.Traits;
      F : Trait;
   begin
      while T /= null loop
         if Has (T, Which) then
            N := N + T.Level;
         end if;
         if Form then
            F := T.Form;
            while F /= null loop
               if Has (F, Which) then
                  N := N + F.Level;
               end if;
               F := F.Next;
            end loop;
         end if;
         T := T.Next;
      end loop;
      return N;
   end Sum;

   --  True if S has a Trait with Which (in its form too, when Form).
   function Present (S : not null Sheet; Which : Rules.Flag; Form : Boolean) return Boolean is
      T : Trait := S.Traits;
      F : Trait;
   begin
      while T /= null loop
         if Has (T, Which) then
            return True;
         end if;
         if Form then
            F := T.Form;
            while F /= null loop
               if Has (F, Which) then
                  return True;
               end if;
               F := F.Next;
            end loop;
         end if;
         T := T.Next;
      end loop;
      return False;
   end Present;

   --  A table's level, 0 to +5; one past it is counted as +5, with a
   --  warning (two Tough Abilities, or the form's added to the base's).
   function Table_Level (S : not null Sheet; Level : Integer) return Integer is
   begin
      if Level > Max_Level then
         Warn (S, Table_Range, null, null, null, null);
         return Max_Level;
      elsif Level < 0 then
         Warn (S, Table_Range, null, null, null, null);
         return 0;
      else
         return Level;
      end if;
   end Table_Level;

   --  ---- Perks and Flaws ----

   function Mod_Has (List : Modifier; Which : Rules.Flag) return Boolean is
      M : Modifier := List;
   begin
      while M /= null loop
         if M.Item /= null and then Rules.Has (M.Item, Which) then
            return True;
         end if;
         M := M.Next;
      end loop;
      return False;
   end Mod_Has;

   --  True if List has a Modifier of Of_Kind (Perk or Flaw) with Which.
   function Kind_Has (List : Modifier; Of_Kind : Rules.Kind; Which : Rules.Flag) return Boolean is
      M : Modifier := List;
   begin
      while M /= null loop
         if M.Item /= null and then M.Item.Of_Kind = Of_Kind and then Rules.Has (M.Item, Which) then
            return True;
         end if;
         M := M.Next;
      end loop;
      return False;
   end Kind_Has;

   function Mod_Has_Item (List : Modifier; It : Rules.Item) return Boolean is
      M : Modifier := List;
   begin
      while M /= null and then M.Item /= It loop
         M := M.Next;
      end loop;
      return M /= null;
   end Mod_Has_Item;

   --  The times the Perks with Which are taken, less the times the Flaws
   --  with it are: Accurate x2 and Inaccurate x3 make -1.
   function Net (List : Modifier; Which : Rules.Flag) return Integer is
      N : Integer := 0;
      M : Modifier := List;
   begin
      while M /= null loop
         if M.Item /= null and then Rules.Has (M.Item, Which) then
            N := (if M.Item.Of_Kind = Perk then N + M.Times else N - M.Times);
         end if;
         M := M.Next;
      end loop;
      return N;
   end Net;

   function Mod_Cost (M : not null Modifier) return Integer is
     (if M.Item /= null and then M.Item.Cost_Kind = Fixed_Cost then M.Item.Cost * M.Times
      else M.Cost * M.Times);

   --  What Endurance Use at Level adds (p. 70); none outside -1 to -3.
   function Use_Cost (Level : Integer) return Natural is
     (if Level in Min_Weakness .. -1 then Rules.Endurance_Use_Cost (Level) else 0);

   --  An attack's or Ability's Endurance cost (p. 83, 70): its Perks', its
   --  Endurance Use's, less its Flaws', never below 0.
   function End_Cost (List : Modifier; Use_Level : Integer) return Natural is
      N : Integer := Use_Cost (Use_Level);
      M : Modifier := List;
   begin
      while M /= null loop
         N := N + Mod_Cost (M);
         M := M.Next;
      end loop;
      return Integer'Max (N, 0);
   end End_Cost;

   --  The warnings of each Modifier: unknown, taken too often, a cost out
   --  of its range.  T or A is the owner.
   procedure Check_Mods (S : not null Sheet; List : Modifier; T : Trait; A : Attack) is
      M : Modifier := List;
   begin
      while M /= null loop
         if M.Item = null then
            Warn (S, Unknown_Item, T, A, M, null);
         else
            if M.Times < 1 or else M.Times > M.Item.Max_Times then
               Warn (S, Too_Often, T, A, M, null);
            end if;
            if M.Item.Cost_Kind = Range_Cost
              and then (M.Cost < M.Item.Min_Cost or else M.Cost > M.Item.Max_Cost
                        or else M.Cost mod Cost_Step /= 0)
            then
               Warn (S, Cost_Range, T, A, M, null);
            end if;
         end if;
         M := M.Next;
      end loop;
   end Check_Mods;

   --  ---- The combat box (p. 105-107) ----

   procedure Compute_Attack (S : not null Sheet; A : not null Attack) is
      Form : constant Boolean := S.Transformed or A.Transformed;
      Roll, DX, Net_Roll, Net_DX : Integer;
   begin
      --  ROLL: 2 + Agile - Clumsy, or Iron-Willed - Weak-Willed for a Will
      --  Attack, + Combat Expert, + Accurate - Inaccurate.
      if Mod_Has (A.Mods, Will_Attack) then
         Roll := 2 + Sum (S, Will, Form);
      else
         Roll := 2 + Sum (S, Agility, Form);
      end if;
      Roll := Roll + Sum (S, Combat_Skill, Form);
      if S.Options.Combined_Effectiveness and then Roll - 2 > Combined_Limit then
         Warn (S, Over_Five, null, A, null, null);
      end if;
      Net_Roll := Net (A.Mods, Roll_Each);
      Set (A.Roll, Roll + Net_Roll);
      --  DX: 1 + Attack + Strong - Weak (not if Ranged, unless
      --  Strength-Powered) + Telekinesis if made with it + Effective -
      --  Ineffective; 0 for No Damage, else 1/2 at 0 or less.
      DX := 1 + Sum (S, Damage, Form);
      if not Mod_Has (A.Mods, Ranged_Attack) or else Mod_Has (A.Mods, Strength_Ranged) then
         DX := DX + Sum (S, Strength, Form);
      end if;
      if A.Telekinetic then
         DX := DX + Sum (S, Telekinetic, Form);
      end if;
      Net_DX := Net (A.Mods, Damage_Each);
      if Mod_Has (A.Mods, No_Damage_Done) then
         Set (A.DX, 0);
      elsif DX + Net_DX <= 0 then
         Set_Computed (A.DX, 0, True, False);
      else
         Set (A.DX, DX + Net_DX);
      end if;
      Set (A.End_Cost, End_Cost (A.Mods, A.Use_Level));
      --  What TV takes: the numbers in effect, overrides included, less
      --  what the Perks and Flaws added each time.
      A.In_TV := not A.Transformed or S.Transformed;
      A.TV_Roll := Value (A.Roll) - Net_Roll;
      if not A.DX.Overridden then
         A.TV_DX := DX;
      elsif A.DX.Ov_Half then
         A.TV_DX := 0;
      else
         A.TV_DX := A.DX.Ov_Value - Net_DX;
      end if;
      A.TV_DX := Integer'Max (A.TV_DX, 0);
      Check_Mods (S, A.Mods, null, A);
      if Mod_Has (A.Mods, No_Damage_Done) and then Kind_Has (A.Mods, Flaw, Damage_Each) then
         Warn (S, No_Damage_Ineffective, null, A, null, null);
      end if;
      if Redirectable /= null and then Mod_Has_Item (A.Mods, Redirectable)
        and then not Mod_Has (A.Mods, Ranged_Attack) and then not Mod_Has (A.Mods, Strength_Ranged)
      then
         Warn (S, Redirectable_Alone, null, A, null, null);
      end if;
   end Compute_Attack;

   --  An Ability's or Weakness's own warnings and END, and its spells'
   --  costs (p. 58): by the Magic's level and the spell's, "+" for an
   --  Ability that spends Endurance of its own (Barrier).  A spell at -1
   --  to -3 casts a Weakness, as Witchcraft's do, at the same costs
   --  (p. 58): by its size, as Acacia's curses cost (p. 134).
   procedure Compute_Trait (S : not null Sheet; T : not null Trait) is
      Sp : Spell := T.Spells;
   begin
      if T.Item = null then
         Warn (S, Unknown_Item, T, null, null, null);
      end if;
      if (T.Of_Kind = Ability and then T.Level not in 1 .. Max_Level)
        or else (T.Of_Kind = Weakness and then T.Level not in Min_Weakness .. -1)
      then
         Warn (S, Level_Range, T, null, null, null);
      end if;
      if Has (T, Boss_Only) and then S.Of_Kind /= Boss_Sheet then
         Warn (S, Not_Boss, T, null, null, null);
      end if;
      T.Has_End := T.Mods /= null or else T.Use_Level /= 0;
      Set (T.End_Cost, (if T.Has_End then End_Cost (T.Mods, T.Use_Level) else 0));
      Check_Mods (S, T.Mods, T, null);
      while Sp /= null loop
         if T.Level in 1 .. Max_Level
           and then (Sp.Level in 1 .. Max_Level or else Sp.Level in Min_Weakness .. -1)
         then
            Set_Computed (Sp.End_Cost, Rules.Spell_Cost (T.Level, abs Sp.Level), False,
                          Sp.Item /= null and then Rules.Has (Sp.Item, Own_Cost));
         else
            Set (Sp.End_Cost, 0);
            Warn (S, Spell_Range, T, null, null, Sp);
         end if;
         Sp := Sp.Next;
      end loop;
   end Compute_Trait;

   --  An alternate Defense Roll, 2 + the levels of what has Which (p. 51,
   --  55), into N; Has, whether the character has one.
   procedure Compute_Alternate (S : not null Sheet; Which : Rules.Flag; N : in out Number; Has : out Boolean) is
      Form : constant Boolean := S.Transformed;
      D    : Integer;
   begin
      Has := Present (S, Which, Form);
      if Has then
         D := 2 + Sum (S, Which, Form);
         Set (N, D);
         if S.Options.Combined_Effectiveness and then D - 2 > Combined_Limit then
            Warn (S, Over_Five, null, null, null, null);
         end if;
      else
         Set (N, 0);
      end if;
   end Compute_Alternate;

   --  Defense (p. 105), and Barrier's (p. 51) and Incorporeal Form's
   --  (p. 55).
   procedure Compute_Defense (S : not null Sheet) is
      D : constant Integer := 2 + Sum (S, Defense_Roll, S.Transformed);
   begin
      Set (S.Defense, D);
      if S.Options.Combined_Effectiveness and then D - 2 > Combined_Limit then
         Warn (S, Over_Five, null, null, null, null);
      end if;
      Compute_Alternate (S, Second_Defense, S.Barrier, S.Has_Barrier);
      Compute_Alternate (S, Third_Defense, S.Incorporeal, S.Has_Incorporeal);
   end Compute_Defense;

   --  Health and Endurance (p. 107): from the sheet's base, + the Tough
   --  and Vigorous table (p. 63, 65), - 10 a level of Frail and Languid
   --  (p. 71, 73); and Endurance Reserve's separate store (p. 53).
   procedure Compute_Health (S : not null Sheet) is
      Form : constant Boolean := S.Transformed;
      Base : constant Integer :=
        (case S.Of_Kind is
            when Character_Sheet | Boss_Sheet => Character_Base,
            when Companion_Sheet => Companion_Base,
            when Minion_Sheet | Extra_Sheet => Minion_Base);
   begin
      Set (S.Health, Base + Rules.Tough_Bonus (Table_Level (S, Sum (S, Health_Table, Form)))
                   + 10 * Sum (S, Health_Tens, Form));
      Set (S.Endurance, Base + Rules.Tough_Bonus (Table_Level (S, Sum (S, Endurance_Table, Form)))
                      + 10 * Sum (S, Endurance_Tens, Form));
      S.Has_Reserve := Present (S, Reserve, Form);
      if S.Has_Reserve then
         Set (S.Reserve, Rules.Reserve_Bonus (Table_Level (S, Sum (S, Reserve, Form))));
      else
         Set (S.Reserve, 0);
      end if;
   end Compute_Health;

   --  Half of a marked Ability's level, rounded up (p. 124).
   function Half_TV_Level (T : not null Trait) return Natural is
     (if T.Half_TV and then T.Of_Kind = Ability and then T.Level > 0 and then not Has (T, No_TV)
      then (T.Level + 1) / 2 else 0);

   --  TV (p. 124): the best ROLL, Defense and DX, without the Perks and
   --  Flaws that add to them each time (Attack_Record.TV_Roll, TV_DX), +
   --  Armored + the signed levels that change Health and Endurance + half
   --  of each marked Ability's + 5 for each Boss Ability; a Companion's 4
   --  less, at least 1.  With no attack, the plain one: 2 + Agile + Combat
   --  Expert - Clumsy, 1 + Attack + Strong - Weak.
   procedure Compute_TV (S : not null Sheet) is
      Form : constant Boolean := S.Transformed;
      Any  : Boolean := False;
      A    : Attack := S.Attacks;
      T, F : Trait;
      Roll, DX, Def, TV : Integer := 0;
   begin
      while A /= null loop
         if A.In_TV then
            if not Any or else A.TV_Roll > Roll then
               Roll := A.TV_Roll;
            end if;
            if not Any or else A.TV_DX > DX then
               DX := A.TV_DX;
            end if;
            Any := True;
         end if;
         A := A.Next;
      end loop;
      if not Any then
         Roll := 2 + Sum (S, Agility, Form) + Sum (S, Combat_Skill, Form);
         DX := Integer'Max (1 + Sum (S, Damage, Form) + Sum (S, Strength, Form), 0);
      end if;
      Def := Value (S.Defense);
      if S.Has_Barrier and then Value (S.Barrier) > Def then
         Def := Value (S.Barrier);
      end if;
      if S.Has_Incorporeal and then Value (S.Incorporeal) > Def then
         Def := Value (S.Incorporeal);
      end if;
      TV := Roll + Def + DX + Sum (S, Armor, Form)
        + Sum (S, Health_Table, Form) + Sum (S, Health_Tens, Form)
        + Sum (S, Endurance_Table, Form) + Sum (S, Endurance_Tens, Form);
      T := S.Traits;
      while T /= null loop
         TV := TV + Half_TV_Level (T);
         if Has (T, Boss_Only) then
            TV := TV + Boss_TV;
         end if;
         if Form then
            F := T.Form;
            while F /= null loop
               TV := TV + Half_TV_Level (F);
               F := F.Next;
            end loop;
         end if;
         T := T.Next;
      end loop;
      case S.Of_Kind is
         when Companion_Sheet => TV := Integer'Max (TV - Companion_TV, 1);
         when Extra_Sheet => TV := 1;
         when others => null;
      end case;
      Set (S.TV, TV);
   end Compute_TV;

   --  ---- The totals and the limits (p. 21) ----

   --  Scaled Cost's points for a level's size (p. 21): 1, 2, 4, 8, 15.
   function Scaled (Size : Natural) return Natural is
     (if Size = 0 then 0 elsif Size >= Max_Level then 15 else 2 ** (Size - 1));

   --  N halved, rounded away from 0: Knowledge 3 counts 2, Ineptitude -3
   --  counts -2 (p. 57, "round up").
   function Half_Up (N : Integer) return Integer is
     (if N >= 0 then (N + 1) / 2 else -((1 - N) / 2));

   --  The totals of the character's own Traits (not a form's, which
   --  Transformation's level pays for, p. 63; not a Boss Ability, which is
   --  applied and removed as needed, p. 123), then the limits on them.
   procedure Compute_Totals (S : not null Sheet) is
      O    : Options_Record renames S.Options;
      Half : constant Boolean :=
        O.Half_Cost_Knowledge and (O.Base_Zero or O.Power_Ceiling or O.Scaled_Cost);
      T : Trait := S.Traits;
      Lv, Pts, Abilities, Ability_Points, Weaknesses, Spent, Measure : Integer := 0;
   begin
      S.Weakness_Points := 0;
      while T /= null loop
         Lv := (if Has (T, Boss_Only) then 0 else T.Level);
         Pts := Scaled (abs Lv);
         if Half and then Has (T, Half_Cost) then
            Lv := Half_Up (Lv);
            Pts := Half_Up (Pts);
         end if;
         T.Points := Pts;
         if T.Of_Kind = Ability then
            Abilities := Abilities + Lv;
            Ability_Points := Ability_Points + Pts;
         else
            Weaknesses := Weaknesses + Lv;
            S.Weakness_Points := S.Weakness_Points + Pts;
         end if;
         T := T.Next;
      end loop;
      Set (S.Ability_Levels, Abilities);
      Set (S.Weakness_Levels, Weaknesses);
      Set (S.Total, Value (S.Ability_Levels) + Value (S.Weakness_Levels));
      Set (S.Ability_Points, Ability_Points);
      Set (S.Points, Value (S.Ability_Points) - S.Weakness_Points);
      if O.Scaled_Cost then
         Measure := Value (S.Points);
         Spent := Value (S.Ability_Points);
      else
         Measure := Value (S.Total);
         Spent := Value (S.Ability_Levels);
      end if;
      if O.Base_Zero and then abs Measure > O.Base_Zero_Range then
         Warn (S, Base_Zero_Broken, null, null, null, null);
      end if;
      if O.Power_Ceiling and then Spent > O.Ceiling then
         Warn (S, Ceiling_Broken, null, null, null, null);
      end if;
      if O.Starting_Levels then
         Measure := (if O.Scaled_Cost then S.Weakness_Points else -Value (S.Weakness_Levels));
         if Spent > O.Starting + Measure then
            Warn (S, Starting_Broken, null, null, null, null);
         end if;
      end if;
   end Compute_Totals;

   procedure Compute (S : not null Sheet) is
      T : Trait := S.Traits;
      F : Trait;
      A : Attack := S.Attacks;
   begin
      S.Warnings.V.Clear;
      while T /= null loop
         Compute_Trait (S, T);
         F := T.Form;
         while F /= null loop
            Compute_Trait (S, F);
            F := F.Next;
         end loop;
         if T.Partner /= null then
            Compute (T.Partner);
         end if;
         T := T.Next;
      end loop;
      Compute_Totals (S);
      while A /= null loop
         Compute_Attack (S, A);
         A := A.Next;
      end loop;
      Compute_Defense (S);
      Compute_Health (S);
      Compute_TV (S);
   end Compute;

begin
   Redirectable := Rules.Find ("Redirectable");
end Ova_Cg.Calc;
