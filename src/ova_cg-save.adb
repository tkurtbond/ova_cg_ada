with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Interfaces.C;
with Interfaces.C.Strings;
with Libfyaml.Documents.Styled;
with Libfyaml.Nodes;
with Ova_Cg.Calc;
with Ova_Cg.Rules;

package body Ova_Cg.Save is

   package Documents renames Libfyaml.Documents;
   package Styled renames Libfyaml.Documents.Styled;
   package Nodes renames Libfyaml.Nodes;
   package E renames Ova_Fmt.Entities;
   package Ch renames Ova_Cg.Character;

   use type Calc.Trait;
   use type Calc.Modifier;
   use type Calc.Spell;
   use type Calc.Attack;
   use type Calc.Sheet;
   use type Rules.Kind;
   use type E.Override_Set;

   subtype Node is Nodes.Node;
   subtype Document is Documents.Document;

   function Fluff_Key (F : Ch.Fluff_Field) return String is
     (case F is
         when Ch.Concept => "concept", when Ch.Birthday => "birthday", when Ch.Age => "age",
         when Ch.Gender => "gender", when Ch.Height => "height", when Ch.Weight => "weight",
         when Ch.Hair => "hair", when Ch.Eyes => "eyes", when Ch.Association => "association",
         when Ch.Hobbies => "hobbies", when Ch.Favorite_Food => "favorite-food",
         when Ch.Allies => "allies", when Ch.Enemies => "enemies",
         when Ch.Love_Interests => "love-interests");

   --  ---- Scalars ----

   function Text (D : in out Document; S : Unbounded_String) return Node is
     (if Index (S, [1 => ASCII.LF]) > 0
      then Styled.Create_Styled_Scalar (D, To_String (S), Styled.Literal)
      else Styled.Create_Styled_Scalar (D, To_String (S), Styled.Plain));

   function Int (D : in out Document; I : Integer) return Node is
     (D.Create_Scalar (Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Left)));

   function Bool (D : in out Document; B : Boolean) return Node is
     (D.Create_Scalar (if B then "true" else "false"));

   --  N in effect: "4", "1/2", "10+".
   function Num (D : in out Document; N : Calc.Number) return Node is
     (Styled.Create_Styled_Scalar (D, Calc.Text (N), Styled.Plain));

   --  ---- Mappings ----

   procedure Pair (D : in out Document; M : Node; Key : String; V : Node) is
   begin
      Nodes.Append_Pair (M, D.Create_Scalar (Key), V);
   end Pair;

   --  Adds K to Set if N is overridden.
   procedure Over (Set : in out E.Override_Set; K : E.Override_Key; N : Calc.Number) is
   begin
      if Calc.Overridden (N) then
         Set (K) := True;
      end if;
   end Over;

   --  "overrides: [...]", the keys in Set in Ova_Fmt.Entities' order, if
   --  any.
   procedure Overrides (D : in out Document; M : Node; Set : E.Override_Set) is
      Seq : Node;
   begin
      if Set = E.No_Overrides then
         return;
      end if;
      Seq := D.Create_Sequence;
      for K in Set'Range loop
         if Set (K) then
            Nodes.Append (Seq, D.Create_Scalar (E.Key_Name (K)));
         end if;
      end loop;
      Pair (D, M, "overrides", Seq);
   end Overrides;

   procedure Text_Pair (D : in out Document; M : Node; Key : String; Has : Boolean;
                        S : Unbounded_String) is
   begin
      if Has then
         Pair (D, M, Key, Text (D, S));
      end if;
   end Text_Pair;

   --  ---- Perks and Flaws ----

   --  A plain name, as the fixtures write most; a mapping when it has a
   --  detail, a count or a cost to say.
   function Mod_Node (D : in out Document; X : not null Calc.Modifier) return Node is
      M : constant Ch.Modifier := Ch.Modifier (X);
      N : Node;
   begin
      if not M.Has_Detail and then M.Times = 1 and then not M.Has_Cost then
         return Text (D, M.Name);
      end if;
      N := D.Create_Mapping;
      Pair (D, N, "name", Text (D, M.Name));
      Text_Pair (D, N, "detail", M.Has_Detail, M.Detail);
      if M.Times /= 1 then
         Pair (D, N, "counts-as", Int (D, M.Times));
      end if;
      if M.Has_Cost then
         Pair (D, N, "cost", Int (D, M.Cost));
      end if;
      return N;
   end Mod_Node;

   --  The Perks (Flaws False) or Flaws of List, under Key, if any.
   procedure Mods (D : in out Document; M : Node; Key : String; List : Calc.Modifier;
                   Flaws : Boolean) is
      Seq : Node := Nodes.Null_Node;
      X   : Calc.Modifier := List;
   begin
      while X /= null loop
         if Ch.Modifier (X).Is_Flaw = Flaws then
            if not Nodes.Is_Valid (Seq) then
               Seq := D.Create_Sequence;
            end if;
            Nodes.Append (Seq, Mod_Node (D, X));
         end if;
         X := X.Next;
      end loop;
      if Nodes.Is_Valid (Seq) then
         Pair (D, M, Key, Seq);
      end if;
   end Mods;

   --  ---- Traits ----

   function Partner (D : in out Document; C : not null Ch.Character_Access) return Node;

   function Trait_Node (D : in out Document; X : not null Calc.Trait) return Node;

   --  The Traits of List of kind Of_Kind, under Key, if any.
   procedure Traits (D : in out Document; M : Node; Key : String; List : Calc.Trait;
                     Of_Kind : Rules.Kind) is
      Seq : Node := Nodes.Null_Node;
      T   : Calc.Trait := List;
   begin
      while T /= null loop
         if T.Of_Kind = Of_Kind then
            if not Nodes.Is_Valid (Seq) then
               Seq := D.Create_Sequence;
            end if;
            Nodes.Append (Seq, Trait_Node (D, T));
         end if;
         T := T.Next;
      end loop;
      if Nodes.Is_Valid (Seq) then
         Pair (D, M, Key, Seq);
      end if;
   end Traits;

   function Trait_Node (D : in out Document; X : not null Calc.Trait) return Node is
      T   : constant Ch.Trait := Ch.Trait (X);
      N   : constant Node := D.Create_Mapping;
      Seq : Node;
      Sp  : Calc.Spell;
      Set : E.Override_Set;
   begin
      Pair (D, N, "name", Text (D, T.Name));
      Pair (D, N, "level", Int (D, T.Level));
      Text_Pair (D, N, "detail", T.Has_Detail, T.Detail);
      Mods (D, N, "perks", T.Mods, False);
      Mods (D, N, "flaws", T.Mods, True);
      --  An END of 0 isn't written, as the fixtures don't write one; an
      --  override always is.
      if (T.Has_End and then Calc.Value (T.End_Cost) /= 0) or else Calc.Overridden (T.End_Cost) then
         Pair (D, N, "endurance", Num (D, T.End_Cost));
      end if;
      Text_Pair (D, N, "note", T.Has_Note, T.Note);
      if T.Has_Half_TV then
         Pair (D, N, "threat-value-half", Bool (D, T.Half_TV));
      end if;
      Set := E.No_Overrides;
      Over (Set, E.Endurance, T.End_Cost);
      Overrides (D, N, Set);
      if T.Form /= null then
         Traits (D, N, "abilities", T.Form, Rules.Ability);
         Traits (D, N, "weaknesses", T.Form, Rules.Weakness);
      end if;
      if T.Spells /= null then
         Seq := D.Create_Sequence;
         Sp := T.Spells;
         while Sp /= null loop
            declare
               S  : constant Ch.Spell := Ch.Spell (Sp);
               SN : constant Node := D.Create_Mapping;
            begin
               Pair (D, SN, "name", Text (D, S.Name));
               Pair (D, SN, "ability", Text (D, S.Ability));
               Pair (D, SN, "level", Int (D, S.Level));
               Pair (D, SN, "endurance", Num (D, S.End_Cost));
               Set := E.No_Overrides;
               Over (Set, E.Endurance, S.End_Cost);
               Overrides (D, SN, Set);
               Nodes.Append (Seq, SN);
            end;
            Sp := Sp.Next;
         end loop;
         Pair (D, N, "spells", Seq);
      end if;
      if T.Partner /= null then
         declare
            P : constant Ch.Character_Access := Ch.Character_Access (T.Partner);
         begin
            --  "companion" or "vehicle"
            Pair (D, N, Ada.Characters.Handling.To_Lower (To_String (P.Label)), Partner (D, P));
         end;
      end if;
      return N;
   end Trait_Node;

   --  ---- Combat ----

   --  Adds N's text to Def, after a slash if After, and K to Set if N
   --  is overridden.
   procedure Add_Defense (Def : in out Unbounded_String; After : Boolean;
                          Set : in out E.Override_Set; K : E.Override_Key; N : Calc.Number) is
   begin
      if After then
         Append (Def, '/');
      end if;
      Append (Def, Calc.Text (N));
      Over (Set, K, N);
   end Add_Defense;

   --  C's defense and its overrides: the best value alone
   --  (Single_Defense), or the Defense, then Barrier's, then Incorporeal
   --  Form's, each that C has or that is overridden.  Barrier's is
   --  written before an overridden Incorporeal Form's that C doesn't
   --  have, which a second value alone would be read as
   --  (Ova_Cg.Character's Adopt_Defenses).
   procedure Defenses (C : not null Ch.Character_Access; Def : out Unbounded_String;
                       Set : in out E.Override_Set) is
      K     : E.Override_Key;
      Which : Ch.Slot;
   begin
      Def := Null_Unbounded_String;
      if Ch.Single_Defense (C, Which) then
         case Which is
            when Ch.Defense_Slot => Add_Defense (Def, False, Set, E.Defense, C.Defense);
            when Ch.Barrier_Slot => Add_Defense (Def, False, Set, E.Defense, C.Barrier);
            when Ch.Incorporeal_Slot => Add_Defense (Def, False, Set, E.Defense, C.Incorporeal);
         end case;
      else
         Add_Defense (Def, False, Set, E.Defense, C.Defense);
         K := E.Defense_2;
         if C.Has_Barrier or else Calc.Overridden (C.Barrier)
           or else (Calc.Overridden (C.Incorporeal) and then not C.Has_Incorporeal)
         then
            Add_Defense (Def, True, Set, K, C.Barrier);
            K := E.Defense_3;
         end if;
         if C.Has_Incorporeal or else Calc.Overridden (C.Incorporeal) then
            Add_Defense (Def, True, Set, K, C.Incorporeal);
         end if;
      end if;
   end Defenses;

   procedure Combat (D : in out Document; M : Node; C : not null Ch.Character_Access) is
      N   : Node;
      Seq : Node;
      X   : Calc.Attack;
      Def : Unbounded_String;
      Set : E.Override_Set := E.No_Overrides;
   begin
      if not C.Has_Combat then
         return;
      end if;
      N := D.Create_Mapping;
      Defenses (C, Def, Set);
      Pair (D, N, "defense", Styled.Create_Styled_Scalar (D, To_String (Def), Styled.Plain));
      Pair (D, N, "health", Num (D, C.Health));
      Pair (D, N, "endurance", Num (D, C.Endurance));
      if C.Has_Threat_Value then
         Pair (D, N, "threat-value", Num (D, C.TV));
      end if;
      if C.Transformed then
         Pair (D, N, "transformed", Bool (D, True));
      end if;
      Over (Set, E.Health, C.Health);
      Over (Set, E.Endurance, C.Endurance);
      if C.Has_Threat_Value then
         Over (Set, E.Threat_Value, C.TV);
      end if;
      Overrides (D, N, Set);
      Text_Pair (D, N, "notes", C.Has_Combat_Notes, C.Combat_Notes);
      if C.Attacks /= null then
         Seq := D.Create_Sequence;
         X := C.Attacks;
         while X /= null loop
            declare
               A  : constant Ch.Attack := Ch.Attack (X);
               AN : constant Node := D.Create_Mapping;
            begin
               Pair (D, AN, "name", Text (D, A.Name));
               Mods (D, AN, "perks", A.Mods, False);
               Text_Pair (D, AN, "affinity", A.Has_Affinity, A.Affinity);
               Mods (D, AN, "flaws", A.Mods, True);
               Text_Pair (D, AN, "description", A.Has_Description, A.Description);
               Pair (D, AN, "roll", Num (D, A.Roll));
               Pair (D, AN, "dx", Num (D, A.DX));
               Pair (D, AN, "endurance", Num (D, A.End_Cost));
               if A.Telekinetic then
                  Pair (D, AN, "telekinesis", Bool (D, True));
               end if;
               if A.Transformed then
                  Pair (D, AN, "transformed", Bool (D, True));
               end if;
               Set := E.No_Overrides;
               Over (Set, E.Roll, A.Roll);
               Over (Set, E.Dx, A.DX);
               Over (Set, E.Endurance, A.End_Cost);
               Overrides (D, AN, Set);
               Nodes.Append (Seq, AN);
            end;
            X := X.Next;
         end loop;
         Pair (D, N, "attacks", Seq);
      end if;
      Pair (D, M, "combat", N);
   end Combat;

   --  ---- Entities ----

   --  A Companion's or Vehicle's mapping.
   function Partner (D : in out Document; C : not null Ch.Character_Access) return Node is
      M : constant Node := D.Create_Mapping;
   begin
      Pair (D, M, "name", Text (D, C.Name));
      if C.Is_Fragment then
         Pair (D, M, "fragment", Bool (D, True));
      end if;
      Traits (D, M, "abilities", C.Traits, Rules.Ability);
      Traits (D, M, "weaknesses", C.Traits, Rules.Weakness);
      Combat (D, M, C);
      return M;
   end Partner;

   function Entity (D : in out Document; C : not null Ch.Character_Access) return Node is
      M : constant Node := D.Create_Mapping;
   begin
      Pair (D, M, "name", Text (D, C.Name));
      if C.Is_Fragment then
         Pair (D, M, "fragment", Bool (D, True));
      end if;
      if C.Has_NPC_Type then
         Pair (D, M, "npc-type", Text (D, To_Unbounded_String (E.NPC_Kind_Name (C.NPC_Type))));
      end if;
      Text_Pair (D, M, "player", C.Has_Player, C.Player);
      Text_Pair (D, M, "portrait", C.Has_Portrait, C.Portrait);
      Text_Pair (D, M, "tagline", C.Has_Tagline, C.Tagline);
      Text_Pair (D, M, "summary", C.Has_Summary, C.Summary);
      Text_Pair (D, M, "background", C.Has_Background, C.Background);
      Text_Pair (D, M, "appearance", C.Has_Appearance, C.Appearance);
      Text_Pair (D, M, "personality", C.Has_Personality, C.Personality);
      Text_Pair (D, M, "character-hooks", C.Has_Character_Hooks, C.Character_Hooks);
      Text_Pair (D, M, "other-notes", C.Has_Other_Notes, C.Other_Notes);
      if C.Has_Options then
         declare
            O  : constant Node := D.Create_Mapping;
            Op : Calc.Options_Record renames C.Options;
         begin
            if Op.Base_Zero then
               Pair (D, O, "base-zero", Int (D, Op.Base_Zero_Range));
            end if;
            if Op.Power_Ceiling then
               Pair (D, O, "power-ceiling", Int (D, Op.Ceiling));
            end if;
            if Op.Starting_Levels then
               Pair (D, O, "starting-levels", Int (D, Op.Starting));
            end if;
            if Op.Scaled_Cost then
               Pair (D, O, "scaled-cost", Bool (D, True));
            end if;
            if Op.Half_Cost_Knowledge then
               Pair (D, O, "half-cost-knowledge", Bool (D, True));
            end if;
            if Op.Combined_Effectiveness then
               Pair (D, O, "combined-effectiveness", Bool (D, True));
            end if;
            Pair (D, M, "options", O);
         end;
      end if;
      Traits (D, M, "abilities", C.Traits, Rules.Ability);
      Traits (D, M, "weaknesses", C.Traits, Rules.Weakness);
      Combat (D, M, C);
      if not C.Notes.Is_Empty then
         declare
            Seq : constant Node := D.Create_Sequence;
         begin
            for Note of C.Notes loop
               declare
                  N : constant Node := D.Create_Mapping;
               begin
                  Pair (D, N, "header", Text (D, Note.Header));
                  Pair (D, N, "text", Text (D, Note.Text));
                  Nodes.Append (Seq, N);
               end;
            end loop;
            Pair (D, M, "notes", Seq);
         end;
      end if;
      if C.Has_Fluff then
         declare
            F : constant Node := D.Create_Mapping;
         begin
            for I in Ch.Fluff_Field loop
               if C.Has_Fluff_Field (I) then
                  Pair (D, F, Fluff_Key (I), Text (D, C.Fluff (I)));
               end if;
            end loop;
            Pair (D, M, "fluff", F);
         end;
      end if;
      return M;
   end Entity;

   --  Builds into D, a new document, the characters Cs, in order.
   --  Program_Error if building it failed (a duplicate key: a
   --  programmer's error, never the user's).
   procedure Build (D : in out Document; Cs : Ch.Characters) is
      Root : constant Node := D.Create_Sequence;
   begin
      D.Set_Root (Root);
      for C of Cs loop
         Nodes.Append (Root, Entity (D, C));
      end loop;
   end Build;

   --  An empty document: alibfyaml has no constructor for one, so "[]"
   --  parsed, its root replaced by Build.
   function New_Document return Document is (Documents.Parse_String ("[]"));

   --  libfyaml's FYECF_MODE_BLOCK, FYECF_MODE (1): the mode field
   --  starts at bit 20.  alibfyaml's Emit_Mode_Block is 1 at bit 8,
   --  which is libfyaml's indent field, so it asks for the original
   --  mode, indented by one (PLAN.md, "Findings").
   Flags : constant Documents.Emit_Flags := 16#10_0000#;

   function All_To_Text (Cs : Ch.Characters) return String is
      D : Document := New_Document;
   begin
      Build (D, Cs);
      return D.To_YAML (Flags);
   end All_To_Text;

   function To_Text (C : not null Ch.Character_Access) return String is
     (All_To_Text (Ch.One (C)));

   --  C's: Ada.Directories.Rename raises Use_Error where To exists.
   function C_Rename (From, To : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "rename";

   function Save_All (Cs : Ch.Characters; Path : String; Msg : out Unbounded_String)
     return Boolean
   is
      use type Interfaces.C.int;
      package CStr renames Interfaces.C.Strings;
      Tmp : constant String := Path & ".tmp";
   begin
      Msg := Null_Unbounded_String;
      declare
         D : Document := New_Document;
      begin
         Build (D, Cs);
         D.Write_To_File (Tmp, Flags);
      exception
         when Program_Error =>
            Msg := To_Unbounded_String ("the characters' YAML couldn't be built (a duplicate key)");
            return False;
         when Libfyaml.Emit_Error =>
            Msg := To_Unbounded_String
              ("couldn't write " & Tmp & ": " & GNAT.OS_Lib.Errno_Message);
            if Ada.Directories.Exists (Tmp) then
               Ada.Directories.Delete_File (Tmp);
            end if;
            return False;
      end;
      declare
         From : CStr.chars_ptr := CStr.New_String (Tmp);
         To   : CStr.chars_ptr := CStr.New_String (Path);
         Rc   : constant Interfaces.C.int := C_Rename (From, To);
      begin
         CStr.Free (From);
         CStr.Free (To);
         if Rc /= 0 then
            Msg := To_Unbounded_String
              ("couldn't replace " & Path & " with " & Tmp & ": " & GNAT.OS_Lib.Errno_Message);
            return False;
         end if;
      end;
      return True;
   end Save_All;

   function Save (C : not null Ch.Character_Access; Path : String;
                  Msg : out Unbounded_String) return Boolean is
     (Save_All (Ch.One (C), Path, Msg));

   function To_Entity (C : not null Ch.Character_Access; E : out Ova_Fmt.Entities.Entity)
     return Boolean
   is
      D : Document := New_Document;
   begin
      Build (D, Ch.One (C));
      Ova_Fmt.Entities.Reset_Errors;
      E := Ova_Fmt.Entities.Load_Entity (Nodes.Item (D.Root, 1));
      if Ova_Fmt.Entities.Error_Count /= 0 then
         Ch.Free_Entity (E);
         return False;
      end if;
      return True;
   exception
      when Program_Error | Ova_Fmt.Entities.Shape_Error | Libfyaml.Missing_Key | Libfyaml.Data_Error =>
         return False;
   end To_Entity;

   function Copy (C : not null Ch.Character_Access) return Ch.Character_Access is
      X : Ova_Fmt.Entities.Entity;
   begin
      if not To_Entity (C, X) then
         return null;
      end if;
      return R : constant Ch.Character_Access := Ch.From_Entity (X) do
         Ch.Free_Entity (X);
      end return;
   end Copy;

end Ova_Cg.Save;
