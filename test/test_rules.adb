--  Ova_Cg.Rules: the tables against the rulebook's Quick List, labels,
--  small tables.
--
--  The Quick List (p. 90) is a source independent of the entries'
--  headings, from which Ova_Cg.Rules' pages were taken: every name on it
--  must be in Ova_Cg.Rules, of the same kind, at the same place in the
--  book's order, with the cost it gives. Its entries below are
--  ova_cg_po's TestRules', which were generated from the PDF's text of
--  p. 90, not typed. Needs no display.

with Ada.Text_IO;
with Check;
with Ova_Cg.Rules; use Ova_Cg.Rules;

procedure Test_Rules is

   use Check;

   Next     : array (Kind) of Natural;  --  the Quick List's place in each kind
   Quick_OK : Boolean;

   --  One Quick List entry: kind, name, and for a Perk or Flaw how its
   --  cost is given and the cost (min, max for a range).
   procedure Q (Of_Kind : Kind; Name : String; Cost_Kind : Cost_Kind_Type; Cost, Max : Integer) is
      It : constant Item := Find (Name);
      OK : Boolean :=
        It /= null and then It.Of_Kind = Of_Kind and then Next (Of_Kind) < Count (Of_Kind)
        and then Get (Of_Kind, Next (Of_Kind)) = It;
   begin
      if OK and then Of_Kind >= Perk then
         OK := It.Cost_Kind = Cost_Kind;
         if OK and then Cost_Kind = Fixed_Cost then
            OK := It.Cost = Cost;
         elsif OK and then Cost_Kind = Range_Cost then
            OK := It.Min_Cost = Cost and then It.Max_Cost = Max;
         end if;
      end if;
      if not OK then
         Ada.Text_IO.Put_Line ("    the Quick List's " & Name & " doesn't match");
      end if;
      Quick_OK := Quick_OK and OK;
      Next (Of_Kind) := Next (Of_Kind) + 1;
   end Q;

   procedure Quick_List is
   begin
      --  Abilities
      Q (Ability, "Agile", Fixed_Cost, 0, 0);
      Q (Ability, "Armored", Fixed_Cost, 0, 0);
      Q (Ability, "Art of Invisibility", Fixed_Cost, 0, 0);
      Q (Ability, "Attack", Fixed_Cost, 0, 0);
      Q (Ability, "Barrier", Fixed_Cost, 0, 0);
      Q (Ability, "Beautiful", Fixed_Cost, 0, 0);
      Q (Ability, "Charismatic", Fixed_Cost, 0, 0);
      Q (Ability, "Combat Expert", Fixed_Cost, 0, 0);
      Q (Ability, "Companion", Fixed_Cost, 0, 0);
      Q (Ability, "Connected", Fixed_Cost, 0, 0);
      Q (Ability, "Cute!", Fixed_Cost, 0, 0);
      Q (Ability, "Dexterous", Fixed_Cost, 0, 0);
      Q (Ability, "Dimensional Pocket", Fixed_Cost, 0, 0);
      Q (Ability, "Endurance Reserve", Fixed_Cost, 0, 0);
      Q (Ability, "Evasive", Fixed_Cost, 0, 0);
      Q (Ability, "Famous", Fixed_Cost, 0, 0);
      Q (Ability, "Flight", Fixed_Cost, 0, 0);
      Q (Ability, "Gear", Fixed_Cost, 0, 0);
      Q (Ability, "Healer", Fixed_Cost, 0, 0);
      Q (Ability, "Heightened Sense", Fixed_Cost, 0, 0);
      Q (Ability, "Illusionist", Fixed_Cost, 0, 0);
      Q (Ability, "Incorporeal Form", Fixed_Cost, 0, 0);
      Q (Ability, "Intimidating", Fixed_Cost, 0, 0);
      Q (Ability, "Intuitive", Fixed_Cost, 0, 0);
      Q (Ability, "Inventor", Fixed_Cost, 0, 0);
      Q (Ability, "Invisibility", Fixed_Cost, 0, 0);
      Q (Ability, "Iron-Willed", Fixed_Cost, 0, 0);
      Q (Ability, "Knowledge", Fixed_Cost, 0, 0);
      Q (Ability, "Life Support", Fixed_Cost, 0, 0);
      Q (Ability, "Lucky", Fixed_Cost, 0, 0);
      Q (Ability, "Magic, Arcane", Fixed_Cost, 0, 0);
      Q (Ability, "Magic, Witchcraft", Fixed_Cost, 0, 0);
      Q (Ability, "Minions", Fixed_Cost, 0, 0);
      Q (Ability, "Passion", Fixed_Cost, 0, 0);
      Q (Ability, "Perceptive", Fixed_Cost, 0, 0);
      Q (Ability, "Performer", Fixed_Cost, 0, 0);
      Q (Ability, "Pilot", Fixed_Cost, 0, 0);
      Q (Ability, "Position of Power", Fixed_Cost, 0, 0);
      Q (Ability, "Psychic", Fixed_Cost, 0, 0);
      Q (Ability, "Quick", Fixed_Cost, 0, 0);
      Q (Ability, "Resistance", Fixed_Cost, 0, 0);
      Q (Ability, "Shape-Shifter", Fixed_Cost, 0, 0);
      Q (Ability, "Sixth Sense", Fixed_Cost, 0, 0);
      Q (Ability, "Smart", Fixed_Cost, 0, 0);
      Q (Ability, "Spirit Medium", Fixed_Cost, 0, 0);
      Q (Ability, "Strong", Fixed_Cost, 0, 0);
      Q (Ability, "Telekinesis", Fixed_Cost, 0, 0);
      Q (Ability, "Teleport", Fixed_Cost, 0, 0);
      Q (Ability, "Time Freeze", Fixed_Cost, 0, 0);
      Q (Ability, "Tough", Fixed_Cost, 0, 0);
      Q (Ability, "Transformation", Fixed_Cost, 0, 0);
      Q (Ability, "Unique Ability", Fixed_Cost, 0, 0);
      Q (Ability, "Vehicle (Mecha)", Fixed_Cost, 0, 0);
      Q (Ability, "Vigorous", Fixed_Cost, 0, 0);
      Q (Ability, "Walking Arsenal", Fixed_Cost, 0, 0);
      Q (Ability, "Wealthy", Fixed_Cost, 0, 0);
      --  Weaknesses
      Q (Weakness, "Absent-Minded", Fixed_Cost, 0, 0);
      Q (Weakness, "Accidental Transformation", Fixed_Cost, 0, 0);
      Q (Weakness, "Ageism", Fixed_Cost, 0, 0);
      Q (Weakness, "Airhead", Fixed_Cost, 0, 0);
      Q (Weakness, "Amnesia", Fixed_Cost, 0, 0);
      Q (Weakness, "Arrogant", Fixed_Cost, 0, 0);
      Q (Weakness, "Awkward Size", Fixed_Cost, 0, 0);
      Q (Weakness, "Bizarre Appearance", Fixed_Cost, 0, 0);
      Q (Weakness, "Clumsy", Fixed_Cost, 0, 0);
      Q (Weakness, "Code of Conduct", Fixed_Cost, 0, 0);
      Q (Weakness, "Compulsion", Fixed_Cost, 0, 0);
      Q (Weakness, "Coward", Fixed_Cost, 0, 0);
      Q (Weakness, "Crybaby", Fixed_Cost, 0, 0);
      Q (Weakness, "Dense", Fixed_Cost, 0, 0);
      Q (Weakness, "Dependency", Fixed_Cost, 0, 0);
      Q (Weakness, "Dull", Fixed_Cost, 0, 0);
      Q (Weakness, "Easily Distracted", Fixed_Cost, 0, 0);
      Q (Weakness, "Emotionless", Fixed_Cost, 0, 0);
      Q (Weakness, "Endurance Use", Fixed_Cost, 0, 0);
      Q (Weakness, "Fear", Fixed_Cost, 0, 0);
      Q (Weakness, "Focus", Fixed_Cost, 0, 0);
      Q (Weakness, "Frail", Fixed_Cost, 0, 0);
      Q (Weakness, "Fussy", Fixed_Cost, 0, 0);
      Q (Weakness, "Greedy", Fixed_Cost, 0, 0);
      Q (Weakness, "Guardian", Fixed_Cost, 0, 0);
      Q (Weakness, "Hatred", Fixed_Cost, 0, 0);
      Q (Weakness, "Impaired Sense", Fixed_Cost, 0, 0);
      Q (Weakness, "Impulsive", Fixed_Cost, 0, 0);
      Q (Weakness, "Ineptitude", Fixed_Cost, 0, 0);
      Q (Weakness, "Infamous", Fixed_Cost, 0, 0);
      Q (Weakness, "Jittery", Fixed_Cost, 0, 0);
      Q (Weakness, "Kind-Hearted", Fixed_Cost, 0, 0);
      Q (Weakness, "Languid", Fixed_Cost, 0, 0);
      Q (Weakness, "Lecherous", Fixed_Cost, 0, 0);
      Q (Weakness, "Limited Uses", Fixed_Cost, 0, 0);
      Q (Weakness, "Loner", Fixed_Cost, 0, 0);
      Q (Weakness, "Love Interest", Fixed_Cost, 0, 0);
      Q (Weakness, "Love Magnet", Fixed_Cost, 0, 0);
      Q (Weakness, "Mute", Fixed_Cost, 0, 0);
      Q (Weakness, "Naive", Fixed_Cost, 0, 0);
      Q (Weakness, "Nosebleeder", Fixed_Cost, 0, 0);
      Q (Weakness, "Oblivious", Fixed_Cost, 0, 0);
      Q (Weakness, "Obsession", Fixed_Cost, 0, 0);
      Q (Weakness, "Outcast", Fixed_Cost, 0, 0);
      Q (Weakness, "Overconfident", Fixed_Cost, 0, 0);
      Q (Weakness, "Pacifist", Fixed_Cost, 0, 0);
      Q (Weakness, "Poor", Fixed_Cost, 0, 0);
      Q (Weakness, "Quirk", Fixed_Cost, 0, 0);
      Q (Weakness, "Restricted Freedom", Fixed_Cost, 0, 0);
      Q (Weakness, "Rival", Fixed_Cost, 0, 0);
      Q (Weakness, "Room for Two", Fixed_Cost, 0, 0);
      Q (Weakness, "Rude", Fixed_Cost, 0, 0);
      Q (Weakness, "Secret", Fixed_Cost, 0, 0);
      Q (Weakness, "Sensitivity", Fixed_Cost, 0, 0);
      Q (Weakness, "Servitude", Fixed_Cost, 0, 0);
      Q (Weakness, "Short-Tempered", Fixed_Cost, 0, 0);
      Q (Weakness, "Shy", Fixed_Cost, 0, 0);
      Q (Weakness, "Slow", Fixed_Cost, 0, 0);
      Q (Weakness, "Soft Spot", Fixed_Cost, 0, 0);
      Q (Weakness, "Split Personality", Fixed_Cost, 0, 0);
      Q (Weakness, "Stubborn", Fixed_Cost, 0, 0);
      Q (Weakness, "Suppressed Power", Fixed_Cost, 0, 0);
      Q (Weakness, "Trigger", Fixed_Cost, 0, 0);
      Q (Weakness, "Unique Weakness", Fixed_Cost, 0, 0);
      Q (Weakness, "Unlucky", Fixed_Cost, 0, 0);
      Q (Weakness, "Vulnerability", Fixed_Cost, 0, 0);
      Q (Weakness, "Wanted", Fixed_Cost, 0, 0);
      Q (Weakness, "Weak", Fixed_Cost, 0, 0);
      Q (Weakness, "Weak-Willed", Fixed_Cost, 0, 0);
      --  Perks
      Q (Perk, "Accurate", Fixed_Cost, 5, 0);
      Q (Perk, "Area Effect", Fixed_Cost, 10, 0);
      Q (Perk, "Armor Piercing", Fixed_Cost, 5, 0);
      Q (Perk, "Barrier Buster", Fixed_Cost, 5, 0);
      Q (Perk, "Blinding", Fixed_Cost, 20, 0);
      Q (Perk, "Continued Effect", Fixed_Cost, 10, 0);
      Q (Perk, "Defensive", Fixed_Cost, 5, 0);
      Q (Perk, "Disarming", Fixed_Cost, 10, 0);
      Q (Perk, "Effective", Fixed_Cost, 5, 0);
      Q (Perk, "Fatiguing", Fixed_Cost, 0, 0);
      Q (Perk, "Impairing", Fixed_Cost, 10, 0);
      Q (Perk, "Multiple Targets", Fixed_Cost, 10, 0);
      Q (Perk, "No Gesture", Fixed_Cost, 5, 0);
      Q (Perk, "Overwhelming", Fixed_Cost, 15, 0);
      Q (Perk, "Paralyzing", Fixed_Cost, 10, 0);
      Q (Perk, "Ranged", Fixed_Cost, 0, 0);
      Q (Perk, "Ranged, Str.-Powered", Fixed_Cost, 5, 0);
      Q (Perk, "Reach", Fixed_Cost, 5, 0);
      Q (Perk, "Redirectable", Fixed_Cost, 5, 0);
      Q (Perk, "Strike Through", Fixed_Cost, 5, 0);
      Q (Perk, "Stunning", Fixed_Cost, 10, 0);
      Q (Perk, "Trap", Fixed_Cost, 5, 0);
      Q (Perk, "Unique Perk", User_Cost, 0, 0);
      Q (Perk, "Vampire", Fixed_Cost, 5, 0);
      Q (Perk, "Will Attack", Fixed_Cost, 0, 0);
      --  Flaws
      Q (Flaw, "Activation", Fixed_Cost, -10, 0);
      Q (Flaw, "Ammunition", Fixed_Cost, -5, 0);
      Q (Flaw, "Assisted", Fixed_Cost, -15, 0);
      Q (Flaw, "Backlash", Fixed_Cost, -5, 0);
      Q (Flaw, "Break", Fixed_Cost, -10, 0);
      Q (Flaw, "Buildup", Fixed_Cost, -5, 0);
      Q (Flaw, "Cancel", Range_Cost, -20, 0);
      Q (Flaw, "Concentration", Fixed_Cost, -20, 0);
      Q (Flaw, "Delayed", Fixed_Cost, -5, 0);
      Q (Flaw, "Elaborate Gestures", Fixed_Cost, -5, 0);
      Q (Flaw, "Feather Blow", Fixed_Cost, -5, 0);
      Q (Flaw, "Finisher", Fixed_Cost, -10, 0);
      Q (Flaw, "Inaccurate", Fixed_Cost, -5, 0);
      Q (Flaw, "Ineffective", Fixed_Cost, -5, 0);
      Q (Flaw, "Low Penetration", Fixed_Cost, -5, 0);
      Q (Flaw, "No Damage", Fixed_Cost, -20, 0);
      Q (Flaw, "Open to Attack", Fixed_Cost, -25, 0);
      Q (Flaw, "Recoil", Fixed_Cost, -10, 0);
      Q (Flaw, "Requirement", Range_Cost, -20, -5);
      Q (Flaw, "Self-Only", Fixed_Cost, -5, 0);
      Q (Flaw, "Unique Flaw", User_Cost, 0, 0);
      Q (Flaw, "Unwieldy", Fixed_Cost, -5, 0);
      Q (Flaw, "Weapon", Fixed_Cost, -5, 0);
   end Quick_List;

   procedure Test_Quick_List is
   begin
      Next := [others => 0];
      Quick_OK := True;
      Quick_List;
      Check.Check (Quick_OK, "every Quick List name: found, of its kind, in the book's order, at its cost");
      Check.Check ((for all K in Kind => Next (K) = Count (K)), "nothing beyond the Quick List");
      Check.Check
        (Count (Ability) = 56 and Count (Weakness) = 69 and Count (Perk) = 25 and Count (Flaw) = 23,
         "56 Abilities, 69 Weaknesses, 25 Perks, 23 Flaws");
   end Test_Quick_List;

   --  Each kind's pages lie within its part of the chapter and never go
   --  back, since the book lists each kind alphabetically.
   function Pages_In (Of_Kind : Kind; From, To : Positive) return Boolean is
      OK   : Boolean := True;
      Last : Positive := From;
   begin
      for I in 0 .. Count (Of_Kind) - 1 loop
         declare
            It : constant Item := Get (Of_Kind, I);
         begin
            OK := OK and It.Page >= Last and It.Page <= To;
            Last := It.Page;
         end;
      end loop;
      return OK and Get (Of_Kind, 0).Page = From and Get (Of_Kind, Count (Of_Kind) - 1).Page = To;
   end Pages_In;

   function Page_Is (Name : String; Page : Positive) return Boolean is
      It : constant Item := Find (Name);
   begin
      return It /= null and then It.Page = Page;
   end Page_Is;

   procedure Test_Pages is
   begin
      Check.Check (Pages_In (Ability, 49, 65), "Abilities on pp. 49-65, in order");
      Check.Check (Pages_In (Weakness, 66, 82), "Weaknesses on pp. 66-82, in order");
      Check.Check (Pages_In (Perk, 83, 86), "Perks on pp. 83-86, in order");
      Check.Check (Pages_In (Flaw, 87, 89), "Flaws on pp. 87-89, in order");
      Check.Check
        (Page_Is ("Attack", 50) and Page_Is ("Short-Tempered", 79) and Page_Is ("Weapon", 89)
         and Page_Is ("Ammunition", 87) and Page_Is ("Ranged, Strength-Powered", 86),
         "pages checked by eye and by hand");
      Check.Check (Pdf_Index (50) = 52, "the PDF's page index is the printed page + 2");
   end Test_Pages;

   --  How often the item called Name may be taken; -1 if there's none.
   function Max_Times (Name : String) return Integer is
      It : constant Item := Find (Name);
   begin
      return (if It = null then -1 else It.Max_Times);
   end Max_Times;

   --  The linked content of the item called Name; False if there's none.
   function Linked_Is (Name : String; Linked : Link) return Boolean is
      It : constant Item := Find (Name);
   begin
      return It /= null and then It.Linked = Linked;
   end Linked_Is;

   --  How often a Perk or Flaw may be taken (ova_cg_po's PLAN.md, "Perk
   --  and Flaw costs").
   procedure Test_Repeats is
      Unlimited_N, Two, Three, Once : Natural := 0;
   begin
      for K in Perk .. Flaw loop
         for I in 0 .. Count (K) - 1 loop
            case Get (K, I).Max_Times is
               when Unlimited => Unlimited_N := Unlimited_N + 1;
               when 3 => Three := Three + 1;
               when 2 => Two := Two + 1;
               when 1 => Once := Once + 1;
               when others => null;
            end case;
         end loop;
      end loop;
      Check.Check (Unlimited_N = 16 and Two = 2 and Three = 1 and Once = 29,
                   "16 repeat freely, 2 at most twice, 1 at most three times, 29 once");
      Check.Check
        (Max_Times ("Continued Effect") = 2 and Max_Times ("Paralyzing") = 2
         and Max_Times ("Ammunition") = 3,
         "the limited ones: Continued Effect, Paralyzing, Ammunition");
      Check.Check
        (Max_Times ("Low Penetration") = Unlimited and Max_Times ("Assisted") = Unlimited
         and Max_Times ("Effective") = Unlimited,
         "Low Penetration, Assisted, Effective repeat");
      Check.Check
        (Max_Times ("Cancel") = 1 and Max_Times ("Requirement") = 1 and Max_Times ("Unique Perk") = 1,
         "Cancel, Requirement, Unique Perk are taken once");
   end Test_Repeats;

   --  True if Find (Name) finds the item named Book_Name.
   function Finds (Name, Book_Name : String) return Boolean is
      It : constant Item := Find (Name);
   begin
      return It /= null and then Name_Of (It) = Book_Name;
   end Finds;

   procedure Test_Find is
   begin
      Check.Check (Finds ("attack", "Attack"), "Find ignores case");
      Check.Check (Finds ("Vehicle", "Vehicle (Mecha)"), "Find: Vehicle is Vehicle (Mecha)");
      Check.Check (Finds ("ranged, str.-powered", "Ranged, Strength-Powered"),
                   "Find: the Quick List's Ranged, Str.-Powered");
      Check.Check
        (Find ("Magic, Testing") = null and Find ("") = null and Find ("Attac") = null
         and Find ("Attacks") = null,
         "Find: no near misses");
   end Test_Find;

   procedure Test_Labels is
      OK : Boolean := True;
   begin
      Check.Check (Label (Find ("Attack")) = "Attack (p. 50)", "Label: Attack (p. 50)");
      Check.Check (Page_Text (Find ("Attack")) = "p. 50", "PageText: p. 50");
      Check.Check (Page_Text (null) = "p. ?", "PageText of an unknown item: p. ?");
      Check.Check (Label_Of ("Magic, Testing") = "Magic, Testing (p. ?)",
                   "LabelOf an unknown name keeps it, with p. ?");
      Check.Check (Label_Of ("vehicle") = "Vehicle (Mecha) (p. 64)",
                   "LabelOf a known name gives the book's name");
      --  ova_cg_po's labels are ARRAY 64 OF CHAR; Ada's aren't cut short,
      --  but the window's widths were made for labels that fit.
      for K in Kind loop
         for I in 0 .. Count (K) - 1 loop
            declare
               S : constant String := Label (Get (K, I));
            begin
               OK := OK and S'Length > 0 and S'Length < 63 and S (S'Last) = ')';
            end;
         end loop;
      end loop;
      Check.Check (OK, "every label fits 64 characters");
   end Test_Labels;

   procedure Test_Tables is
      function Row (M, A, B, C, D, E : Natural) return Boolean is
        (Spell_Cost (M, 1) = A and Spell_Cost (M, 2) = B and Spell_Cost (M, 3) = C
         and Spell_Cost (M, 4) = D and Spell_Cost (M, 5) = E);
   begin
      Check.Check
        (Tough_Bonus (0) = 0 and Tough_Bonus (1) = 10 and Tough_Bonus (4) = 40 and Tough_Bonus (5) = 60,
         "Tough and Vigorous: 10, 20, 30, 40, 60");
      Check.Check (Reserve_Bonus (1) = 20 and Reserve_Bonus (5) = 100, "Endurance Reserve: 20 a level");
      Check.Check
        (Endurance_Use_Cost (0) = 0 and Endurance_Use_Cost (-1) = 5 and Endurance_Use_Cost (-2) = 10
         and Endurance_Use_Cost (-3) = 20,
         "Endurance Use: 5, 10, 20");
      Check.Check
        (Row (1, 20, 30, 40, 50, 60) and Row (2, 10, 20, 30, 40, 50) and Row (3, 5, 10, 20, 30, 40)
         and Row (4, 2, 5, 10, 20, 30) and Row (5, 0, 2, 5, 10, 20),
         "the Spell Endurance Cost table (p. 58)");
      Check.Check (Spell_Cost (3, 2) = 10, "Auren's Mana Shield: Barrier +2 at Magic 3 costs 10");
   end Test_Tables;

   function Has (Name : String; Which : Flag) return Boolean is
      It : constant Item := Find (Name);
   begin
      return It /= null and then Has (It, Which);
   end Has;

   procedure Test_Flags is
   begin
      Check.Check
        (Has ("Agile", Agility) and Has ("Clumsy", Agility) and Has ("Combat Expert", Combat_Skill)
         and Has ("Iron-Willed", Will) and Has ("Weak-Willed", Will),
         "the Attack Roll's Abilities and Weaknesses");
      Check.Check
        (Has ("Evasive", Defense_Roll) and Has ("Quick", Defense_Roll) and Has ("Slow", Defense_Roll)
         and Has ("Barrier", Second_Defense),
         "the Defense Roll's");
      Check.Check
        (Has ("Attack", Damage) and Has ("Strong", Strength) and Has ("Weak", Strength)
         and Has ("Telekinesis", Telekinetic),
         "the Damage Multiplier's");
      Check.Check
        (Has ("Tough", Health_Table) and Has ("Frail", Health_Tens) and Has ("Vigorous", Endurance_Table)
         and Has ("Languid", Endurance_Tens) and Has ("Endurance Reserve", Reserve),
         "Health's and Endurance's");
      Check.Check
        (Has ("Healer", Half_TV) and Has ("Magic, Arcane", Half_TV) and Has ("Magic, Witchcraft", Half_TV)
         and Has ("Companion", No_TV) and Has ("Minions", No_TV) and Has ("Armored", Armor),
         "TV's");
      Check.Check
        (Has ("Knowledge", Half_Cost) and Has ("Ineptitude", Half_Cost) and Has ("Endurance Use", Cost_Up),
         "half cost, and Endurance Use");
      Check.Check
        (Has ("Accurate", Roll_Each) and Has ("Inaccurate", Roll_Each) and Has ("Effective", Damage_Each)
         and Has ("Ineffective", Damage_Each) and Has ("Ranged", Ranged_Attack)
         and Has ("Ranged, Strength-Powered", Strength_Ranged) and Has ("Will Attack", Will_Attack)
         and Has ("No Damage", No_Damage_Done),
         "the Perks' and Flaws'");
      Check.Check
        (Linked_Is ("Transformation", Form) and Linked_Is ("Companion", Partner)
         and Linked_Is ("Magic, Arcane", Spells) and Linked_Is ("Magic, Witchcraft", Spells)
         and Linked_Is ("Vehicle (Mecha)", Machine) and Linked_Is ("Attack", No_Link),
         "linked content");
   end Test_Flags;

   --  The Boss Abilities (p. 123): Abilities, found by name, but offered
   --  only to a list that asks for them, after every other.
   procedure Test_Boss is
      N  : constant Natural := Count (Ability);
      OK : Boolean := Boss_Count = 4;
   begin
      OK := OK and then Name_Of (Get_Boss (0)) = "Health Reserve"
        and then Name_Of (Get_Boss (1)) = "Extra Actions"
        and then Name_Of (Get_Boss (2)) = "Scale Advantage"
        and then Name_Of (Get_Boss (3)) = "Escape Plan";
      Check.Check (OK, "the four Boss Abilities, in the book's order");
      OK := True;
      for I in 0 .. 3 loop
         declare
            It : constant Item := Get_Boss (I);
         begin
            OK := OK and then It.Of_Kind = Ability and then It.Page = 123 and then Has (It, Boss_Only)
              and then Find (Name_Of (It)) = It and then Offer_Index (It, Ability, False) = -1
              and then Offer_Index (It, Ability, True) = N + I
              and then Offered (Ability, N + I, True) = It;
         end;
      end loop;
      Check.Check (OK, "each: an Ability on p. 123, found by name, offered last and only to a Boss's list");
      for I in 0 .. N - 1 loop
         OK := OK and then not Has (Get (Ability, I), Boss_Only)
           and then Offer_Index (Get (Ability, I), Ability, True) = I;
      end loop;
      Check.Check (OK, "the other Abilities: none is a Boss Ability, their places the same");
      Check.Check (Offer_Count (Ability, False) = N and then Offer_Count (Ability, True) = N + 4
                   and then Offer_Count (Weakness, True) = Count (Weakness),
                   "only Abilities offer them");
   end Test_Boss;

begin
   Test_Quick_List;
   Test_Pages;
   Test_Repeats;
   Test_Find;
   Test_Labels;
   Test_Tables;
   Test_Boss;
   Test_Flags;
   Check.Summary;
end Test_Rules;
