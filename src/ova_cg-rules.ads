--  The rulebook's names, pages and numbers: no descriptions.
--
--  ova_cg_po's PLAN.md, "Data tables" and "The rules the program
--  computes".  Every Ability, Weakness, Perk and Flaw of the OVA
--  rulebook, in the book's order (alphabetical within each kind), with
--  the page it is described on and what the calculations need of it;
--  and the rulebook's small tables (Tough, Vigorous, Endurance Reserve,
--  Endurance Use, spell costs).  The rulebook's text stays out
--  (AGENTS.md): to explain an item the program opens the book at its
--  page.
--
--  Pages are the book's printed numbers, which are also the PDF's page
--  labels; the PDF's page index is the printed page + Pdf_Page_Offset.
--  The pages were checked against the PDF by the font of the entries'
--  headings (tools/rulebook-headings.py, make check-pages).
--
--  Uses nothing of the window or the files, so its tests need no
--  display.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Ova_Cg.Rules is

   --  Where the NPC types, Heroic, Secondary, Extra and Boss (ova_fmt's
   --  npc-type:), and the Boss Abilities are described: their Health and
   --  Endurance; TV's step for them is on p. 124.
   NPC_Types_Page : constant := 123;

   type Kind is (Ability, Weakness, Perk, Flaw);

   Pdf_Page_Offset : constant := 2;  --  PDF page index = printed page + 2

   --  What an Ability or Weakness does to the sheet.  Its signed level
   --  is what it adds: Agile +2 adds 2 dice, Clumsy -2 takes 2.  Then
   --  what a Perk or Flaw does to an attack's numbers, after the
   --  Abilities' and Weaknesses'.
   type Flag is
     (Agility,          --  Attack Rolls, but a Will Attack's: Agile, Clumsy (p. 105, 86)
      Combat_Skill,     --  Attack Rolls, a Will Attack's too: Combat Expert
      Will,             --  a Will Attack's roll, in Agility's place: Iron-Willed, Weak-Willed
      Defense_Roll,     --  Defense Rolls: Evasive, Quick, Slow (p. 105)
      Damage,           --  the Damage Multiplier: Attack (p. 106)
      Strength,         --  the Damage Multiplier, but a Ranged attack's: Strong, Weak (p. 85)
      Health_Table,     --  Health + the Tough table (p. 63)
      Health_Tens,      --  Health - 10 a level: Frail (p. 71)
      Endurance_Table,  --  Endurance + the Vigorous table (p. 65)
      Endurance_Tens,   --  Endurance - 10 a level: Languid (p. 73)
      Armor,            --  Armored: in TV (p. 124)
      Second_Defense,   --  a second Defense Roll, 2 + its level: Barrier (p. 51)
      Telekinetic,      --  its level adds to an attack made with it: Telekinesis (p. 62)
      Half_TV,          --  adds half its level to TV unless unmarked: Healer, Magic (p. 124)
      No_TV,            --  never in TV, which is its own: Companion, Minions (p. 124)
      Half_Cost,        --  may cost half under the limits: Knowledge, Ineptitude (p. 57)
      Reserve,          --  a separate store of Endurance, 20 a level: Endurance Reserve (p. 53)
      Cost_Up,          --  raises one Ability's Endurance cost: Endurance Use (p. 70)
      Own_Cost,         --  spends Endurance of its own as it is used, so a spell of it
                        --  costs more than the table's, "10+": Barrier (p. 51, 58)
      Casts_Weaknesses, --  its spells cast Weaknesses, -1 to -3, at Arcane's costs:
                        --  Witchcraft (p. 58)
      Third_Defense,    --  another alternate Defense Roll, 2 + its level, written after
                        --  Barrier's: Incorporeal Form, its dice as the Defense Roll (p. 55)
      Boss_Only,        --  a Boss Ability: +5 TV (p. 124), no level in the totals (p. 123)
      --  A Perk's or Flaw's:
      Roll_Each,        --  +1 die a time (Accurate), or -1 (Inaccurate)
      Damage_Each,      --  +1 DX a time (Effective), or -1 (Ineffective)
      Ranged_Attack,    --  drops Strong and Weak (Ranged, p. 85)
      Strength_Ranged,  --  keeps them (Ranged, Strength-Powered, p. 86)
      Will_Attack,      --  Iron-Willed and Weak-Willed for Agile and Clumsy (p. 86)
      No_Damage_Done);  --  DX 0 (No Damage, p. 88)

   type Flag_Set is array (Flag) of Boolean with Pack;

   --  What linked content an Ability has (Item_Record.Linked).
   type Link is (No_Link, Spells, Form, Partner, Machine);

   --  How a Perk's or Flaw's cost is set (Item_Record.Cost_Kind).
   type Cost_Kind_Type is
     (Fixed_Cost,  --  Cost, each time it is taken
      Range_Cost,  --  chosen from Min_Cost .. Max_Cost, in steps of 5 (Cancel, Requirement)
      User_Cost);  --  any the user and GM agree on (Unique Perk, Unique Flaw)

   Unlimited : constant := Integer'Last;  --  Max_Times of a Perk or Flaw taken as often as wanted

   --  Pages of the rules themselves, for the window's "?" buttons.
   Limits_Page           : constant := 21;   --  Limiting the Character
   Perks_Flaws_Page      : constant := 83;   --  Ability Perks and Flaws: how they cost
   Affinities_Page       : constant := 89;
   Quick_List_Page       : constant := 90;
   Spell_Cost_Page       : constant := 58;   --  the Spell Endurance Cost table
   Rolls_Page            : constant := 105;  --  Attack and Defense Rolls
   Damage_Page           : constant := 106;
   Health_Endurance_Page : constant := 107;
   Threat_Value_Page     : constant := 124;

   type Item_Record is record
      Name   : Unbounded_String;
      Of_Kind : Kind;
      Page   : Positive;
      Flags  : Flag_Set;
      Linked : Link;  --  an Ability's linked content
      --  A Perk's or Flaw's Endurance cost, each time it is taken
      --  (negative for a Flaw); for a Range_Cost one, Min_Cost ..
      --  Max_Cost; and how often it may be taken.
      Cost_Kind                    : Cost_Kind_Type;
      Cost, Min_Cost, Max_Cost     : Integer;
      Max_Times                    : Positive;
   end record;

   type Item is access constant Item_Record;

   --  How many items of a kind there are.
   function Count (Of_Kind : Kind) return Natural;

   --  The I'th item of a kind, 0 <= I < Count (Of_Kind), in the book's
   --  order.
   function Get (Of_Kind : Kind; I : Natural) return not null Item
     with Pre => I < Count (Of_Kind);

   --  How many Boss Abilities there are.  They are Abilities, but Count
   --  and Get don't see them: only a Boss's list offers them.
   function Boss_Count return Natural;

   --  The I'th Boss Ability, 0 <= I < Boss_Count, in the book's order.
   function Get_Boss (I : Natural) return not null Item
     with Pre => I < Boss_Count;

   --  How many names a list of a kind offers: With_Boss, a list of
   --  Abilities offers the Boss Abilities too, at its end.
   function Offer_Count (Of_Kind : Kind; With_Boss : Boolean) return Natural;

   --  The I'th name such a list offers, 0 <= I < Offer_Count.
   function Offered (Of_Kind : Kind; I : Natural; With_Boss : Boolean) return not null Item
     with Pre => I < Offer_Count (Of_Kind, With_Boss);

   --  It's place in such a list, from 0; -1 if the list doesn't offer it.
   function Offer_Index (It : not null Item; Of_Kind : Kind; With_Boss : Boolean) return Integer;

   --  The item named Name, ignoring case, or by an alias ("Vehicle" for
   --  "Vehicle (Mecha)"); null if there is none.  Names are unique
   --  across the four kinds.
   function Find (Name : String) return Item;

   --  The item's name.
   function Name_Of (It : not null Item) return String is (To_String (It.Name));

   --  True if It does Which.
   function Has (It : not null Item; Which : Flag) return Boolean is (It.Flags (Which));

   --  What the window shows (ova_cg_po's PLAN.md, "Page numbers beside
   --  names").

   --  "p. 50"; "p. ?" for null, an item the tables don't have.
   function Page_Text (It : Item) return String;

   --  "Attack (p. 50)": an item's name with its page, as every name is
   --  shown.
   function Label (It : not null Item) return String;

   --  "Secondary (p. 123)": a name that isn't one of the items', with
   --  the page it is described on.
   function Page_Label (Name : String; Page : Positive) return String;

   --  Name's label, as written, if the tables have it: "Magic, Testing
   --  (p. ?)" if they don't.
   function Label_Of (Name : String) return String;

   --  The PDF's page index of a printed page.
   function Pdf_Index (Page : Positive) return Positive is (Page + Pdf_Page_Offset);

   --  The rulebook's small tables.

   --  Tough's bonus to Health (p. 63), and Vigorous's to Endurance
   --  (p. 65), the same table: 10, 20, 30, 40, 60 for +1 to +5; 0 for 0.
   function Tough_Bonus (Level : Integer) return Natural
     with Pre => Level in 0 .. 5;

   --  Endurance Reserve's store (p. 53): 20 a level.
   function Reserve_Bonus (Level : Integer) return Natural
     with Pre => Level in 0 .. 5;

   --  What Endurance Use adds to an Ability's cost (p. 70): 5, 10, 20 at
   --  -1, -2, -3; 0 at 0.
   function Endurance_Use_Cost (Level : Integer) return Natural
     with Pre => Level in -3 .. 0;

   --  The Spell Endurance Cost table (p. 58): casting a spell that
   --  mimics an Ability of level Ability_Level, at Magic level Magic,
   --  both 1 .. 5.
   function Spell_Cost (Magic, Ability_Level : Integer) return Natural
     with Pre => Magic in 1 .. 5 and Ability_Level in 1 .. 5;

end Ova_Cg.Rules;
