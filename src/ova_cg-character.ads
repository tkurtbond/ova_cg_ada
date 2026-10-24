--  The character being built: Ova_Cg.Calc's sheet, with its names and
--  text.
--
--  ova_cg_po's PLAN.md, "Files" and "Modules".  A Character is an
--  Ova_Cg.Calc sheet, its Traits, Modifiers, Attacks and Spells extended
--  with what Ova_Cg.Calc doesn't need: names, details, notes,
--  descriptions, the background and the fluff, and the flags saying
--  which optional keys a file had, so that a file loaded and saved
--  formats the same in ova_fmt.  Text that is absent is "", with its
--  Has_ flag False.
--
--  A file is read by Ova_Fmt.Entities, ova_fmt's loader, so the
--  generator reads exactly what ova_fmt reads, and then built into a
--  Character.  A number the file's overrides: key lists is an override.
--  Every other number the file holds is compared with the one
--  Ova_Cg.Calc computes; one that differs is kept as an override too,
--  with a notice saying so: the file is the user's (a GM's ruling, a
--  hand edit, or a case the rules here don't cover), and nothing in it
--  is lost.
--
--  Characters are freed with Ova_Cg.Calc.Free (or Free_All), which
--  frees their extensions too.
--
--  Uses nothing of the window, so its tests need no display.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ova_Cg.Calc;
with Ova_Cg.Rules;
with Ova_Fmt.Entities;

package Ova_Cg.Character is

   --  The fluff: block's fields, in the order the file holds them.
   type Fluff_Field is
     (Concept, Birthday, Age, Gender, Height, Weight, Hair, Eyes, Association, Hobbies,
      Favorite_Food, Allies, Enemies, Love_Interests);

   type Fluff_Flags is array (Fluff_Field) of Boolean;
   type Fluff_Texts is array (Fluff_Field) of Unbounded_String;

   --  The Defense values, in the order a combat: block's defense holds
   --  them (Best_Defense).
   type Slot is (Defense_Slot, Barrier_Slot, Incorporeal_Slot);

   type Character_Record is new Calc.Sheet_Record with record
      Label : Unbounded_String;  --  a partner's sheet: "Companion" or "Vehicle"; "" for the character
      Name  : Unbounded_String;
      Has_Player, Has_Portrait : Boolean := False;
      Player, Portrait         : Unbounded_String;  --  Portrait: the image's path, relative to the file
      Has_Tagline, Has_Summary, Has_Background, Has_Appearance, Has_Personality,
      Has_Character_Hooks, Has_Other_Notes : Boolean := False;
      Tagline, Summary, Background, Appearance, Personality, Character_Hooks,
      Other_Notes : Unbounded_String;
      --  npc-type:; it sets the sheet's kind.  Set them with Set_NPC_Type.
      Has_NPC_Type : Boolean := False;
      NPC_Type     : Ova_Fmt.Entities.NPC_Kind := Ova_Fmt.Entities.Heroic;
      Notes        : Ova_Fmt.Entities.Note_Vectors.Vector;
      Has_Fluff    : Boolean := False;
      Has_Fluff_Field : Fluff_Flags := [others => False];
      Fluff        : Fluff_Texts;
      Has_Options  : Boolean := False;  --  an options: block, even an empty one
      Is_Fragment  : Boolean := False;  --  an NPC Fragment, or a simple Companion
      Has_Combat   : Boolean := True;   --  a combat: block: a Fragment or Companion may have none
      Has_Threat_Value : Boolean := True;
      --  The file gave one Defense though Barrier or Incorporeal Form
      --  gives another, as the book's Sample NPCs have it: the best,
      --  saved so, the others left out (Single_Defense).  Single_Slot,
      --  the slot it was read into, Best_Defense's then; for
      --  Single_Defense alone.
      Omit_Alternates  : Boolean := False;
      Single_Slot      : Slot := Defense_Slot;
      Has_Combat_Notes : Boolean := False;
      Combat_Notes     : Unbounded_String;
   end record;

   type Character_Access is access all Character_Record'Class;

   --  An Ability or Weakness.
   type Trait_Record is new Calc.Trait_Record with record
      Name        : Unbounded_String;
      Has_Detail  : Boolean := False;
      Detail      : Unbounded_String;
      Has_Note    : Boolean := False;
      Note        : Unbounded_String;
      Has_Half_TV : Boolean := False;  --  Half_TV is written: threat-value-half; else the rules'
   end record;

   type Trait is access all Trait_Record'Class;

   --  A Perk or Flaw.
   type Modifier_Record is new Calc.Modifier_Record with record
      Name       : Unbounded_String;
      Has_Detail : Boolean := False;
      Detail     : Unbounded_String;
      Is_Flaw    : Boolean := False;  --  which list it is in, whether or not Ova_Cg.Rules has it
      Has_Cost   : Boolean := False;  --  its cost is written: chosen (Cancel, Requirement, Unique), or the file's
   end record;

   type Modifier is access all Modifier_Record'Class;

   type Attack_Record is new Calc.Attack_Record with record
      Name            : Unbounded_String;
      Has_Affinity    : Boolean := False;
      Affinity        : Unbounded_String;
      Has_Description : Boolean := False;
      Description     : Unbounded_String;
   end record;

   type Attack is access all Attack_Record'Class;

   type Spell_Record is new Calc.Spell_Record with record
      Name, Ability : Unbounded_String;
   end record;

   type Spell is access all Spell_Record'Class;

   --  A file's characters, in its order.
   package Character_Vectors is new Ada.Containers.Vectors (Positive, Character_Access);
   subtype Characters is Character_Vectors.Vector;

   package Text_Vectors is new Ada.Containers.Vectors (Positive, Unbounded_String);

   --  What the last Load or Load_All found to say about the file: each
   --  number kept as an override.
   function Notices return Text_Vectors.Vector;

   --  Frees every character of Cs, and empties it.
   procedure Free_All (Cs : in out Characters);

   --  ---- Building ----

   --  Every number of C computed again, after a change: what
   --  Ova_Cg.Calc.Compute does, with each Endurance Use tied first to
   --  the Ability or attack its detail names.
   procedure Recompute (C : not null Character_Access);

   --  Sets C's NPC type (Has False: none), and so its sheet's kind:
   --  Recompute after.
   procedure Set_NPC_Type (C : not null Character_Access; Has : Boolean;
                           NPC_Type : Ova_Fmt.Entities.NPC_Kind);

   --  A new, empty character.
   function New_Character return not null Character_Access;

   --  E's character, every number computed, none overridden: its
   --  Abilities, then its Weaknesses, each in E's (sorted) order, its
   --  attacks in the file's.
   function Build (E : Ova_Fmt.Entities.Entity) return not null Character_Access;

   --  The character of entity E, its numbers E's: each its mapping's
   --  overrides: lists is an override, and each other that differs from
   --  the rules' is kept as one too, added to Notices.
   function From_Entity (E : Ova_Fmt.Entities.Entity) return not null Character_Access;

   --  Frees what Ova_Fmt.Entities allocated for E (its Abilities'
   --  companions and vehicles).
   procedure Free_Entity (E : in out Ova_Fmt.Entities.Entity);

   --  ---- The file's numbers ----

   --  C's best Defense value, its slot: the Defense, or an alternate C
   --  has that is higher than those before it.
   function Best_Defense (C : not null Character_Access) return Slot;

   --  Whether C's defense is saved as one value, and which, Which: the
   --  file gave one (Omit_Alternates), and the only value overridden, if
   --  any, is the one it was read into.  It is saved, or else the best.
   function Single_Defense (C : not null Character_Access; Which : out Slot) return Boolean;

   --  ---- Files ----

   --  The first entity of the file at Path, of every document in it,
   --  read as ova_fmt reads them, and N, how many it holds.  False, with
   --  Msg, if it can't be read, or Ova_Fmt.Entities finds a problem in
   --  any of them.  Free First with Free_Entity.
   function Read_Entity
     (Path : String; First : out Ova_Fmt.Entities.Entity; N : out Natural;
      Msg : out Unbounded_String) return Boolean;

   --  C alone, as a file's characters.
   function One (C : not null Character_Access) return Characters;

   --  Every character in the file at Path, in order, as From_Entity
   --  builds them, with notices for all of them (each names its
   --  character).  False, with Msg, if the file can't be read,
   --  Ova_Fmt.Entities finds a problem, or it holds none.
   function Load_All (Path : String; Cs : out Characters; Msg : out Unbounded_String) return Boolean;

   --  The one character in the file at Path, as Load_All; False, with
   --  Msg, as Load_All, or if the file holds more than one.
   function Load (Path : String; C : out Character_Access; Msg : out Unbounded_String) return Boolean;

   --  ---- Editing (the window's) ----
   --
   --  Every change the window makes goes through these, then Recompute.
   --  Traits and Modifiers are kept in the order the file's loader sorts
   --  them (by name, then detail, ignoring case), so the window lists
   --  them as ova_fmt prints them; attacks keep the order they were
   --  added in, as a file's do.  What is taken out of a list is the
   --  caller's to free.

   --  A new Ability or Weakness (Of_Kind), named for It, or Name if It
   --  is null (a name the tables don't have); Detail "" for none.
   function New_Trait (It : Rules.Item; Of_Kind : Rules.Kind; Level : Integer;
                       Name, Detail : Unbounded_String) return not null Trait;

   --  Puts T into List in its place: Abilities before Weaknesses, each
   --  sorted.
   procedure Insert_Trait (List : in out Calc.Trait; T : not null Trait);

   --  Takes T out of List; nothing if it isn't there.
   procedure Remove_Trait (List : in out Calc.Trait; T : not null Calc.Trait);

   --  Changes T to item It at Level with Detail, and moves it to its new
   --  place in List.  Its Perks and Flaws stay; its linked content stays
   --  if it keeps the same kind (Magic, Arcane to Magic, Witchcraft
   --  keeps the spells), and is freed if not, as the file couldn't hold
   --  it.
   procedure Change_Trait (List : in out Calc.Trait; T : not null Trait; It : Rules.Item;
                           Level : Integer; Detail : Unbounded_String);

   --  A new sheet for T, a Companion (a Secondary NPC's sheet, p. 52) or
   --  a Vehicle (a character's, p. 64): named T's detail, or what it is;
   --  with a combat block, not a Fragment.
   function New_Partner (T : not null Trait) return not null Character_Access
     with Pre => Rules."/=" (T.Item, null) and then T.Item.Linked in Rules.Partner | Rules.Machine;

   --  A new spell named Name, mimicking Ability (the Ability's name; It,
   --  Ova_Cg.Rules', or null) at Level.
   function New_Spell (Name, Ability : Unbounded_String; It : Rules.Item; Level : Integer)
     return not null Spell;

   procedure Remove_Spell (T : not null Calc.Trait; Sp : not null Calc.Spell);

   --  A new attack named Name, with no Perks or Flaws.
   function New_Attack (Name : Unbounded_String) return not null Attack;

   procedure Remove_Attack (C : not null Character_Access; A : not null Calc.Attack);

   --  A new Perk, or Flaw if Is_Flaw, taken Times times at Cost each (a
   --  Range_Cost's or User_Cost's; else ignored).
   function New_Modifier (It : not null Rules.Item; Is_Flaw : Boolean; Times, Cost : Integer)
     return not null Modifier;

   --  Puts M into List in its place: Perks before Flaws, each sorted.
   procedure Insert_Modifier (List : in out Calc.Modifier; M : not null Modifier);

   procedure Remove_Modifier (List : in out Calc.Modifier; M : not null Calc.Modifier);

   --  A copy of List, each Modifier copied: what a dialog puts back on
   --  Cancel.  Free it with Calc.Free_Mods.
   function Copy_Modifiers (List : Calc.Modifier) return Calc.Modifier;

   --  Sets a text field and its flag: "" is none.
   procedure Set_Text (Has : out Boolean; Field : out Unbounded_String; Text : Unbounded_String);

   --  S without leading and trailing blanks, tabs, line feeds and
   --  carriage returns: OvaText.Trim, ova_fmt's Trim_Whitespace.
   function Trim (S : String) return String;

end Ova_Cg.Character;
