--  The numbers on the sheet, computed from the character.
--
--  ova_cg_po's PLAN.md, "The rules the program computes" and "Limiting
--  the character": each attack's ROLL, DX and END; the END of an Ability
--  with Perks and Flaws or Endurance Use, and of each spell; DEFENSE,
--  Barrier's and Incorporeal Form's alternate Defenses; HEALTH,
--  ENDURANCE, Endurance Reserve and TV; the running totals; and the
--  warnings of broken limits.
--
--  A character is given as a Sheet of Traits (its Abilities and
--  Weaknesses) and Attacks, each Attack and Trait with its Perks and
--  Flaws (Modifiers).  The model (Ova_Cg.Character, Phase 3) extends
--  these types with what Ova_Cg.Calc doesn't need (names, details,
--  text), so they are allocated by the client and set up with Init and
--  Add, never here; Free frees a sheet and all it holds, extensions and
--  all.
--
--  Every computed number is a Number, which also holds the user's
--  override (ova_cg_po's PLAN.md, "Overriding a computed number").
--  Compute reads the overrides of the numbers others are computed from
--  (an attack's ROLL and DX, Defense, the totals) so that an override
--  counts downstream, and sets every computed value; the overrides it
--  leaves alone.
--
--  The fields Compute sets (Has_End, Points, In_TV, ...) are for reading.
--
--  Uses nothing of the window or the files, so its tests need no
--  display.

private with Ada.Containers.Vectors;
with Ova_Cg.Rules;

package Ova_Cg.Calc is

   --  Sheet kinds: where Health and Endurance start, and TV's last step.
   type Sheet_Kind is
     (Character_Sheet,  --  40 and 40 (p. 19); a Vehicle's too (p. 64)
      Companion_Sheet,  --  20 and 20 (p. 52); TV 4 less, at least 1, a Secondary NPC's (p. 123-124)
      Minion_Sheet,     --  10 and 10 (p. 58)
      Extra_Sheet,      --  10 and 10 (p. 123); TV always 1, an Extra's (p. 124)
      Boss_Sheet);      --  40 and 40, a character's (p. 123); it alone may have Boss Abilities

   --  Warning codes.  Each names what it is about in its trait, attack,
   --  modifier or spell; null for the sheet as a whole.
   type Warning_Code is
     (Unknown_Item,           --  trait or modifier: a name Ova_Cg.Rules doesn't have
      Level_Range,            --  trait: an Ability not +1 to +5, a Weakness not -1 to -3 (p. 18)
      Too_Often,              --  modifier: taken more times than its text allows (p. 83)
      Cost_Range,             --  modifier: a chosen cost outside its range, or not in steps of 5 (p. 87-88)
      No_Damage_Ineffective,  --  attack: No Damage with Ineffective (p. 88)
      Redirectable_Alone,     --  attack: Redirectable without Ranged (p. 86)
      Spell_Range,            --  spell: its Magic's level not 1 to 5, or its own not 1 to 5 or
                              --  -1 to -3: no cost (p. 58)
      Table_Range,            --  Tough, Vigorous or Endurance Reserve past +5 in all: counted as +5
      Base_Zero_Broken,       --  the Character Total (or points) beyond Base Zero's range (p. 21)
      Starting_Broken,        --  Abilities beyond the starting levels and the Weaknesses' (p. 21)
      Ceiling_Broken,         --  Abilities beyond the Power Ceiling (p. 21)
      Over_Five,              --  attack, or null for Defense: Abilities give a roll more than +5 (p. 21)
      Not_Boss);              --  trait: a Boss Ability on a sheet that isn't a Boss's (p. 123)

   --  ---- Numbers ----

   --  A number on the sheet: the computed value, and the override the
   --  user typed, if any.  A DX can be 1/2 (half, value 0) and a spell's
   --  END "10+" (plus).  An override is the same three.
   type Number is private;

   --  Overrides N with Value (1/2 if Half, Value+ if Plus).
   procedure Override (N : in out Number; Value : Integer; Half, Plus : Boolean);

   --  Back to the computed value.
   procedure Clear (N : in out Number);

   function Overridden (N : Number) return Boolean;

   --  The value in effect: the override if there is one; 1/2 is 0.
   function Value (N : Number) return Integer;
   function Half (N : Number) return Boolean;
   function Plus (N : Number) return Boolean;

   --  The number in effect as the sheet writes it: "4", "1/2", "10+".
   function Text (N : Number) return String;

   --  The computed number, whatever the override.
   function Computed_Text (N : Number) return String;

   --  Sets N's override from what the user typed in its box: blank
   --  clears it; else an integer, "1/2" if Allow_Half (a DX), or an
   --  integer and "+" if Allow_Plus (an END).  False, N unchanged, for
   --  anything else.
   function Parse (S : String; Allow_Half, Allow_Plus : Boolean; N : in out Number) return Boolean;

   --  ---- The character ----

   type Sheet_Record is tagged;
   type Sheet is access all Sheet_Record'Class;

   --  A Perk or Flaw taken, by an attack or an Ability.  Cost is each
   --  time's cost where the user sets it: a Range_Cost's or User_Cost's,
   --  or an item the tables don't have (from the file); else ignored.
   type Modifier_Record is tagged;
   type Modifier is access all Modifier_Record'Class;
   type Modifier_Record is tagged record
      Next  : Modifier;
      Item  : Rules.Item;  --  null: a name Ova_Cg.Rules doesn't have
      Times : Integer;     --  >= 1; ova_fmt's counts-as
      Cost  : Integer;
   end record;

   --  A Magic Ability's spell, mimicking Item at Level.
   type Spell_Record is tagged;
   type Spell is access all Spell_Record'Class;
   type Spell_Record is tagged record
      Next     : Spell;
      Item     : Rules.Item;
      Level    : Integer;
      End_Cost : Number;
   end record;

   --  An Ability or Weakness, at its signed level.
   type Trait_Record is tagged;
   type Trait is access all Trait_Record'Class;
   type Trait_Record is tagged record
      Next      : Trait;
      Item      : Rules.Item;  --  null: a name Ova_Cg.Rules doesn't have
      Of_Kind   : Rules.Kind;  --  Ability or Weakness, with or without Item
      Level     : Integer;
      Half_TV   : Boolean;     --  marked: half its level counts toward TV (p. 124)
      Mods      : Modifier;    --  its Perks and Flaws (p. 83)
      Use_Level : Integer;     --  the level, -1 to -3, of an Endurance Use tied to it; 0 if none
      Form      : Trait;       --  a Transformation's form: counted when transformed (p. 63)
      Spells    : Spell;       --  a Magic Ability's
      Partner   : Sheet;       --  a Companion's or Vehicle's own sheet
      Has_End   : Boolean;     --  it has Perks, Flaws or Endurance Use: End_Cost is its cost
      End_Cost  : Number;
      Points    : Integer;     --  its Scaled Cost points (p. 21), as the totals count them; 0 in a form
   end record;

   type Attack_Record is tagged;
   type Attack is access all Attack_Record'Class;
   type Attack_Record is tagged record
      Next        : Attack;
      Mods        : Modifier;
      Telekinetic : Boolean;   --  made with Telekinesis, which adds to its DX (p. 62)
      Transformed : Boolean;   --  made in the transformed form, as Miho's Mode SP
      Use_Level   : Integer;   --  an Endurance Use tied to it, as a Trait's
      Roll, DX, End_Cost : Number;
      --  What TV takes of it (ova_cg_po's PLAN.md, "The combat box"): its
      --  ROLL and DX in effect, less what Accurate, Inaccurate, Effective
      --  and Ineffective add; 1/2 and No Damage count as 0.  In_TV is
      --  False for an attack made in a form the sheet isn't shown in.
      In_TV         : Boolean;
      TV_Roll, TV_DX : Integer;
   end record;

   --  The limits the user turned on (p. 21; ova_fmt's options:).
   type Options_Record is record
      Base_Zero               : Boolean := False;
      Base_Zero_Range         : Integer := 0;
      Power_Ceiling           : Boolean := False;
      Ceiling                 : Integer := 0;
      Starting_Levels         : Boolean := False;
      Starting                : Integer := 0;
      Scaled_Cost             : Boolean := False;
      Half_Cost_Knowledge     : Boolean := False;
      Combined_Effectiveness  : Boolean := False;
   end record;

   type Warning is record
      Code     : Warning_Code;
      Of_Trait : Trait;
      Of_Attack : Attack;
      Of_Mod   : Modifier;
      Of_Spell : Spell;
   end record;

   type Warning_List is private;

   function Length (L : Warning_List) return Natural;

   --  The I'th warning, 1 <= I <= Length (L), in the order found.
   function Element (L : Warning_List; I : Positive) return Warning
     with Pre => I <= Length (L);

   type Sheet_Record is tagged limited record
      Of_Kind     : Sheet_Kind;
      Traits      : Trait;    --  in the order added
      Attacks     : Attack;
      Transformed : Boolean;  --  shown in the transformed form, as Fukiko's sheet is
      Options     : Options_Record;
      Defense, Barrier, Incorporeal, Health, Endurance, Reserve, TV : Number;
      Has_Barrier, Has_Incorporeal, Has_Reserve : Boolean;
      --  The running totals: levels (Knowledge and Ineptitude halved if
      --  the options say so), the Character Total, and Scaled Cost's
      --  points: the Abilities', and the Abilities' less the Weaknesses'.
      Ability_Levels, Weakness_Levels, Total, Ability_Points, Points : Number;
      Weakness_Points : Natural;
      Warnings        : Warning_List;  --  from the last Compute, in the order found
   end record;

   --  ---- Building a sheet ----

   procedure Init_Sheet (S : not null Sheet; Of_Kind : Sheet_Kind);

   --  Item may be null, for a name Ova_Cg.Rules doesn't have; Of_Kind
   --  then says which it is.  A Healer or Magic Ability starts marked for
   --  TV.
   procedure Init_Trait (T : not null Trait; Item : Rules.Item; Of_Kind : Rules.Kind; Level : Integer);

   --  Cost is each time's, used where the user sets it (Modifier_Record).
   procedure Init_Mod (M : not null Modifier; Item : Rules.Item; Times, Cost : Integer);

   procedure Init_Spell (Sp : not null Spell; Item : Rules.Item; Level : Integer);

   procedure Init_Attack (A : not null Attack);

   --  Each Add appends, keeping the order the items were added in.
   procedure Add_Trait (List : in out Trait; T : not null Trait);
   procedure Add_Mod (List : in out Modifier; M : not null Modifier);
   procedure Add_Spell (T : not null Trait; Sp : not null Spell);
   procedure Add_Attack (S : not null Sheet; A : not null Attack);

   --  Frees S, and every trait, form, modifier, spell, partner and
   --  attack it holds; S becomes null.
   procedure Free (S : in out Sheet);

   --  Frees a list of traits, with what each holds; List becomes null.
   procedure Free_Traits (List : in out Trait);
   procedure Free_Mods (List : in out Modifier);
   procedure Free_Spells (List : in out Spell);
   procedure Free_Attacks (List : in out Attack);

   --  ---- Computing ----

   --  Every number of S and of its partners' sheets, and their warnings.
   procedure Compute (S : not null Sheet);

private

   type Number is record
      Value       : Integer := 0;
      Half, Plus  : Boolean := False;
      Overridden  : Boolean := False;
      Ov_Value    : Integer := 0;
      Ov_Half, Ov_Plus : Boolean := False;
   end record;

   package Warning_Vectors is new Ada.Containers.Vectors (Positive, Warning);

   type Warning_List is record
      V : Warning_Vectors.Vector;
   end record;

end Ova_Cg.Calc;
