with Ada.Characters.Handling;
with Ada.Exceptions;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with Libfyaml.Documents.Streams;
with Libfyaml.Nodes;

package body Ova_Cg.Character is

   package E renames Ova_Fmt.Entities;

   use type Calc.Trait;
   use type Calc.Modifier;
   use type Calc.Spell;
   use type Calc.Attack;
   use type Calc.Sheet;
   use type Rules.Item;
   use type Rules.Kind;
   use type Rules.Link;
   use type Rules.Cost_Kind_Type;
   use type E.Sub_Entity_Access;

   The_Notices : Text_Vectors.Vector;

   function Notices return Text_Vectors.Vector is (The_Notices);

   procedure Free_All (Cs : in out Characters) is
      S : Calc.Sheet;
   begin
      for C of Cs loop
         S := Calc.Sheet (C);
         Calc.Free (S);
      end loop;
      Cs.Clear;
   end Free_All;

   --  ---- Text ----

   Blanks : constant String := ' ' & ASCII.HT & ASCII.LF & ASCII.CR;

   function Trim (S : String) return String is
      First : Positive := S'First;
      Last  : Natural := S'Last;
   begin
      while First <= Last and then Ada.Strings.Fixed.Index (Blanks, S (First .. First)) > 0 loop
         First := First + 1;
      end loop;
      while Last >= First and then Ada.Strings.Fixed.Index (Blanks, S (Last .. Last)) > 0 loop
         Last := Last - 1;
      end loop;
      return S (First .. Last);
   end Trim;

   --  Folded as ova_fmt sorts: Ada.Characters.Handling.To_Lower.
   function Fold (S : Unbounded_String) return String is
     (Ada.Characters.Handling.To_Lower (To_String (S)));

   --  I in decimal, with a leading "-" if negative and no blanks.
   function Image (I : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Left));

   --  ---- Endurance Use ----

   --  Whether Name, or Name and Detail as "Name (detail)", is Target,
   --  ignoring case.
   function Names (Name, Detail, Target : Unbounded_String) return Boolean is
      T : constant String := Ada.Characters.Handling.To_Lower (Trim (To_String (Target)));
      Full : Unbounded_String := Name;
   begin
      if Length (Detail) > 0 then
         Append (Full, " (" & Detail & ")");
      end if;
      return T /= "" and then (Fold (Name) = T or else Fold (Full) = T);
   end Names;

   --  Ties each Endurance Use in List to the Ability in List, or else
   --  the attack of S, that its detail names (ova_cg_po's PLAN.md,
   --  "Changes to ova_fmt": it needs no key of its own), setting their
   --  Use_Level; one naming nothing ties to nothing.
   procedure Link_List (List : Calc.Trait; S : not null Calc.Sheet) is
      W, T  : Calc.Trait := List;
      A     : Calc.Attack;
      Found : Boolean;
   begin
      while W /= null loop
         if W.Of_Kind = Rules.Weakness and then W.Item /= null and then Rules.Has (W.Item, Rules.Cost_Up)
           and then Trait (W).Has_Detail
         then
            Found := False;
            T := List;
            while not Found and then T /= null loop
               if T.Of_Kind = Rules.Ability
                 and then Names (Trait (T).Name, Trait (T).Detail, Trait (W).Detail)
               then
                  T.Use_Level := W.Level;
                  Found := True;
               end if;
               T := T.Next;
            end loop;
            A := S.Attacks;
            while not Found and then A /= null loop
               if Names (Attack (A).Name, Null_Unbounded_String, Trait (W).Detail) then
                  A.Use_Level := W.Level;
                  Found := True;
               end if;
               A := A.Next;
            end loop;
         end if;
         W := W.Next;
      end loop;
   end Link_List;

   procedure Clear_Use (List : Calc.Trait) is
      T : Calc.Trait := List;
   begin
      while T /= null loop
         T.Use_Level := 0;
         T := T.Next;
      end loop;
   end Clear_Use;

   --  Every Endurance Use of S, its Transformations' forms and its
   --  partners, tied to what it names.
   procedure Link (S : not null Calc.Sheet) is
      T : Calc.Trait := S.Traits;
      A : Calc.Attack := S.Attacks;
   begin
      Clear_Use (S.Traits);
      while A /= null loop
         A.Use_Level := 0;
         A := A.Next;
      end loop;
      while T /= null loop
         Clear_Use (T.Form);
         T := T.Next;
      end loop;
      Link_List (S.Traits, S);
      T := S.Traits;
      while T /= null loop
         Link_List (T.Form, S);
         if T.Partner /= null then
            Link (T.Partner);
         end if;
         T := T.Next;
      end loop;
   end Link;

   procedure Recompute (C : not null Character_Access) is
   begin
      Link (Calc.Sheet (C));
      Calc.Compute (Calc.Sheet (C));
   end Recompute;

   --  ---- Building from what Ova_Fmt.Entities read ----

   function Find (Name : Unbounded_String) return Rules.Item is (Rules.Find (To_String (Name)));

   function New_Sheet (Of_Kind : Calc.Sheet_Kind) return not null Character_Access is
      C : constant Character_Access := new Character_Record;
   begin
      Calc.Init_Sheet (Calc.Sheet (C), Of_Kind);
      return C;
   end New_Sheet;

   --  The sheet kind of an NPC type (p. 123-124): a Heroic NPC's is a
   --  character's, a Secondary's a Companion's, an Extra's and a Boss's
   --  their own; no type is a character's.
   function Kind_Of (Has : Boolean; NPC_Type : E.NPC_Kind) return Calc.Sheet_Kind is
     (if not Has then Calc.Character_Sheet
      else (case NPC_Type is
               when E.Heroic    => Calc.Character_Sheet,
               when E.Secondary => Calc.Companion_Sheet,
               when E.Extra     => Calc.Extra_Sheet,
               when E.Boss      => Calc.Boss_Sheet));

   procedure Set_NPC_Type (C : not null Character_Access; Has : Boolean; NPC_Type : E.NPC_Kind) is
   begin
      C.Has_NPC_Type := Has;
      C.NPC_Type := (if Has then NPC_Type else E.Heroic);
      C.Of_Kind := Kind_Of (Has, NPC_Type);
   end Set_NPC_Type;

   function New_Character return not null Character_Access is (New_Sheet (Calc.Character_Sheet));

   --  L's Perks (Is_Flaw False) or Flaws, added to Mods.
   procedure Add_Mods (L : E.Perk_Flaw_Vectors.Vector; Is_Flaw : Boolean; Mods : in out Calc.Modifier) is
      M : Modifier;
   begin
      for PF of L loop
         M := new Modifier_Record;
         Calc.Init_Mod (Calc.Modifier (M), Find (PF.Name), (if PF.Has_Counts_As then PF.Counts_As else 1),
                        (if PF.Has_Cost then PF.Cost else 0));
         M.Name := PF.Name;
         M.Has_Detail := PF.Has_Detail;
         M.Detail := PF.Detail;
         M.Is_Flaw := Is_Flaw;
         M.Has_Cost := PF.Has_Cost;
         Calc.Add_Mod (Mods, Calc.Modifier (M));
      end loop;
   end Add_Mods;

   function Sub_Trait (X : E.Sub_Item; Of_Kind : Rules.Kind) return not null Trait is
      T : constant Trait := new Trait_Record;
   begin
      Calc.Init_Trait (Calc.Trait (T), Find (X.Name), Of_Kind, X.Level);
      T.Name := X.Name;
      T.Has_Detail := X.Has_Detail;
      T.Detail := X.Detail;
      T.Has_Note := X.Has_Note;
      T.Note := X.Note;
      T.Has_Half_TV := X.Has_Threat_Value_Half;
      if X.Has_Threat_Value_Half then
         T.Half_TV := X.Threat_Value_Half;
      end if;
      Add_Mods (X.Perks, False, T.Mods);
      Add_Mods (X.Flaws, True, T.Mods);
      return T;
   end Sub_Trait;

   procedure Sub_Traits (L : E.Sub_Item_Vectors.Vector; Of_Kind : Rules.Kind; List : in out Calc.Trait) is
   begin
      for X of L loop
         Calc.Add_Trait (List, Calc.Trait (Sub_Trait (X, Of_Kind)));
      end loop;
   end Sub_Traits;

   procedure Attacks (X : E.Combat_Stats; C : not null Character_Access) is
      A : Attack;
   begin
      C.Has_Combat := X.Has_Combat;
      C.Has_Threat_Value := X.Has_Threat_Value;
      C.Has_Combat_Notes := X.Has_Notes;
      C.Combat_Notes := X.Notes;
      C.Transformed := X.Transformed;
      for Y of X.Attacks loop
         A := new Attack_Record;
         Calc.Init_Attack (Calc.Attack (A));
         A.Name := Y.Name;
         A.Has_Affinity := Y.Has_Affinity;
         A.Affinity := Y.Affinity;
         A.Has_Description := Y.Has_Description;
         A.Description := Y.Description;
         A.Telekinetic := Y.Telekinesis;
         A.Transformed := Y.Transformed;
         Add_Mods (Y.Perks, False, A.Mods);
         Add_Mods (Y.Flaws, True, A.Mods);
         Calc.Add_Attack (Calc.Sheet (C), Calc.Attack (A));
      end loop;
   end Attacks;

   --  A Companion's sheet (a Secondary NPC's), or a Vehicle's (a
   --  character's).
   function Partner (X : E.Sub_Entity_Record) return not null Character_Access is
      C : constant Character_Access :=
        New_Sheet (if X.Label = "Companion" then Calc.Companion_Sheet else Calc.Character_Sheet);
   begin
      C.Label := X.Label;
      C.Name := X.Name;
      C.Is_Fragment := X.Is_Fragment;
      Sub_Traits (X.Abilities, Rules.Ability, C.Traits);
      Sub_Traits (X.Weaknesses, Rules.Weakness, C.Traits);
      Attacks (X.Combat, C);
      return C;
   end Partner;

   function Fluff_Flags_Of (F : E.Fluff_Block) return Fluff_Flags is
     [F.Has_Concept, F.Has_Birthday, F.Has_Age, F.Has_Gender, F.Has_Height, F.Has_Weight, F.Has_Hair,
      F.Has_Eyes, F.Has_Association, F.Has_Hobbies, F.Has_Favorite_Food, F.Has_Allies, F.Has_Enemies,
      F.Has_Love_Interests];

   function Fluff_Texts_Of (F : E.Fluff_Block) return Fluff_Texts is
     [F.Concept, F.Birthday, F.Age, F.Gender, F.Height, F.Weight, F.Hair, F.Eyes, F.Association,
      F.Hobbies, F.Favorite_Food, F.Allies, F.Enemies, F.Love_Interests];

   function Build (E : Ova_Fmt.Entities.Entity) return not null Character_Access is
      C  : constant Character_Access := New_Character;
      T  : Trait;
      Sp : Spell;
   begin
      C.Name := E.Name;
      C.Has_Player := E.Has_Player;
      C.Player := E.Player;
      C.Has_Portrait := E.Has_Portrait;
      C.Portrait := E.Portrait;
      C.Has_Tagline := E.Has_Tagline;
      C.Tagline := E.Tagline;
      C.Has_Summary := E.Has_Summary;
      C.Summary := E.Summary;
      C.Has_Background := E.Has_Background;
      C.Background := E.Background;
      C.Has_Appearance := E.Has_Appearance;
      C.Appearance := E.Appearance;
      C.Has_Personality := E.Has_Personality;
      C.Personality := E.Personality;
      C.Has_Character_Hooks := E.Has_Character_Hooks;
      C.Character_Hooks := E.Character_Hooks;
      Set_NPC_Type (C, E.Has_NPC_Type, E.NPC_Type);
      C.Has_Other_Notes := E.Has_Other_Notes;
      C.Other_Notes := E.Other_Notes;
      C.Is_Fragment := E.Is_Fragment;
      for A of E.Abilities loop
         T := Sub_Trait
           ((Name => A.Name, Level => A.Level, Has_Detail => A.Has_Detail, Detail => A.Detail,
             Perks => A.Perks, Flaws => A.Flaws, Has_Endurance => A.Has_Endurance,
             Endurance => A.Endurance, Has_Note => A.Has_Note, Note => A.Note,
             Has_Threat_Value_Half => A.Has_Threat_Value_Half,
             Threat_Value_Half => A.Threat_Value_Half, Overrides => A.Overrides),
            Rules.Ability);
         Sub_Traits (A.Sub_Abilities, Rules.Ability, T.Form);
         Sub_Traits (A.Sub_Weaknesses, Rules.Weakness, T.Form);
         for X of A.Spells loop
            Sp := new Spell_Record;
            Calc.Init_Spell (Calc.Spell (Sp), Find (X.Ability), X.Level);
            Sp.Name := X.Name;
            Sp.Ability := X.Ability;
            Calc.Add_Spell (Calc.Trait (T), Calc.Spell (Sp));
         end loop;
         if A.Sub_Entity /= null then
            T.Partner := Calc.Sheet (Partner (A.Sub_Entity.all));
         end if;
         Calc.Add_Trait (C.Traits, Calc.Trait (T));
      end loop;
      for W of E.Weaknesses loop
         T := new Trait_Record;
         Calc.Init_Trait (Calc.Trait (T), Find (W.Name), Rules.Weakness, W.Level);
         T.Name := W.Name;
         T.Has_Detail := W.Has_Detail;
         T.Detail := W.Detail;
         Calc.Add_Trait (C.Traits, Calc.Trait (T));
      end loop;
      Attacks (E.Combat, C);
      C.Notes := E.Notes;
      C.Has_Fluff := E.Has_Fluff;
      C.Has_Fluff_Field := Fluff_Flags_Of (E.Fluff);
      C.Fluff := Fluff_Texts_Of (E.Fluff);
      C.Has_Options := E.Has_Options;
      if E.Has_Options then
         C.Options :=
           (Base_Zero              => E.Options.Has_Base_Zero,
            Base_Zero_Range        => (if E.Options.Has_Base_Zero then E.Options.Base_Zero else 0),
            Power_Ceiling          => E.Options.Has_Power_Ceiling,
            Ceiling                => (if E.Options.Has_Power_Ceiling then E.Options.Power_Ceiling else 0),
            Starting_Levels        => E.Options.Has_Starting_Levels,
            Starting               => (if E.Options.Has_Starting_Levels then E.Options.Starting_Levels else 0),
            Scaled_Cost            => E.Options.Scaled_Cost,
            Half_Cost_Knowledge    => E.Options.Half_Cost_Knowledge,
            Combined_Effectiveness => E.Options.Combined_Effectiveness);
      end if;
      Recompute (C);
      return C;
   end Build;

   procedure Free_Entity (E : in out Ova_Fmt.Entities.Entity) is
      procedure Dispose is new Ada.Unchecked_Deallocation (Ova_Fmt.Entities.Sub_Entity_Record,
                                                           Ova_Fmt.Entities.Sub_Entity_Access);
   begin
      for A of E.Abilities loop
         Dispose (A.Sub_Entity);
      end loop;
   end Free_Entity;

   --  ---- The file's numbers ----

   --  Notes that Where's What is File in the file and Computed by the
   --  rules, kept as an override.
   procedure Notice (Where : Unbounded_String; What, File, Computed : String) is
   begin
      The_Notices.Append (Where & ": " & What & " is " & File & " in the file, " & Computed
                          & " by the rules: kept as an override");
   end Notice;

   function Best_Defense (C : not null Character_Access) return Slot is
      Best  : Slot := Defense_Slot;
      Value : Integer := Calc.Value (C.Defense);
   begin
      if C.Has_Barrier and then Calc.Value (C.Barrier) > Value then
         Best := Barrier_Slot;
         Value := Calc.Value (C.Barrier);
      end if;
      if C.Has_Incorporeal and then Calc.Value (C.Incorporeal) > Value then
         Best := Incorporeal_Slot;
      end if;
      return Best;
   end Best_Defense;

   function Single_Defense (C : not null Character_Access; Which : out Slot) return Boolean is
      N : Natural := 0;
   begin
      Which := Best_Defense (C);
      if Calc.Overridden (C.Defense) then
         N := N + 1;
         Which := Defense_Slot;
      end if;
      if Calc.Overridden (C.Barrier) then
         N := N + 1;
         Which := Barrier_Slot;
      end if;
      if Calc.Overridden (C.Incorporeal) then
         N := N + 1;
         Which := Incorporeal_Slot;
      end if;
      return C.Omit_Alternates and then (N = 0 or else (N = 1 and then Which = C.Single_Slot));
   end Single_Defense;

   --  The file's text for N: N's override if Listed (the mapping's
   --  overrides: names it), or if it differs from the computed number,
   --  with a notice.  Text that isn't a number for N is noted and
   --  dropped, the computed number kept.
   procedure Adopt (N : in out Calc.Number; File : String; Allow_Half, Allow_Plus, Listed : Boolean;
                    Where : Unbounded_String; What : String)
   is
      Computed : constant String := Calc.Computed_Text (N);
      T        : Calc.Number := N;
   begin
      Calc.Clear (T);
      if not Calc.Parse (File, Allow_Half, Allow_Plus, T) or else not Calc.Overridden (T) then
         The_Notices.Append (Where & ": " & What & " is " & File & " in the file, not a number: "
                             & Computed & " by the rules is used");
      elsif Listed then
         N := T;
      elsif Calc.Text (T) /= Computed then
         N := T;
         Notice (Where, What, Calc.Text (T), Computed);
      end if;
   end Adopt;

   procedure Adopt_Int (N : in out Calc.Number; I : Integer; Listed : Boolean; Where : Unbounded_String;
                        What : String) is
   begin
      Adopt (N, Image (I), False, False, Listed, Where, What);
   end Adopt_Int;

   --  Where, ": ", and Name.
   function Within (Where, Name : Unbounded_String) return Unbounded_String is (Where & ": " & Name);

   --  The file's value V for Defense slot Which of C.
   procedure Adopt_Defense (C : not null Character_Access; Which : Slot; V : String; Listed : Boolean;
                            Where : Unbounded_String) is
   begin
      case Which is
         when Defense_Slot =>
            Adopt (C.Defense, V, False, False, Listed, Where, "DEFENSE");
         when Barrier_Slot =>
            Adopt (C.Barrier, V, False, False, Listed, Where, "Barrier's DEFENSE");
         when Incorporeal_Slot =>
            Adopt (C.Incorporeal, V, False, False, Listed, Where, "Incorporeal Form's DEFENSE");
      end case;
   end Adopt_Defense;

   --  The Defense values of X's defense: one is the best of C's, two
   --  its Defense and its first alternate, three its Defense, Barrier's
   --  and Incorporeal Form's (ova_fmt allows no more).
   procedure Adopt_Defenses (X : E.Combat_Stats; C : not null Character_Access; Where : Unbounded_String) is
      D     : constant String := To_String (X.Defense);
      V     : array (1 .. 3) of Unbounded_String;
      N     : Natural := 0;
      From  : Positive := D'First;
      Slash : Natural := Ada.Strings.Fixed.Index (D, "/");
      Second : Slot;
   begin
      while Slash > 0 and then N < 2 loop
         N := N + 1;
         V (N) := To_Unbounded_String (D (From .. Slash - 1));
         From := Slash + 1;
         Slash := Ada.Strings.Fixed.Index (D (From .. D'Last), "/");
      end loop;
      N := N + 1;
      V (N) := To_Unbounded_String (D (From .. D'Last));
      if N = 1 then
         C.Omit_Alternates := C.Has_Barrier or else C.Has_Incorporeal;
         C.Single_Slot := Best_Defense (C);
         Adopt_Defense (C, C.Single_Slot, To_String (V (1)), X.Overrides (E.Defense), Where);
      else
         Adopt_Defense (C, Defense_Slot, To_String (V (1)), X.Overrides (E.Defense), Where);
         if N = 3 then
            Adopt_Defense (C, Barrier_Slot, To_String (V (2)), X.Overrides (E.Defense_2), Where);
            Adopt_Defense (C, Incorporeal_Slot, To_String (V (3)), X.Overrides (E.Defense_3), Where);
         else
            Second := (if not C.Has_Barrier and then C.Has_Incorporeal then Incorporeal_Slot else Barrier_Slot);
            Adopt_Defense (C, Second, To_String (V (2)), X.Overrides (E.Defense_2), Where);
         end if;
      end if;
   end Adopt_Defenses;

   --  The numbers of a combat: block but TV.
   procedure Adopt_Combat (X : E.Combat_Stats; C : not null Character_Access; Where : Unbounded_String) is
      A : Calc.Attack := C.Attacks;
   begin
      if not X.Has_Combat then
         return;
      end if;
      for Y of X.Attacks loop
         declare
            At_Attack : constant Unbounded_String := Within (Where, Y.Name);
         begin
            Adopt_Int (A.Roll, Y.Roll, Y.Overrides (E.Roll), At_Attack, "ROLL");
            Adopt (A.DX, To_String (Y.Dx), True, False, Y.Overrides (E.Dx), At_Attack, "DX");
            Adopt_Int (A.End_Cost, Y.Endurance, Y.Overrides (E.Endurance), At_Attack, "END");
         end;
         A := A.Next;
      end loop;
      Adopt_Defenses (X, C, Where);
      Adopt_Int (C.Health, X.Health, X.Overrides (E.Health), Where, "HEALTH");
      Adopt_Int (C.Endurance, X.Endurance, X.Overrides (E.Endurance), Where, "ENDURANCE");
   end Adopt_Combat;

   procedure Adopt_Sub_Items (L : E.Sub_Item_Vectors.Vector; List : Calc.Trait; Where : Unbounded_String) is
      T : Calc.Trait := List;
   begin
      for X of L loop
         if X.Has_Endurance then
            Adopt_Int (T.End_Cost, X.Endurance, X.Overrides (E.Endurance), Within (Where, X.Name), "END");
         end if;
         T := T.Next;
      end loop;
   end Adopt_Sub_Items;

   --  Every number but TV, which is computed from them, and then TV.
   procedure Adopt_Numbers (E : Ova_Fmt.Entities.Entity; C : not null Character_Access) is
      T  : Calc.Trait := C.Traits;
      Sp : Calc.Spell;
      P  : Character_Access;
   begin
      for A of E.Abilities loop
         if A.Has_Endurance then
            Adopt_Int (T.End_Cost, A.Endurance, A.Overrides (Ova_Fmt.Entities.Endurance), Within (C.Name, A.Name),
                       "END");
         end if;
         Adopt_Sub_Items (A.Sub_Abilities, T.Form, Within (C.Name, A.Name));
         Sp := T.Spells;
         for X of A.Spells loop
            Adopt (Sp.End_Cost, To_String (X.Endurance), False, True, X.Overrides (Ova_Fmt.Entities.Endurance),
                   Within (C.Name, X.Name), "END");
            Sp := Sp.Next;
         end loop;
         if A.Sub_Entity /= null then
            P := Character_Access (T.Partner);
            Adopt_Sub_Items (A.Sub_Entity.Abilities, P.Traits, P.Name);
            Adopt_Combat (A.Sub_Entity.Combat, P, P.Name);
         end if;
         T := T.Next;
      end loop;
      Adopt_Combat (E.Combat, C, C.Name);
      Recompute (C);
      T := C.Traits;
      for A of E.Abilities loop
         if A.Sub_Entity /= null and then A.Sub_Entity.Combat.Has_Combat
           and then A.Sub_Entity.Combat.Has_Threat_Value
         then
            P := Character_Access (T.Partner);
            Adopt_Int (P.TV, A.Sub_Entity.Combat.Threat_Value,
                       A.Sub_Entity.Combat.Overrides (Ova_Fmt.Entities.Threat_Value), P.Name, "TV");
         end if;
         T := T.Next;
      end loop;
      if E.Combat.Has_Combat and then E.Combat.Has_Threat_Value then
         Adopt_Int (C.TV, E.Combat.Threat_Value, E.Combat.Overrides (Ova_Fmt.Entities.Threat_Value), C.Name,
                    "TV");
      end if;
      Recompute (C);
   end Adopt_Numbers;

   function From_Entity (E : Ova_Fmt.Entities.Entity) return not null Character_Access is
      C : constant Character_Access := Build (E);
   begin
      Adopt_Numbers (E, C);
      return C;
   end From_Entity;

   --  ---- Files ----

   procedure Free_Entities (Es : in out E.Entity_Vectors.Vector) is
   begin
      for X of Es loop
         Free_Entity (X);
      end loop;
      Es.Clear;
   end Free_Entities;

   --  Every entity of the file at Path, of every document in it, in
   --  order, read as ova_fmt reads them.  False, with Msg, if it can't
   --  be read, or Ova_Fmt.Entities finds a problem in any of them; Es is
   --  then empty.
   function Read_Entities (Path : String; Es : out E.Entity_Vectors.Vector; Msg : out Unbounded_String)
     return Boolean
   is
      package Streams renames Libfyaml.Documents.Streams;
      Ok : Boolean := True;
   begin
      Es.Clear;
      Msg := Null_Unbounded_String;
      E.Reset_Errors;
      declare
         S : Streams.Document_Stream := Streams.Open_File (Path);
      begin
         while Ok and then S.Has_Next loop
            declare
               D    : constant Libfyaml.Documents.Document := S.Next;
               Root : constant Libfyaml.Nodes.Node := D.Root;
            begin
               if not Root.Is_Valid or else not Root.Is_Sequence then
                  Msg := To_Unbounded_String ("expected a top-level YAML sequence of entities in " & Path);
                  Ok := False;
               else
                  for I in 1 .. Root.Length loop
                     Es.Append (E.Load_Entity (Root.Item (I)));
                  end loop;
               end if;
            end;
         end loop;
      end;
      if Ok and then E.Error_Count > 0 then
         for Le of E.Errors loop
            if Length (Msg) > 0 then
               Append (Msg, ASCII.LF);
            end if;
            Append (Msg, Le.Path & ": " & Le.Message);
         end loop;
         Ok := False;
      end if;
      if not Ok then
         Free_Entities (Es);
      end if;
      return Ok;
   exception
      when X : Libfyaml.Parse_Error | Libfyaml.Missing_Key | Libfyaml.Data_Error | E.Shape_Error
             | Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         Msg := To_Unbounded_String (Trim (Ada.Exceptions.Exception_Message (X)));
         Free_Entities (Es);
         return False;
   end Read_Entities;

   function Read_Entity
     (Path : String; First : out Ova_Fmt.Entities.Entity; N : out Natural;
      Msg : out Unbounded_String) return Boolean
   is
      Es : E.Entity_Vectors.Vector;
      Ok : constant Boolean := Read_Entities (Path, Es, Msg);
      None : Ova_Fmt.Entities.Entity;
   begin
      N := Natural (Es.Length);
      if Ok and then N > 0 then
         First := Es.First_Element;
         Es.Delete_First;
      else
         First := None;
      end if;
      Free_Entities (Es);
      return Ok;
   end Read_Entity;

   function One (C : not null Character_Access) return Characters is
   begin
      return Cs : Characters do
         Cs.Append (C);
      end return;
   end One;

   function Load_All (Path : String; Cs : out Characters; Msg : out Unbounded_String) return Boolean is
      Es : E.Entity_Vectors.Vector;
   begin
      Cs.Clear;
      The_Notices.Clear;
      if not Read_Entities (Path, Es, Msg) then
         return False;
      end if;
      if Es.Is_Empty then
         Msg := To_Unbounded_String (Path & " holds no characters");
         return False;
      end if;
      for X of Es loop
         Cs.Append (From_Entity (X));
      end loop;
      Free_Entities (Es);
      return True;
   end Load_All;

   function Load (Path : String; C : out Character_Access; Msg : out Unbounded_String) return Boolean is
      Cs : Characters;
   begin
      C := null;
      if not Load_All (Path, Cs, Msg) then
         return False;
      end if;
      if Natural (Cs.Length) /= 1 then
         Msg := To_Unbounded_String (Path & " holds " & Image (Natural (Cs.Length)) & " characters, not one");
         Free_All (Cs);
         return False;
      end if;
      C := Cs.First_Element;
      return True;
   end Load;

   --  ---- Editing ----

   --  Whether A comes before B: by name, then detail, folded.
   function Before (An, Ad, Bn, Bd : Unbounded_String) return Boolean is
     (if Fold (An) = Fold (Bn) then Fold (Ad) < Fold (Bd) else Fold (An) < Fold (Bn));

   function New_Trait (It : Rules.Item; Of_Kind : Rules.Kind; Level : Integer;
                       Name, Detail : Unbounded_String) return not null Trait
   is
      T : constant Trait := new Trait_Record;
   begin
      Calc.Init_Trait (Calc.Trait (T), It, Of_Kind, Level);
      T.Name := (if It /= null then It.Name else Name);
      T.Has_Detail := Length (Detail) > 0;
      T.Detail := Detail;
      return T;
   end New_Trait;

   procedure Insert_Trait (List : in out Calc.Trait; T : not null Trait) is
      Prev : Calc.Trait := null;
      P    : Calc.Trait := List;
   begin
      while P /= null
        and then (P.Of_Kind < T.Of_Kind
                  or else (P.Of_Kind = T.Of_Kind
                           and then not Before (T.Name, T.Detail, Trait (P).Name, Trait (P).Detail)))
      loop
         Prev := P;
         P := P.Next;
      end loop;
      T.Next := P;
      if Prev = null then
         List := Calc.Trait (T);
      else
         Prev.Next := Calc.Trait (T);
      end if;
   end Insert_Trait;

   procedure Remove_Trait (List : in out Calc.Trait; T : not null Calc.Trait) is
      P : Calc.Trait;
   begin
      if List = T then
         List := T.Next;
      else
         P := List;
         while P /= null and then P.Next /= T loop
            P := P.Next;
         end loop;
         if P /= null then
            P.Next := T.Next;
         end if;
      end if;
      T.Next := null;
   end Remove_Trait;

   --  What linked content an item has: No_Link for none, or null.
   function Linked (It : Rules.Item) return Rules.Link is (if It = null then Rules.No_Link else It.Linked);

   procedure Change_Trait (List : in out Calc.Trait; T : not null Trait; It : Rules.Item;
                           Level : Integer; Detail : Unbounded_String) is
   begin
      Remove_Trait (List, Calc.Trait (T));
      if Linked (It) /= Linked (T.Item) then
         Calc.Free_Traits (T.Form);
         Calc.Free_Spells (T.Spells);
         Calc.Free (T.Partner);
      end if;
      if It /= T.Item then
         T.Item := It;
         if It /= null then
            T.Name := It.Name;
         end if;
         T.Has_Half_TV := False;
         T.Half_TV := It /= null and then Rules.Has (It, Rules.Half_TV);
      end if;
      T.Level := Level;
      T.Has_Detail := Length (Detail) > 0;
      T.Detail := Detail;
      Insert_Trait (List, T);
   end Change_Trait;

   function New_Partner (T : not null Trait) return not null Character_Access is
      C : Character_Access;
   begin
      if T.Item.Linked = Rules.Partner then
         C := New_Sheet (Calc.Companion_Sheet);
         C.Label := To_Unbounded_String ("Companion");
      else
         C := New_Sheet (Calc.Character_Sheet);
         C.Label := To_Unbounded_String ("Vehicle");
      end if;
      C.Name := (if T.Has_Detail then T.Detail else C.Label);
      return C;
   end New_Partner;

   function New_Spell (Name, Ability : Unbounded_String; It : Rules.Item; Level : Integer)
     return not null Spell
   is
      Sp : constant Spell := new Spell_Record;
   begin
      Calc.Init_Spell (Calc.Spell (Sp), It, Level);
      Sp.Name := Name;
      Sp.Ability := Ability;
      return Sp;
   end New_Spell;

   procedure Remove_Spell (T : not null Calc.Trait; Sp : not null Calc.Spell) is
      P : Calc.Spell;
   begin
      if T.Spells = Sp then
         T.Spells := Sp.Next;
      else
         P := T.Spells;
         while P /= null and then P.Next /= Sp loop
            P := P.Next;
         end loop;
         if P /= null then
            P.Next := Sp.Next;
         end if;
      end if;
      Sp.Next := null;
   end Remove_Spell;

   function New_Attack (Name : Unbounded_String) return not null Attack is
      A : constant Attack := new Attack_Record;
   begin
      Calc.Init_Attack (Calc.Attack (A));
      A.Name := Name;
      return A;
   end New_Attack;

   procedure Remove_Attack (C : not null Character_Access; A : not null Calc.Attack) is
      P : Calc.Attack;
   begin
      if C.Attacks = A then
         C.Attacks := A.Next;
      else
         P := C.Attacks;
         while P /= null and then P.Next /= A loop
            P := P.Next;
         end loop;
         if P /= null then
            P.Next := A.Next;
         end if;
      end if;
      A.Next := null;
   end Remove_Attack;

   function New_Modifier (It : not null Rules.Item; Is_Flaw : Boolean; Times, Cost : Integer)
     return not null Modifier
   is
      M : constant Modifier := new Modifier_Record;
   begin
      Calc.Init_Mod (Calc.Modifier (M), Rules.Item (It), Times, Cost);
      M.Name := It.Name;
      M.Is_Flaw := Is_Flaw;
      M.Has_Cost := It.Cost_Kind /= Rules.Fixed_Cost;
      return M;
   end New_Modifier;

   procedure Insert_Modifier (List : in out Calc.Modifier; M : not null Modifier) is
      Prev : Calc.Modifier := null;
      P    : Calc.Modifier := List;
   begin
      while P /= null
        and then ((not Modifier (P).Is_Flaw and then M.Is_Flaw)
                  or else (Modifier (P).Is_Flaw = M.Is_Flaw
                           and then not Before (M.Name, M.Detail, Modifier (P).Name, Modifier (P).Detail)))
      loop
         Prev := P;
         P := P.Next;
      end loop;
      M.Next := P;
      if Prev = null then
         List := Calc.Modifier (M);
      else
         Prev.Next := Calc.Modifier (M);
      end if;
   end Insert_Modifier;

   procedure Remove_Modifier (List : in out Calc.Modifier; M : not null Calc.Modifier) is
      P : Calc.Modifier;
   begin
      if List = M then
         List := M.Next;
      else
         P := List;
         while P /= null and then P.Next /= M loop
            P := P.Next;
         end loop;
         if P /= null then
            P.Next := M.Next;
         end if;
      end if;
      M.Next := null;
   end Remove_Modifier;

   function Copy_Modifiers (List : Calc.Modifier) return Calc.Modifier is
      First, Last : Calc.Modifier := null;
      L : Calc.Modifier := List;
      M : Modifier;
   begin
      while L /= null loop
         M := new Modifier_Record'(Modifier_Record (Modifier (L).all));
         M.Next := null;
         if Last = null then
            First := Calc.Modifier (M);
         else
            Last.Next := Calc.Modifier (M);
         end if;
         Last := Calc.Modifier (M);
         L := L.Next;
      end loop;
      return First;
   end Copy_Modifiers;

   procedure Set_Text (Has : out Boolean; Field : out Unbounded_String; Text : Unbounded_String) is
   begin
      Field := Text;
      Has := Length (Text) > 0;
   end Set_Text;

end Ova_Cg.Character;
