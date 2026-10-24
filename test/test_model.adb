--  Ova_Cg.Character's editing: what the window changes, and Endurance
--  Use.
--
--  ova_cg_po's PLAN.md, "The window": every change the window makes
--  goes through Ova_Cg.Character and then Recompute.  Here those
--  procedures alone: the order traits and mods are kept in, removing
--  and changing them, copying a list of mods, and each Endurance Use
--  tied to the Ability or attack its detail names, which counts in that
--  one's END, and survives a save and a load with no notice; the NPC
--  type, which sets the sheet's kind; an Ability's END of 0, not
--  written unless overridden.  Needs no display.

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Check;
with Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Rules;
with Ova_Cg.Save;
with Ova_Fmt.Entities;

procedure Test_Model is

   package Calc renames Ova_Cg.Calc;
   package Ch renames Ova_Cg.Character;
   package Rules renames Ova_Cg.Rules;
   package Save renames Ova_Cg.Save;
   package E renames Ova_Fmt.Entities;

   use type Calc.Modifier;
   use type Calc.Sheet_Kind;
   use type Rules.Item;
   use type E.NPC_Kind;

   Saved : constant String := "../obj/files/model.yaml";

   C, C2           : Ch.Character_Access;
   T, Tk, Fl, Usage  : Ch.Trait;
   A               : Ch.Attack;
   M, Perk, Flaw, Cancel : Ch.Modifier;
   Mods, Copy      : Calc.Modifier;
   Msg             : Unbounded_String;
   Ok              : Boolean;

   function R (S : String) return Unbounded_String renames To_Unbounded_String;

   function Item (Name : String) return Rules.Item is
      It : constant Rules.Item := Rules.Find (Name);
   begin
      pragma Assert (It /= null);
      return It;
   end Item;

   procedure Free (C : in out Ch.Character_Access) is
      S : Calc.Sheet := Calc.Sheet (C);
   begin
      Calc.Free (S);
      C := null;
   end Free;

   --  The traits' names and details, in order: "Flight; Telekinesis;
   --  Endurance Use (Gust)".
   function Traits (List : Calc.Trait) return String is
      use type Calc.Trait;
      S : Unbounded_String;
      X : Calc.Trait := List;
   begin
      while X /= null loop
         if S /= Null_Unbounded_String then
            Append (S, "; ");
         end if;
         Append (S, Ch.Trait (X).Name);
         if Ch.Trait (X).Has_Detail then
            Append (S, " (" & Ch.Trait (X).Detail & ")");
         end if;
         X := X.Next;
      end loop;
      return To_String (S);
   end Traits;

   function Mod_Names (List : Calc.Modifier) return String is
      S : Unbounded_String;
      X : Calc.Modifier := List;
   begin
      while X /= null loop
         if S /= Null_Unbounded_String then
            Append (S, "; ");
         end if;
         Append (S, Ch.Modifier (X).Name);
         X := X.Next;
      end loop;
      return To_String (S);
   end Mod_Names;

   function Has (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);

   procedure Is_Text (Got, Want, Label : String) is
   begin
      Check.Check (Got = Want, Label);
      if Got /= Want then
         Ada.Text_IO.Put_Line ("    got: " & Got);
      end if;
   end Is_Text;

begin
   --  ---- Traits: in the loader's order ----
   C := Ch.New_Character;
   C.Name := R ("Model");
   Usage := Ch.New_Trait (Item ("Endurance Use"), Rules.Weakness, -2, Null_Unbounded_String, R ("telekinesis"));
   Ch.Insert_Trait (C.Traits, Usage);
   Tk := Ch.New_Trait (Item ("Telekinesis"), Rules.Ability, 2, Null_Unbounded_String, Null_Unbounded_String);
   Ch.Insert_Trait (C.Traits, Tk);
   Fl := Ch.New_Trait (Item ("Flight"), Rules.Ability, 1, Null_Unbounded_String, Null_Unbounded_String);
   Ch.Insert_Trait (C.Traits, Fl);
   T := Ch.New_Trait (null, Rules.Ability, 1, R ("Zany Gadgets"), R ("b"));
   Ch.Insert_Trait (C.Traits, T);
   T := Ch.New_Trait (null, Rules.Ability, 1, R ("zany gadgets"), R ("A"));
   Ch.Insert_Trait (C.Traits, T);
   Is_Text (Traits (C.Traits),
            "Flight; Telekinesis; zany gadgets (A); Zany Gadgets (b); Endurance Use (telekinesis)",
            "InsertTrait: Abilities before Weaknesses, each by name, then detail, ignoring case");
   Ch.Remove_Trait (C.Traits, Calc.Trait (T));
   declare
      X : Calc.Trait := Calc.Trait (T);
   begin
      Calc.Free_Traits (X);
   end;
   Is_Text (Traits (C.Traits), "Flight; Telekinesis; Zany Gadgets (b); Endurance Use (telekinesis)",
            "RemoveTrait");
   Ch.Change_Trait (C.Traits, Fl, Item ("Telekinesis"), 3, R ("small things"));
   Is_Text (Traits (C.Traits),
            "Telekinesis; Telekinesis (small things); Zany Gadgets (b); Endurance Use (telekinesis)",
            "ChangeTrait: renamed and moved to its new place");
   Check.Check (Fl.Item = Item ("Telekinesis") and then Fl.Level = 3, "ChangeTrait: the item and level");
   Ch.Change_Trait (C.Traits, Fl, Item ("Flight"), 1, Null_Unbounded_String);
   Check.Check (not Fl.Has_Detail and then Fl.Detail = Null_Unbounded_String, "ChangeTrait: a detail removed");

   --  ---- Endurance Use ----
   Ch.Recompute (C);
   Check.Check (Tk.Has_End and then Calc.Value (Tk.End_Cost) = 10,
                "Endurance Use -2 ties to the Ability its detail names: END 10");
   Check.Check (not Fl.Has_End, "and to no other");
   Ch.Change_Trait (C.Traits, Usage, Usage.Item, -1, R ("Telekinesis (x)"));
   Ch.Recompute (C);
   Check.Check (not Tk.Has_End, "a detail naming nothing ties to nothing");
   Ch.Change_Trait (C.Traits, Tk, Tk.Item, 2, R ("x"));
   Ch.Recompute (C);
   Check.Check (Tk.Has_End and then Calc.Value (Tk.End_Cost) = 5,
                "a detail naming an Ability and its detail: Endurance Use -1, END 5");
   A := Ch.New_Attack (R ("Gust"));
   Calc.Add_Attack (Calc.Sheet (C), Calc.Attack (A));
   Perk := Ch.New_Modifier (Item ("Accurate"), False, 1, 0);
   Ch.Insert_Modifier (A.Mods, Perk);
   Ch.Change_Trait (C.Traits, Usage, Usage.Item, -1, R ("gust"));
   Ch.Recompute (C);
   Check.Check (not Tk.Has_End and then Calc.Value (A.End_Cost) = 10,
                "else the attack it names: Accurate's 5 and Endurance Use's 5");
   Ch.Change_Trait (C.Traits, Usage, Usage.Item, -1, R ("telekinesis (x)"));

   --  ---- Saved and loaded ----
   Ch.Recompute (C);
   Ok := Save.Save (C, Saved, Msg);
   Check.Check (Ok, "saved");
   Ok := Ch.Load (Saved, C2, Msg);
   Check.Check (Ok and then Ch.Notices.Is_Empty, "loaded again with no notices: the END it wrote is the rules'");
   Check.Check (Ok and then Save.To_Text (C2) = Save.To_Text (C), "and it saves the same");
   if Ok then
      Free (C2);
   end if;

   --  ---- Mods ----
   Mods := null;
   Flaw := Ch.New_Modifier (Item ("Requirement"), True, 1, -10);
   Ch.Insert_Modifier (Mods, Flaw);
   Perk := Ch.New_Modifier (Item ("Ranged"), False, 1, 0);
   Ch.Insert_Modifier (Mods, Perk);
   Cancel := Ch.New_Modifier (Item ("Cancel"), True, 1, -15);
   Ch.Insert_Modifier (Mods, Cancel);
   M := Ch.New_Modifier (Item ("Accurate"), False, 2, 0);
   Ch.Insert_Modifier (Mods, M);
   Is_Text (Mod_Names (Mods), "Accurate; Ranged; Cancel; Requirement", "InsertMod: Perks before Flaws, each by name");
   Check.Check (Cancel.Has_Cost and then Cancel.Cost = -15 and then not M.Has_Cost,
                "NewMod: a chosen cost is written, a fixed one isn't");
   Copy := Ch.Copy_Modifiers (Mods);
   Ch.Remove_Modifier (Mods, Calc.Modifier (Perk));
   declare
      X : Calc.Modifier := Calc.Modifier (Perk);
   begin
      Calc.Free_Mods (X);
   end;
   M.Times := 3;
   Is_Text (Mod_Names (Mods), "Accurate; Cancel; Requirement", "RemoveMod");
   Is_Text (Mod_Names (Copy), "Accurate; Ranged; Cancel; Requirement", "CopyMods: a copy the list's changes don't reach");
   Check.Check (Copy /= Calc.Modifier (M) and then Copy.Times = 2, "CopyMods: each mod copied");
   Calc.Free_Mods (Mods);
   Calc.Free_Mods (Copy);
   Free (C);

   --  ---- The NPC type (p. 123-124) ----
   C := Ch.New_Character;
   C.Name := R ("Typed");
   Ch.Insert_Trait (C.Traits, Ch.New_Trait (Item ("Tough"), Rules.Ability, 1, Null_Unbounded_String,
                                            Null_Unbounded_String));
   Ch.Recompute (C);
   Check.Check (not C.Has_NPC_Type and then C.Of_Kind = Calc.Character_Sheet and then Calc.Value (C.Health) = 50,
                "no NPC type: a character's sheet, HEALTH 40 + Tough 1");
   Ch.Set_NPC_Type (C, True, E.Secondary);
   Ch.Recompute (C);
   Check.Check (C.Of_Kind = Calc.Companion_Sheet and then Calc.Value (C.Health) = 30
                and then Calc.Value (C.Endurance) = 20,
                "Secondary: a Companion's sheet, HEALTH 20 + Tough 1, ENDURANCE 20");
   Ch.Set_NPC_Type (C, True, E.Extra);
   Ch.Recompute (C);
   Check.Check (C.Of_Kind = Calc.Extra_Sheet and then Calc.Value (C.Health) = 20 and then Calc.Value (C.TV) = 1,
                "Extra: HEALTH 10 + Tough 1, TV 1");
   Ch.Set_NPC_Type (C, True, E.Heroic);
   Ch.Recompute (C);
   Check.Check (C.Of_Kind = Calc.Character_Sheet and then Calc.Value (C.Health) = 50, "Heroic: a character's sheet");
   Ch.Set_NPC_Type (C, True, E.Secondary);
   C.Has_Character_Hooks := True;
   C.Character_Hooks := R ("Hooks.");
   Ch.Recompute (C);
   Check.Check (Has (Save.To_Text (C), "npc-type: Secondary") and then Has (Save.To_Text (C), "character-hooks: Hooks."),
                "the type and the hooks saved");
   Ok := Save.Save (C, Saved, Msg) and then Ch.Load (Saved, C2, Msg);
   Check.Check (Ok and then Ch.Notices.Is_Empty and then C2.Has_NPC_Type and then C2.NPC_Type = E.Secondary
                and then C2.Of_Kind = Calc.Companion_Sheet and then C2.Character_Hooks = "Hooks.",
                "loaded again: the type, so the sheet's kind, and the hooks; no notices");
   if Ok then
      Free (C2);
   end if;
   Ch.Set_NPC_Type (C, False, E.Heroic);
   Ch.Recompute (C);
   Check.Check (not C.Has_NPC_Type and then C.Of_Kind = Calc.Character_Sheet
                and then not Has (Save.To_Text (C), "npc-type"),
                "the type taken off: a character's sheet, nothing saved");
   Free (C);

   --  ---- An Ability's END of 0 ----
   C := Ch.New_Character;
   C.Name := R ("Free");
   C.Has_Combat := False;
   T := Ch.New_Trait (Item ("Attack"), Rules.Ability, 3, Null_Unbounded_String, Null_Unbounded_String);
   Ch.Insert_Modifier (T.Mods, Ch.New_Modifier (Item ("Armor Piercing"), False, 1, 0));
   Ch.Insert_Modifier (T.Mods, Ch.New_Modifier (Item ("Ranged"), False, 1, 0));
   Ch.Insert_Modifier (T.Mods, Ch.New_Modifier (Item ("Ineffective"), True, 1, 0));
   Ch.Insert_Modifier (T.Mods, Ch.New_Modifier (Item ("Weapon"), True, 1, 0));
   Ch.Insert_Trait (C.Traits, T);
   Ch.Recompute (C);
   Check.Check (T.Has_End and then Calc.Value (T.End_Cost) = 0, "Perks and Flaws costing nothing: END 0");
   Check.Check (not Has (Save.To_Text (C), "endurance"), "an END of 0 isn't written");
   Calc.Override (T.End_Cost, 0, False, False);
   Check.Check (Has (Save.To_Text (C), "endurance: 0"), "unless it is an override");
   Calc.Clear (T.End_Cost);
   Calc.Override (T.End_Cost, 5, False, False);
   Check.Check (Has (Save.To_Text (C), "endurance: 5"), "an override of 5 is");
   Free (C);

   Check.Summary;
end Test_Model;
