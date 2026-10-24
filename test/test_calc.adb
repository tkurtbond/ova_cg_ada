--  Ova_Cg.Calc: the sample characters, and a case for each rule.
--
--  The oracle is the book's sample characters (ova_cg_po's PLAN.md,
--  "Testing"): each of the twelve in test/data/ is built into a sheet
--  (Ova_Cg.Character.Build) and every number its file holds is compared
--  with Ova_Cg.Calc's: each attack's ROLL, DX and END, Defense (and
--  Barrier's), Health, Endurance, TV, each Ability's END and each
--  spell's, and the same for a Companion with combat stats.  The two
--  rulings the rules don't reproduce (ova_cg_po's PLAN.md, "Sample
--  characters the rules don't reproduce") are checked as overrides: the
--  computed number first, then the book's as an override, and what
--  follows from it.
--
--  Then a hand-made case for each Perk and Flaw that changes ROLL or DX,
--  the floor at 0, 1/2 DX, Endurance Use, spells, Defense, Health and
--  Endurance, TV, each limit and warning, and overrides counting
--  downstream.  Needs no display.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Check;
with Ova_Cg.Calc; use Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Rules;
with Ova_Fmt.Entities;

procedure Test_Calc is

   package E renames Ova_Fmt.Entities;

   use type Ova_Cg.Rules.Item;
   use type E.Sub_Entity_Access;

   Data_Dir : constant String := "data/";

   Label  : Unbounded_String;
   Sample : Unbounded_String;  --  the sample being checked, for labels

   --  ---- Labels ----

   function Image (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      return (if N < 0 then S else S (S'First + 1 .. S'Last));
   end Image;

   --  Label := Sample ": " What
   procedure L (What : String) is
   begin
      Label := Sample & ": " & What;
   end L;

   procedure Ok (Cond : Boolean) is
   begin
      Check.Check (Cond, To_String (Label));
   end Ok;

   --  Checks N's text in effect against Want, the label saying both.
   procedure Check_Text (N : Number; Want : String) is
      Got : constant String := Text (N);
   begin
      Append (Label, " " & Want);
      if Got /= Want then
         Append (Label, " (got " & Got & ")");
      end if;
      Ok (Got = Want);
   end Check_Text;

   procedure Check_Int (N : Number; Want : Integer) is
   begin
      Check_Text (N, Image (Want));
   end Check_Int;

   procedure Check_Text (N : Number; Want : Unbounded_String) is
   begin
      Check_Text (N, To_String (Want));
   end Check_Text;

   --  Checks a plain integer, Got, against Want.
   procedure Is_Int (Got, Want : Integer) is
   begin
      Append (Label, " " & Image (Want));
      if Got /= Want then
         Append (Label, " (got " & Image (Got) & ")");
      end if;
      Ok (Got = Want);
   end Is_Int;

   --  ---- Warnings ----

   function Warnings (S : Sheet) return Natural is (Length (S.Warnings));

   --  True if S has a warning of Code about attack A (null: about none).
   function Warned (S : Sheet; Code : Warning_Code; A : Attack) return Boolean is
   begin
      for I in 1 .. Length (S.Warnings) loop
         if Element (S.Warnings, I).Code = Code and then Element (S.Warnings, I).Of_Attack = A then
            return True;
         end if;
      end loop;
      return False;
   end Warned;

   function Warned_Any (S : Sheet; Code : Warning_Code) return Boolean is
   begin
      for I in 1 .. Length (S.Warnings) loop
         if Element (S.Warnings, I).Code = Code then
            return True;
         end if;
      end loop;
      return False;
   end Warned_Any;

   --  ---- The sample characters ----

   --  Label := Sample ": " Name " " What
   procedure LR (Name : Unbounded_String; What : String) is
   begin
      Label := Sample & ": " & Name & " " & What;
   end LR;

   --  The I'th attack of S, from 0.
   function Nth_Attack (S : Sheet; I : Natural) return Attack is
      A : Attack := S.Attacks;
   begin
      for J in 1 .. I loop
         exit when A = null;
         A := A.Next;
      end loop;
      return A;
   end Nth_Attack;

   --  The index, from 0, of C's attack named Name; -1 if none.
   function Attack_Index (C : E.Combat_Stats; Name : String) return Integer is
   begin
      for I in C.Attacks.First_Index .. C.Attacks.Last_Index loop
         if C.Attacks (I).Name = Name then
            return I - C.Attacks.First_Index;
         end if;
      end loop;
      return -1;
   end Attack_Index;

   --  The numbers of a combat: block against S's.
   procedure Check_Combat (C : E.Combat_Stats; S : Sheet) is
      A   : Attack := S.Attacks;
      Def : Unbounded_String := To_Unbounded_String (Text (S.Defense));
   begin
      for X of C.Attacks loop
         LR (X.Name, "ROLL"); Check_Int (A.Roll, X.Roll);
         LR (X.Name, "DX"); Check_Text (A.DX, X.Dx);
         LR (X.Name, "END"); Check_Int (A.End_Cost, X.Endurance);
         A := A.Next;
      end loop;
      if S.Has_Barrier then
         Append (Def, "/" & Text (S.Barrier));
      end if;
      if S.Has_Incorporeal then
         Append (Def, "/" & Text (S.Incorporeal));
      end if;
      L ("DEFENSE " & To_String (C.Defense));
      if C.Defense /= Def then
         Append (Label, " (got " & Def & ")");
      end if;
      Ok (C.Defense = Def);
      L ("HEALTH"); Check_Int (S.Health, C.Health);
      L ("ENDURANCE"); Check_Int (S.Endurance, C.Endurance);
      if C.Has_Threat_Value then
         L ("TV"); Check_Int (S.TV, C.Threat_Value);
      end if;
   end Check_Combat;

   --  An Ability's END, where the file gives one.
   procedure Check_Sub_Items (Items : E.Sub_Item_Vectors.Vector; First : Trait) is
      T : Trait := First;
   begin
      for X of Items loop
         if X.Has_Endurance then
            LR (X.Name, "has an END"); Ok (T.Has_End);
            LR (X.Name, "END"); Check_Int (T.End_Cost, X.Endurance);
         end if;
         T := T.Next;
      end loop;
   end Check_Sub_Items;

   --  Every number En's file holds against S's.
   procedure Check_Entity (En : E.Entity; S : Sheet) is
      T  : Trait := S.Traits;
      Sp : Spell;
   begin
      for A of En.Abilities loop
         if A.Has_Endurance then
            LR (A.Name, "END"); Check_Int (T.End_Cost, A.Endurance);
         end if;
         Check_Sub_Items (A.Sub_Abilities, T.Form);
         Sp := T.Spells;
         for X of A.Spells loop
            LR (X.Name, "spell END"); Check_Text (Sp.End_Cost, X.Endurance);
            Sp := Sp.Next;
         end loop;
         if A.Sub_Entity /= null and then A.Sub_Entity.Combat.Has_Combat then
            declare
               Keep : constant Unbounded_String := Sample;
            begin
               Sample := A.Sub_Entity.Name;
               Check_Combat (A.Sub_Entity.Combat, T.Partner);
               L ("no warnings"); Ok (Warnings (T.Partner) = 0);
               Sample := Keep;
            end;
         end if;
         T := T.Next;
      end loop;
      Check_Combat (En.Combat, S);
      L ("no warnings"); Ok (Warnings (S) = 0);
   end Check_Entity;

   procedure Check_Sample (Name : String) is
      En  : E.Entity;
      N   : Natural;
      Msg : Unbounded_String;
      S   : Sheet;
      A   : Attack;
      I   : Integer;
      Ok_All : Boolean;
   begin
      Sample := To_Unbounded_String (Name);
      L ("loaded");
      if not Ova_Cg.Character.Read_Entity (Data_Dir & Name & ".yaml", En, N, Msg) then
         Append (Label, " (" & Msg & ")");
         Ok (False);
         return;
      end if;
      Ok (N = 1);
      S := Sheet (Ova_Cg.Character.Build (En));
      --  The Phase 3a keys the samples carry, as Build reads them; and
      --  the book's two rulings, which Build leaves to Load's overrides.
      if Name = "Ai" then
         A := S.Attacks;
         Ok_All := A /= null;
         while A /= null loop
            Ok_All := Ok_All and then A.Telekinetic and then not A.Transformed;
            A := A.Next;
         end loop;
         L ("both attacks made with Telekinesis"); Ok (Ok_All);
      elsif Name = "Fukiko" then
         L ("the sheet shown transformed"); Ok (S.Transformed);
      elsif Name = "Miho" then
         I := Attack_Index (En.Combat, "Mode SP: Miho Ray");
         L ("has Mode SP"); Ok (I >= 0);
         if I >= 0 then
            A := Nth_Attack (S, I);
            L ("Mode SP made transformed"); Ok (A.Transformed);
         end if;
         L ("the sheet not transformed"); Ok (not S.Transformed);
      elsif Name = "Braun" then
         --  The rule: 2 - Clumsy 2 = 0, TV 0 + 2 + 0 = 2; the book's -2
         --  as an override makes TV 0.
         Compute (S);
         L ("First Day of Sale Shove! computed ROLL"); Check_Int (S.Attacks.Roll, 0);
         L ("computed TV"); Check_Int (S.TV, 2);
         Override (S.Attacks.Roll, -2, False, False);
      elsif Name = "Natsuki" then
         I := Attack_Index (En.Combat, "Stiletto Kick");
         L ("has Stiletto Kick"); Ok (I >= 0);
         if I >= 0 then
            A := Nth_Attack (S, I);
            Compute (S);
            L ("Stiletto Kick computed DX"); Check_Int (A.DX, 6);
            Override (A.DX, 3, False, False);
         end if;
      end if;
      Compute (S);
      Check_Entity (En, S);
      Free (S);
      Ova_Cg.Character.Free_Entity (En);
   end Check_Sample;

   procedure Samples12 is
   begin
      Check_Sample ("Ai"); Check_Sample ("Auren"); Check_Sample ("Braun"); Check_Sample ("Cora");
      Check_Sample ("Daisuke"); Check_Sample ("Fukiko"); Check_Sample ("Karis"); Check_Sample ("Miho");
      Check_Sample ("Natsuki"); Check_Sample ("Raine"); Check_Sample ("Shou"); Check_Sample ("Yuu");
   end Samples12;

   --  ---- Hand-made sheets ----

   function New_Sheet (Of_Kind : Sheet_Kind) return Sheet is
      S : constant Sheet := new Sheet_Record;
   begin
      Init_Sheet (S, Of_Kind);
      return S;
   end New_Sheet;

   --  S, freed, then a new sheet of Of_Kind.
   procedure Renew (S : in out Sheet; Of_Kind : Sheet_Kind) is
   begin
      Free (S);
      S := New_Sheet (Of_Kind);
   end Renew;

   function Item (Name : String) return Ova_Cg.Rules.Item is
      It : constant Ova_Cg.Rules.Item := Ova_Cg.Rules.Find (Name);
   begin
      pragma Assert (It /= null, Name);
      return It;
   end Item;

   --  Name at Level, added to List (a sheet's traits or a form).
   function T (List : in out Trait; Name : String; Level : Integer) return Trait is
      It : constant Ova_Cg.Rules.Item := Item (Name);
      Tr : constant Trait := new Trait_Record;
   begin
      Init_Trait (Tr, It, It.Of_Kind, Level);
      Add_Trait (List, Tr);
      return Tr;
   end T;

   procedure Add (List : in out Trait; Name : String; Level : Integer) is
      Tr : constant Trait := T (List, Name, Level) with Unreferenced;
   begin
      null;
   end Add;

   --  Name taken Times, at Cost each time where the user sets it.
   procedure M (Mods : in out Modifier; Name : String; Times, Cost : Integer) is
      Md : constant Modifier := new Modifier_Record;
   begin
      Init_Mod (Md, Item (Name), Times, Cost);
      Add_Mod (Mods, Md);
   end M;

   function New_Attack (S : Sheet) return Attack is
      A : constant Attack := new Attack_Record;
   begin
      Init_Attack (A);
      Add_Attack (S, A);
      return A;
   end New_Attack;

   --  No Abilities: the plain attack, the starting numbers.
   procedure Plain is
      S : Sheet;
      A : Attack;
   begin
      Sample := To_Unbounded_String ("plain");
      S := New_Sheet (Character_Sheet);
      Compute (S);
      L ("no attack: TV 2 + 2 + 1"); Check_Int (S.TV, 5);
      A := New_Attack (S);
      Compute (S);
      L ("ROLL"); Check_Int (A.Roll, 2);
      L ("DX"); Check_Int (A.DX, 1);
      L ("END"); Check_Int (A.End_Cost, 0);
      L ("DEFENSE"); Check_Int (S.Defense, 2);
      L ("no Barrier"); Ok (not S.Has_Barrier);
      L ("HEALTH"); Check_Int (S.Health, 40);
      L ("ENDURANCE"); Check_Int (S.Endurance, 40);
      L ("no Reserve"); Ok (not S.Has_Reserve);
      L ("TV"); Check_Int (S.TV, 5);
      Free (S);
   end Plain;

   --  ROLL: Agile, Clumsy, Combat Expert; Accurate and Inaccurate each
   --  time; a Will Attack's Iron-Willed and Weak-Willed.  Attack and
   --  Strong don't add.
   procedure Rolls is
      S : Sheet;
      Plain, Acc, Inacc, Both, Will : Attack;
   begin
      Sample := To_Unbounded_String ("rolls");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Agile", 3); Add (S.Traits, "Combat Expert", 2); Add (S.Traits, "Clumsy", -1);
      Add (S.Traits, "Iron-Willed", 1); Add (S.Traits, "Attack", 4); Add (S.Traits, "Strong", 2);
      Plain := New_Attack (S);
      Acc := New_Attack (S); M (Acc.Mods, "Accurate", 2, 0);
      Inacc := New_Attack (S); M (Inacc.Mods, "Inaccurate", 3, 0);
      Both := New_Attack (S); M (Both.Mods, "Accurate", 2, 0); M (Both.Mods, "Inaccurate", 3, 0);
      Will := New_Attack (S); M (Will.Mods, "Will Attack", 1, 0);
      Compute (S);
      L ("2 + Agile 3 + Combat Expert 2 - Clumsy 1"); Check_Int (Plain.Roll, 6);
      L ("Accurate x2"); Check_Int (Acc.Roll, 8);
      L ("Accurate x2 END"); Check_Int (Acc.End_Cost, 10);
      L ("Inaccurate x3"); Check_Int (Inacc.Roll, 3);
      L ("Inaccurate x3 END, floored"); Check_Int (Inacc.End_Cost, 0);
      L ("Accurate x2, Inaccurate x3"); Check_Int (Both.Roll, 5);
      L ("Accurate x2, Inaccurate x3 END, floored"); Check_Int (Both.End_Cost, 0);
      L ("Will Attack: 2 + Iron-Willed 1 + Combat Expert 2"); Check_Int (Will.Roll, 5);
      L ("Will Attack END"); Check_Int (Will.End_Cost, 0);
      L ("TV's roll leaves out Accurate"); Is_Int (Acc.TV_Roll, 6);
      L ("TV's roll leaves out Inaccurate"); Is_Int (Inacc.TV_Roll, 6);
      Renew (S, Character_Sheet);
      Add (S.Traits, "Agile", 2); Add (S.Traits, "Weak-Willed", -2);
      Will := New_Attack (S); M (Will.Mods, "Will Attack", 1, 0);
      Compute (S);
      L ("Will Attack: 2 - Weak-Willed 2, Agile not counted"); Check_Int (Will.Roll, 0);
      Free (S);
   end Rolls;

   --  DX: Attack, Strong, Weak; Ranged and Ranged, Strength-Powered;
   --  Telekinesis; Effective and Ineffective; No Damage; 1/2.
   procedure Damage is
      S : Sheet;
      Melee, Ranged, Str_Ranged, Both, Eff, Ineff, Half_DX, None, Tk, Plain_Tk : Attack;
   begin
      Sample := To_Unbounded_String ("DX");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Attack", 2); Add (S.Traits, "Strong", 3); Add (S.Traits, "Agile", 2);
      Melee := New_Attack (S);
      Ranged := New_Attack (S); M (Ranged.Mods, "Ranged", 1, 0);
      Str_Ranged := New_Attack (S); M (Str_Ranged.Mods, "Ranged, Strength-Powered", 1, 0);
      Both := New_Attack (S); M (Both.Mods, "Ranged", 1, 0); M (Both.Mods, "Ranged, Strength-Powered", 1, 0);
      Eff := New_Attack (S); M (Eff.Mods, "Effective", 2, 0);
      Ineff := New_Attack (S); M (Ineff.Mods, "Ineffective", 3, 0);
      Half_DX := New_Attack (S); M (Half_DX.Mods, "Ineffective", 6, 0);
      None := New_Attack (S); M (None.Mods, "Area Effect", 2, 0); M (None.Mods, "No Damage", 1, 0);
      Compute (S);
      L ("1 + Attack 2 + Strong 3"); Check_Int (Melee.DX, 6);
      L ("Ranged drops Strong"); Check_Int (Ranged.DX, 3);
      L ("Ranged END"); Check_Int (Ranged.End_Cost, 0);
      L ("Ranged, Strength-Powered keeps Strong"); Check_Int (Str_Ranged.DX, 6);
      L ("Ranged, Strength-Powered END"); Check_Int (Str_Ranged.End_Cost, 5);
      L ("Ranged with Ranged, Strength-Powered keeps Strong"); Check_Int (Both.DX, 6);
      L ("Effective x2"); Check_Int (Eff.DX, 8);
      L ("Effective x2 END"); Check_Int (Eff.End_Cost, 10);
      L ("Ineffective x3"); Check_Int (Ineff.DX, 3);
      L ("Ineffective x6: 0 is 1/2"); Check_Text (Half_DX.DX, "1/2");
      L ("1/2 is half"); Ok (Half (Half_DX.DX) and Value (Half_DX.DX) = 0);
      L ("No Damage: 0, not 1/2"); Check_Int (None.DX, 0);
      L ("No Damage, Area Effect x2 END"); Check_Int (None.End_Cost, 0);
      L ("TV's DX leaves out Effective"); Is_Int (Eff.TV_DX, 6);
      L ("TV's DX leaves out Ineffective"); Is_Int (Half_DX.TV_DX, 6);
      L ("TV's DX leaves out No Damage"); Is_Int (None.TV_DX, 6);
      L ("TV: roll 4 + Defense 2 + DX 6"); Check_Int (S.TV, 12);

      Renew (S, Character_Sheet);
      Add (S.Traits, "Attack", 1); Add (S.Traits, "Weak", -2); Add (S.Traits, "Telekinesis", 3);
      Melee := New_Attack (S);
      Ranged := New_Attack (S); M (Ranged.Mods, "Ranged", 1, 0);
      Tk := New_Attack (S); M (Tk.Mods, "Ranged", 1, 0); Tk.Telekinetic := True;
      Plain_Tk := New_Attack (S); Plain_Tk.Telekinetic := True;
      Compute (S);
      L ("1 + Attack 1 - Weak 2: 0 is 1/2"); Check_Text (Melee.DX, "1/2");
      L ("TV's DX of a 1/2 is 0"); Is_Int (Melee.TV_DX, 0);
      L ("Ranged drops Weak"); Check_Int (Ranged.DX, 2);
      L ("made with Telekinesis 3, Ranged"); Check_Int (Tk.DX, 5);
      L ("made with Telekinesis 3, not Ranged"); Check_Int (Plain_Tk.DX, 3);
      L ("TV's DX keeps Telekinesis"); Is_Int (Tk.TV_DX, 5);
      Free (S);
   end Damage;

   --  END: Endurance Use, on an attack and on an Ability; the floor; a
   --  chosen cost; Unique Perk.
   procedure Endurance is
      S : Sheet;
      A, B, C, D : Attack;
      Barrier, Flight, Plain : Trait;
   begin
      Sample := To_Unbounded_String ("END");
      S := New_Sheet (Character_Sheet);
      A := New_Attack (S); A.Use_Level := -2; M (A.Mods, "Accurate", 1, 0);
      B := New_Attack (S); B.Use_Level := -1; M (B.Mods, "Effective", 2, 0); M (B.Mods, "Weapon", 1, 0);
      C := New_Attack (S);
      M (C.Mods, "Requirement", 1, -15); M (C.Mods, "Area Effect", 1, 0); M (C.Mods, "Cancel", 1, -5);
      D := New_Attack (S); M (D.Mods, "Unique Perk", 1, 15); M (D.Mods, "Ammunition", 3, 0);
      Barrier := T (S.Traits, "Barrier", 3); Barrier.Use_Level := -1;
      M (Barrier.Mods, "Elaborate Gestures", 1, 0);
      Flight := T (S.Traits, "Flight", 2); Flight.Use_Level := -3;
      Plain := T (S.Traits, "Smart", 2);
      Compute (S);
      L ("Endurance Use -2 + Accurate"); Check_Int (A.End_Cost, 15);
      L ("Endurance Use -1 + Effective x2 - Weapon"); Check_Int (B.End_Cost, 10);
      L ("Area Effect - Requirement 15 - Cancel 5, floored"); Check_Int (C.End_Cost, 0);
      L ("Unique Perk 15 - Ammunition x3"); Check_Int (D.End_Cost, 0);
      L ("Barrier with Endurance Use -1 has an END"); Ok (Barrier.Has_End);
      L ("Barrier: Endurance Use -1 - Elaborate Gestures"); Check_Int (Barrier.End_Cost, 0);
      L ("Flight: Endurance Use -3"); Check_Int (Flight.End_Cost, 20);
      L ("Smart has no END"); Ok (not Plain.Has_End);
      L ("no warnings"); Is_Int (Warnings (S), 0);
      Free (S);
   end Endurance;

   --  Spells (p. 58): the table's corners and middle, "+" for Barrier, a
   --  level out of the table, Witchcraft's Weaknesses.
   procedure Spells is
      S : Sheet;
      Magic, Low : Trait;
      A, B, C, D, E : Spell;

      function Sp (Tr : Trait; Name : String; Level : Integer) return Spell is
         Result : constant Spell := new Spell_Record;
      begin
         Init_Spell (Result, Item (Name), Level);
         Add_Spell (Tr, Result);
         return Result;
      end Sp;

   begin
      Sample := To_Unbounded_String ("spells");
      S := New_Sheet (Character_Sheet);
      Magic := T (S.Traits, "Magic, Arcane", 3);
      A := Sp (Magic, "Barrier", 2); B := Sp (Magic, "Flight", 2); C := Sp (Magic, "Quick", 6);
      Low := T (S.Traits, "Magic, Witchcraft", 1);
      D := Sp (Low, "Strong", 5); E := Sp (Low, "Flight", 1);
      Compute (S);
      L ("Magic 3, Barrier 2"); Check_Text (A.End_Cost, "10+");
      L ("Magic 3, Flight 2"); Check_Text (B.End_Cost, "10");
      L ("Magic 1, Strong 5"); Check_Int (D.End_Cost, 60);
      L ("Magic 1, Flight 1"); Check_Int (E.End_Cost, 20);
      L ("Quick 6 is out of the table"); Ok (Warned_Any (S, Spell_Range));
      L ("one warning"); Is_Int (Warnings (S), 1);
      Magic.Level := 5; C.Level := 1; Compute (S);
      L ("Magic 5, Quick 1"); Check_Int (C.End_Cost, 0);
      L ("Magic 5, Barrier 2"); Check_Text (A.End_Cost, "2+");
      --  Witchcraft's curses: Weaknesses, at Arcane's costs, by their
      --  size (p. 58); Acacia's, at Magic 3 (p. 134).
      Magic := T (S.Traits, "Magic, Witchcraft", 3);
      A := Sp (Magic, "Frail", -2); B := Sp (Magic, "Weak", -3); C := Sp (Magic, "Slow", -4);
      Compute (S);
      L ("Witchcraft 3, Frail -2"); Check_Int (A.End_Cost, 10);
      L ("Witchcraft 3, Weak -3"); Check_Int (B.End_Cost, 20);
      L ("Slow -4 is out of the table"); Check_Int (C.End_Cost, 0);
      L ("and warned"); Ok (Warned_Any (S, Spell_Range));
      Free (S);
   end Spells;

   --  Defense, Barrier, Health, Endurance, Endurance Reserve, by sheet
   --  kind.
   procedure Stats is
      S : Sheet;
   begin
      Sample := To_Unbounded_String ("stats");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Evasive", 2); Add (S.Traits, "Quick", 3); Add (S.Traits, "Slow", -1);
      Add (S.Traits, "Barrier", 4);
      Add (S.Traits, "Tough", 5); Add (S.Traits, "Frail", -2);
      Add (S.Traits, "Vigorous", 3); Add (S.Traits, "Languid", -1);
      Add (S.Traits, "Endurance Reserve", 2);
      Compute (S);
      L ("DEFENSE 2 + Evasive 2 + Quick 3 - Slow 1"); Check_Int (S.Defense, 6);
      L ("Barrier"); Ok (S.Has_Barrier);
      L ("Barrier's Defense 2 + 4"); Check_Int (S.Barrier, 6);
      L ("HEALTH 40 + Tough 5's 60 - Frail 2's 20"); Check_Int (S.Health, 80);
      L ("ENDURANCE 40 + Vigorous 3's 30 - Languid 1's 10"); Check_Int (S.Endurance, 60);
      L ("Reserve"); Ok (S.Has_Reserve);
      L ("Endurance Reserve 2"); Check_Int (S.Reserve, 40);
      L ("no Incorporeal Form"); Ok (not S.Has_Incorporeal);

      Renew (S, Character_Sheet); Add (S.Traits, "Incorporeal Form", 3); Compute (S);
      L ("Incorporeal Form"); Ok (S.Has_Incorporeal and not S.Has_Barrier);
      L ("Incorporeal Form's Defense 2 + 3"); Check_Int (S.Incorporeal, 5);
      L ("TV: 2 + Incorporeal Form's Defense 5, the best, + 1"); Check_Int (S.TV, 8);
      Add (S.Traits, "Barrier", 4); Compute (S);
      L ("and Barrier's 2 + 4"); Check_Int (S.Barrier, 6);
      L ("TV: Barrier's Defense 6 the best"); Check_Int (S.TV, 9);
      Override (S.Incorporeal, 8, False, False); Compute (S);
      L ("TV: Incorporeal Form's Defense overridden 8"); Check_Int (S.TV, 11);
      Clear (S.Incorporeal); Add (S.Traits, "Incorporeal Form", 3);
      S.Options.Combined_Effectiveness := True; Compute (S);
      L ("Combined Effectiveness: Incorporeal Form 6 past 5"); Ok (Warned_Any (S, Over_Five));

      Renew (S, Companion_Sheet); Add (S.Traits, "Tough", 1); Compute (S);
      L ("a Companion's HEALTH 20 + Tough 1"); Check_Int (S.Health, 30);
      L ("a Companion's ENDURANCE"); Check_Int (S.Endurance, 20);
      L ("a Companion's TV 2 + 2 + 1 + Tough 1 - 4, at least 1"); Check_Int (S.TV, 2);
      Add (S.Traits, "Frail", -3); Compute (S);
      L ("a Companion's TV, at least 1"); Check_Int (S.TV, 1);
      Renew (S, Minion_Sheet); Compute (S);
      L ("Minions' HEALTH"); Check_Int (S.Health, 10);
      L ("Minions' ENDURANCE"); Check_Int (S.Endurance, 10);
      Renew (S, Extra_Sheet); Add (S.Traits, "Tough", 1); Add (S.Traits, "Armored", 3); Compute (S);
      L ("an Extra's HEALTH 10 + Tough 1"); Check_Int (S.Health, 20);
      L ("an Extra's ENDURANCE"); Check_Int (S.Endurance, 10);
      L ("an Extra's TV, always 1"); Check_Int (S.TV, 1);
      Free (S);
   end Stats;

   --  TV (p. 124): Armored, the signed Health and Endurance levels, the
   --  marked Abilities' halves; Companion never counted.
   procedure Threat_Value is
      S : Sheet;
      Healer, Companion, Smart : Trait;
   begin
      Sample := To_Unbounded_String ("TV");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Armored", 2); Add (S.Traits, "Tough", 1); Add (S.Traits, "Languid", -1);
      Healer := T (S.Traits, "Healer", 3); Add (S.Traits, "Magic, Arcane", 1);
      Companion := T (S.Traits, "Companion", 3); Smart := T (S.Traits, "Smart", 3);
      Compute (S);
      L ("Healer starts marked"); Ok (Healer.Half_TV);
      L ("Companion doesn't"); Ok (not Companion.Half_TV);
      L ("5 + Armored 2 + Tough 1 - Languid 1 + Healer 3/2 + Magic 1/2"); Check_Int (S.TV, 10);
      Companion.Half_TV := True; Compute (S);
      L ("a marked Companion still doesn't count"); Check_Int (S.TV, 10);
      Healer.Half_TV := False; Smart.Half_TV := True; Compute (S);
      L ("Healer unmarked, Smart 3 marked"); Check_Int (S.TV, 10);
      Smart.Half_TV := False; Compute (S);
      L ("neither"); Check_Int (S.TV, 8);
      Free (S);
   end Threat_Value;

   --  Transformation (p. 63): the form counts when the sheet is shown
   --  transformed, or for an attack made in it, which TV then leaves out.
   procedure Transformation is
      S : Sheet;
      Tr : Trait;
      Base, Formed : Attack;
   begin
      Sample := To_Unbounded_String ("Transformation");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Agile", 1); Add (S.Traits, "Tough", 4);
      Tr := T (S.Traits, "Transformation", 2);
      Add (Tr.Form, "Combat Expert", 2); Add (Tr.Form, "Barrier", 1); Add (Tr.Form, "Tough", 3);
      Base := New_Attack (S); Formed := New_Attack (S); Formed.Transformed := True;
      Compute (S);
      L ("ROLL 2 + Agile 1"); Check_Int (Base.Roll, 3);
      L ("made transformed, + Combat Expert 2"); Check_Int (Formed.Roll, 5);
      L ("no Barrier untransformed"); Ok (not S.Has_Barrier);
      L ("HEALTH: Tough 4"); Check_Int (S.Health, 80);
      L ("TV leaves out the transformed attack: 3 + 2 + 1 + Tough 4"); Check_Int (S.TV, 10);
      L ("no warnings"); Is_Int (Warnings (S), 0);
      L ("the form's levels aren't in the totals"); Check_Int (S.Ability_Levels, 7);
      S.Transformed := True; Compute (S);
      L ("transformed: ROLL"); Check_Int (Base.Roll, 5);
      L ("transformed: Barrier"); Ok (S.Has_Barrier);
      L ("transformed: Tough 4 + 3 counted as 5"); Check_Int (S.Health, 100);
      L ("transformed: Tough past 5 warned of"); Ok (Warned_Any (S, Table_Range));
      L ("transformed: TV 5 + Barrier 3 + 1 + Tough 7"); Check_Int (S.TV, 16);
      Free (S);
   end Transformation;

   --  Overrides, and what is computed from them.
   procedure Overrides is
      S : Sheet;
      A, B : Attack;
      Fresh : Attack := new Attack_Record;  --  a new attack's ROLL, for Parse
      N : Number;
   begin
      Sample := To_Unbounded_String ("overrides");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Attack", 2); Add (S.Traits, "Evasive", 1); Add (S.Traits, "Barrier", 1);
      A := New_Attack (S); M (A.Mods, "Accurate", 2, 0); M (A.Mods, "Effective", 1, 0);
      B := New_Attack (S);
      Compute (S);
      L ("TV 2 + Defense 3 + DX 3"); Check_Int (S.TV, 8);
      Override (A.Roll, 10, False, False); Compute (S);
      L ("ROLL overridden"); Check_Int (A.Roll, 10);
      L ("still computed"); Ok (Computed_Text (A.Roll) = "4");
      L ("TV: overridden ROLL 10 less Accurate x2"); Check_Int (S.TV, 14);
      Override (A.DX, 0, True, False); Override (B.DX, 1, False, False); Compute (S);
      L ("DX overridden 1/2"); Check_Text (A.DX, "1/2");
      L ("TV: DX 1/2 and 1"); Check_Int (S.TV, 12);
      Override (B.DX, 7, False, False); Compute (S);
      L ("TV: DX overridden 7"); Check_Int (S.TV, 18);
      Override (S.Barrier, 6, False, False); Compute (S);
      L ("TV: Barrier's Defense overridden 6"); Check_Int (S.TV, 21);
      Override (S.Defense, 9, False, False); Compute (S);
      L ("TV: Defense overridden 9"); Check_Int (S.TV, 24);
      Override (S.TV, 1, False, False); Compute (S);
      L ("TV overridden"); Check_Int (S.TV, 1);
      Clear (S.TV); Clear (S.Defense); Clear (S.Barrier);
      Clear (A.Roll); Clear (A.DX); Clear (B.DX); Compute (S);
      L ("all cleared"); Check_Int (S.TV, 8);
      Override (S.Ability_Levels, 10, False, False); Compute (S);
      L ("Character Total from the overridden Abilities' 10"); Check_Int (S.Total, 10);
      S.Options.Base_Zero := True; S.Options.Base_Zero_Range := 5; Compute (S);
      L ("and Base Zero checks it"); Ok (Warned_Any (S, Base_Zero_Broken));
      Clear (S.Ability_Levels); Compute (S);
      L ("cleared: Base Zero kept"); Ok (not Warned_Any (S, Base_Zero_Broken));

      Sample := To_Unbounded_String ("Parse");
      Init_Attack (Fresh); N := Fresh.Roll;
      L ("12"); Ok (Parse ("12", False, False, N) and then Overridden (N) and then Value (N) = 12);
      L ("' -2 '"); Ok (Parse (" -2 ", False, False, N) and then Value (N) = -2);
      L ("blank clears"); Ok (Parse ("  ", False, False, N) and then not Overridden (N));
      L ("1/2 for a DX"); Ok (Parse ("1/2", True, False, N) and then Half (N));
      L ("1/2 only for a DX"); Ok (not Parse ("1/2", False, True, N) and then Half (N));
      L ("10+ for an END"); Ok (Parse ("10+", False, True, N) and then Plus (N));
      L ("10+ written back"); Ok (Text (N) = "10+");
      L ("10+ only for an END"); Ok (not Parse ("10+", True, False, N));
      L ("x refused"); Ok (not Parse ("x", True, True, N));
      L ("+ refused"); Ok (not Parse ("+", True, True, N));
      L ("- refused"); Ok (not Parse ("-", True, True, N));
      L ("4 5 refused"); Ok (not Parse ("4 5", True, True, N));
      Free_Attacks (Fresh);
      Free (S);
   end Overrides;

   --  The limits (p. 21) and the totals they check.
   procedure Limits is
      S : Sheet;
      Know, Inept : Trait;
      A, B : Attack;
   begin
      Sample := To_Unbounded_String ("limits");
      S := New_Sheet (Character_Sheet);
      Add (S.Traits, "Agile", 4); Add (S.Traits, "Smart", 4); Add (S.Traits, "Weak", -1);
      Compute (S);
      L ("Abilities"); Check_Int (S.Ability_Levels, 8);
      L ("Weaknesses"); Check_Int (S.Weakness_Levels, -1);
      L ("Character Total"); Check_Int (S.Total, 7);
      L ("Scaled Cost points 8 + 8 - 1"); Check_Int (S.Points, 15);
      L ("no limits, no warnings"); Is_Int (Warnings (S), 0);
      S.Options.Base_Zero := True; S.Options.Base_Zero_Range := 5; Compute (S);
      L ("Base Zero: 7 is past 5"); Ok (Warned_Any (S, Base_Zero_Broken));
      Add (S.Traits, "Poor", -2); Compute (S);
      L ("Base Zero: 5 isn't"); Ok (not Warned_Any (S, Base_Zero_Broken));
      S.Options.Scaled_Cost := True; Compute (S);
      L ("Scaled Cost points 16 - 1 - 2"); Check_Int (S.Points, 13);
      L ("Base Zero on Scaled Cost's points: 13 is past 5"); Ok (Warned_Any (S, Base_Zero_Broken));

      Renew (S, Character_Sheet);
      Add (S.Traits, "Agile", 5); Add (S.Traits, "Smart", 5); Add (S.Traits, "Quick", 5);
      Add (S.Traits, "Poor", -3); Add (S.Traits, "Rude", -3); Add (S.Traits, "Shy", -3);
      Add (S.Traits, "Mute", -1);
      S.Options.Power_Ceiling := True; S.Options.Ceiling := 15;
      S.Options.Starting_Levels := True; S.Options.Starting := 5;
      Compute (S);
      L ("Power Ceiling 15, 15 levels"); Ok (not Warned_Any (S, Ceiling_Broken));
      L ("starting 5 + Weaknesses 10"); Ok (not Warned_Any (S, Starting_Broken));
      Know := T (S.Traits, "Knowledge", 1); Compute (S);
      L ("Power Ceiling 15, 16 levels"); Ok (Warned_Any (S, Ceiling_Broken));
      L ("starting 5 + Weaknesses 10, 16 levels"); Ok (Warned_Any (S, Starting_Broken));
      S.Options.Half_Cost_Knowledge := True; Know.Level := 2; Compute (S);
      L ("Knowledge 2 at half cost"); Check_Int (S.Ability_Levels, 16);
      Know.Level := 3; Inept := T (S.Traits, "Ineptitude", -3); Compute (S);
      L ("Knowledge 3 at half cost, rounded up"); Check_Int (S.Ability_Levels, 17);
      L ("Ineptitude -3 at half cost, rounded up"); Check_Int (S.Weakness_Levels, -12);
      S.Options.Scaled_Cost := True; Know.Level := 5; Compute (S);
      L ("Scaled Cost: Knowledge 5 at half cost, 8"); Check_Int (S.Ability_Points, 53);
      L ("Scaled Cost: Ineptitude -3 at half cost, 2"); Is_Int (S.Weakness_Points, 15);
      L ("Scaled Cost: Knowledge 5's own points, halved"); Is_Int (Know.Points, 8);
      L ("Scaled Cost: Ineptitude -3's own points, halved"); Is_Int (Inept.Points, 2);
      L ("Scaled Cost: Agile 5's own points"); Is_Int (S.Traits.Points, 15);
      L ("Power Ceiling on Scaled Cost's points"); Ok (Warned_Any (S, Ceiling_Broken));
      Override (S.Ability_Points, 15, False, False); Compute (S);
      L ("Ability points overridden to 15: the points 15 - 15"); Check_Int (S.Points, 0);
      L ("Power Ceiling 15 on the overridden Ability points");
      Ok (not Warned_Any (S, Ceiling_Broken));
      Clear (S.Ability_Points);
      S.Options.Power_Ceiling := False; S.Options.Starting_Levels := False;
      S.Options.Scaled_Cost := False;
      Compute (S);
      L ("no limit, no half cost"); Check_Int (S.Ability_Levels, 20);
      L ("no limit, no warnings"); Is_Int (Warnings (S), 0);

      Renew (S, Character_Sheet);
      Add (S.Traits, "Agile", 4); Add (S.Traits, "Combat Expert", 2);
      Add (S.Traits, "Evasive", 3); Add (S.Traits, "Quick", 2);
      A := New_Attack (S);
      Compute (S);
      L ("Combined Effectiveness off"); Is_Int (Warnings (S), 0);
      S.Options.Combined_Effectiveness := True; Compute (S);
      L ("Combined Effectiveness: ROLL +6"); Ok (Warned (S, Over_Five, A));
      L ("Combined Effectiveness: Defense +5 is all right"); Ok (not Warned (S, Over_Five, null));
      Add (S.Traits, "Quick", 1); Compute (S);
      L ("Combined Effectiveness: Defense +6"); Ok (Warned (S, Over_Five, null));

      Sample := To_Unbounded_String ("warnings");
      Renew (S, Character_Sheet);
      A := New_Attack (S);
      M (A.Mods, "Paralyzing", 2, 0); M (A.Mods, "Requirement", 1, -10); M (A.Mods, "Cancel", 1, 0);
      M (A.Mods, "Redirectable", 1, 0); M (A.Mods, "Ranged", 1, 0); M (A.Mods, "No Damage", 1, 0);
      M (A.Mods, "Effective", 1, 0);
      Compute (S);
      L ("within the limits"); Is_Int (Warnings (S), 0);
      B := New_Attack (S);
      M (B.Mods, "Paralyzing", 3, 0); M (B.Mods, "Requirement", 1, -25);
      M (B.Mods, "Cancel", 1, -7); M (B.Mods, "Redirectable", 1, 0); M (B.Mods, "No Damage", 1, 0);
      M (B.Mods, "Ineffective", 1, 0); M (B.Mods, "Ammunition", 4, 0);
      Compute (S);
      L ("Paralyzing x3, Ammunition x4"); Ok (Warned (S, Too_Often, B));
      L ("Requirement -25, Cancel -7"); Ok (Warned (S, Cost_Range, B));
      L ("Redirectable not Ranged"); Ok (Warned (S, Redirectable_Alone, B));
      L ("No Damage with Ineffective"); Ok (Warned (S, No_Damage_Ineffective, B));
      L ("six warnings"); Is_Int (Warnings (S), 6);
      Renew (S, Character_Sheet);
      Add (S.Traits, "Agile", 6); Add (S.Traits, "Weak", 0); Add (S.Traits, "Poor", -4);
      Know := new Trait_Record;
      Init_Trait (Know, null, Ova_Cg.Rules.Ability, 2); Add_Trait (S.Traits, Know);
      Compute (S);
      L ("an unknown Ability"); Ok (Warned_Any (S, Unknown_Item));
      L ("an unknown Ability counts in the totals"); Check_Int (S.Ability_Levels, 8);
      L ("Agile 6, Weak 0, Poor -4"); Is_Int (Warnings (S), 4);
      Free (S);
   end Limits;

begin
   Samples12;
   Plain; Rolls; Damage; Endurance; Spells; Stats; Threat_Value; Transformation; Overrides; Limits;
   Check.Summary;
end Test_Calc;
