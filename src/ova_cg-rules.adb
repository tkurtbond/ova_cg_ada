with Ada.Characters.Handling;

package body Ova_Cg.Rules is

   Max_Items : constant := 200;

   type Flag_List is array (Positive range <>) of Flag;

   Items   : array (0 .. Max_Items - 1) of aliased Item_Record;
   N_Items : Natural := 0;
   First   : array (Kind) of Natural := [others => 0];  --  each kind's span of items
   Counts  : array (Kind) of Natural := [others => 0];

   --  Other names an item is found by: the Quick List's abbreviation,
   --  and the name without its parenthesis.
   type Alias_Record is record
      Alias : Unbounded_String;
      It    : Item;
   end record;
   Aliases   : array (1 .. 4) of Alias_Record;
   N_Aliases : Natural := 0;

   Spell_Costs : array (1 .. 5, 1 .. 5) of Natural;  --  (Magic, Ability_Level)

   --  ---- Text ----

   --  A = B, ignoring ASCII case: names are ASCII.
   function Same_Name (A, B : String) return Boolean is
     (Ada.Characters.Handling.To_Lower (A) = Ada.Characters.Handling.To_Lower (B));

   --  N >= 0 in decimal.
   function Image (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Image;

   --  ---- The tables ----

   function New_Item (Name : String; Of_Kind : Kind; Page : Positive; Flags : Flag_List)
     return Natural
   is
      Set : Flag_Set := [others => False];
   begin
      pragma Assert (N_Items < Max_Items);
      for F of Flags loop
         Set (F) := True;
      end loop;
      Items (N_Items) :=
        (Name => To_Unbounded_String (Name), Of_Kind => Of_Kind, Page => Page, Flags => Set,
         Linked => No_Link, Cost_Kind => Fixed_Cost, Cost => 0, Min_Cost => 0, Max_Cost => 0,
         Max_Times => 1);
      if Counts (Of_Kind) = 0 then
         First (Of_Kind) := N_Items;
      end if;
      Counts (Of_Kind) := Counts (Of_Kind) + 1;
      N_Items := N_Items + 1;
      return N_Items - 1;
   end New_Item;

   procedure A (Name : String; Page : Positive; Flags : Flag_List) is
      I : constant Natural := New_Item (Name, Ability, Page, Flags) with Unreferenced;
   begin
      null;
   end A;

   procedure L (Name : String; Page : Positive; Flags : Flag_List; Linked : Link) is
      I : constant Natural := New_Item (Name, Ability, Page, Flags);
   begin
      Items (I).Linked := Linked;
   end L;

   procedure W (Name : String; Page : Positive; Flags : Flag_List) is
      I : constant Natural := New_Item (Name, Weakness, Page, Flags) with Unreferenced;
   begin
      null;
   end W;

   --  A Perk or Flaw of fixed cost, taken at most Max_Times.
   procedure PF (Name : String; Of_Kind : Kind; Page : Positive; Cost : Integer;
                 Max_Times : Positive; Flags : Flag_List)
   is
      I : constant Natural := New_Item (Name, Of_Kind, Page, Flags);
   begin
      Items (I).Cost := Cost;
      Items (I).Max_Times := Max_Times;
   end PF;

   procedure Range_Flaw (Name : String; Page : Positive; Min, Max : Integer) is
      I : constant Natural := New_Item (Name, Flaw, Page, []);
   begin
      Items (I).Cost_Kind := Range_Cost;
      Items (I).Min_Cost := Min;
      Items (I).Max_Cost := Max;
   end Range_Flaw;

   procedure Unique (Name : String; Of_Kind : Kind; Page : Positive) is
      I : constant Natural := New_Item (Name, Of_Kind, Page, []);
   begin
      Items (I).Cost_Kind := User_Cost;
   end Unique;

   procedure Alias (Alias_Name, Name : String) is
   begin
      for I in 0 .. N_Items - 1 loop
         if Items (I).Name = Name then
            N_Aliases := N_Aliases + 1;
            Aliases (N_Aliases) := (To_Unbounded_String (Alias_Name), Items (I)'Access);
            return;
         end if;
      end loop;
      raise Program_Error with "no item " & Name;
   end Alias;

   procedure Abilities is
   begin
      A ("Agile", 49, [Agility]);
      A ("Armored", 49, [Armor]);
      A ("Art of Invisibility", 50, []);
      A ("Attack", 50, [Damage]);
      A ("Barrier", 51, [Second_Defense, Own_Cost]);
      A ("Beautiful", 51, []);
      A ("Charismatic", 51, []);
      A ("Combat Expert", 51, [Combat_Skill]);
      L ("Companion", 52, [No_TV], Partner);
      A ("Connected", 52, []);
      A ("Cute!", 52, []);
      A ("Dexterous", 52, []);
      A ("Dimensional Pocket", 52, []);
      A ("Endurance Reserve", 53, [Reserve]);
      A ("Evasive", 53, [Defense_Roll]);
      A ("Famous", 53, []);
      A ("Flight", 54, []);
      A ("Gear", 54, []);
      A ("Healer", 54, [Half_TV]);
      A ("Heightened Sense", 54, []);
      A ("Illusionist", 54, []);
      A ("Incorporeal Form", 55, [Third_Defense]);
      A ("Intimidating", 55, []);
      A ("Intuitive", 56, []);
      A ("Inventor", 56, []);
      A ("Invisibility", 56, []);
      A ("Iron-Willed", 56, [Will]);
      A ("Knowledge", 57, [Half_Cost]);
      A ("Life Support", 57, []);
      A ("Lucky", 57, []);
      L ("Magic, Arcane", 57, [Half_TV], Spells);
      L ("Magic, Witchcraft", 58, [Half_TV, Casts_Weaknesses], Spells);
      A ("Minions", 58, [No_TV]);
      A ("Passion", 59, []);
      A ("Perceptive", 59, []);
      A ("Performer", 59, []);
      A ("Pilot", 59, []);
      A ("Position of Power", 59, []);
      A ("Psychic", 59, []);
      A ("Quick", 60, [Defense_Roll]);
      A ("Resistance", 60, []);
      A ("Shape-Shifter", 60, []);
      A ("Sixth Sense", 61, []);
      A ("Smart", 61, []);
      A ("Spirit Medium", 61, []);
      A ("Strong", 62, [Strength]);
      A ("Telekinesis", 62, [Telekinetic]);
      A ("Teleport", 62, []);
      A ("Time Freeze", 63, []);
      A ("Tough", 63, [Health_Table]);
      L ("Transformation", 63, [], Form);
      A ("Unique Ability", 64, []);
      L ("Vehicle (Mecha)", 64, [], Machine);
      A ("Vigorous", 65, [Endurance_Table]);
      A ("Walking Arsenal", 65, []);
      A ("Wealthy", 65, []);
   end Abilities;

   procedure Weaknesses is
   begin
      W ("Absent-Minded", 66, []);
      W ("Accidental Transformation", 66, []);
      W ("Ageism", 66, []);
      W ("Airhead", 66, []);
      W ("Amnesia", 67, []);
      W ("Arrogant", 67, []);
      W ("Awkward Size", 67, []);
      W ("Bizarre Appearance", 68, []);
      W ("Clumsy", 68, [Agility]);
      W ("Code of Conduct", 68, []);
      W ("Compulsion", 69, []);
      W ("Coward", 69, []);
      W ("Crybaby", 69, []);
      W ("Dense", 69, []);
      W ("Dependency", 70, []);
      W ("Dull", 70, []);
      W ("Easily Distracted", 70, []);
      W ("Emotionless", 70, []);
      W ("Endurance Use", 70, [Cost_Up]);
      W ("Fear", 70, []);
      W ("Focus", 71, []);
      W ("Frail", 71, [Health_Tens]);
      W ("Fussy", 71, []);
      W ("Greedy", 71, []);
      W ("Guardian", 72, []);
      W ("Hatred", 72, []);
      W ("Impaired Sense", 72, []);
      W ("Impulsive", 72, []);
      W ("Ineptitude", 72, [Half_Cost]);
      W ("Infamous", 73, []);
      W ("Jittery", 73, []);
      W ("Kind-Hearted", 73, []);
      W ("Languid", 73, [Endurance_Tens]);
      W ("Lecherous", 73, []);
      W ("Limited Uses", 74, []);
      W ("Loner", 74, []);
      W ("Love Interest", 74, []);
      W ("Love Magnet", 75, []);
      W ("Mute", 75, []);
      W ("Naive", 75, []);
      W ("Nosebleeder", 75, []);
      W ("Oblivious", 76, []);
      W ("Obsession", 76, []);
      W ("Outcast", 76, []);
      W ("Overconfident", 76, []);
      W ("Pacifist", 77, []);
      W ("Poor", 77, []);
      W ("Quirk", 77, []);
      W ("Restricted Freedom", 77, []);
      W ("Rival", 77, []);
      W ("Room for Two", 78, []);
      W ("Rude", 78, []);
      W ("Secret", 78, []);
      W ("Sensitivity", 78, []);
      W ("Servitude", 78, []);
      W ("Short-Tempered", 79, []);
      W ("Shy", 80, []);
      W ("Slow", 80, [Defense_Roll]);
      W ("Soft Spot", 80, []);
      W ("Split Personality", 80, []);
      W ("Stubborn", 80, []);
      W ("Suppressed Power", 81, []);
      W ("Trigger", 81, []);
      W ("Unique Weakness", 81, []);
      W ("Unlucky", 81, []);
      W ("Vulnerability", 82, []);
      W ("Wanted", 82, []);
      W ("Weak", 82, [Strength]);
      W ("Weak-Willed", 82, [Will]);
   end Weaknesses;

   --  Costs from the Quick List (p. 90) and the headings; how often each
   --  may be taken from its own text (ova_cg_po's PLAN.md, "Perk and
   --  Flaw costs").
   procedure Perks_And_Flaws is
   begin
      PF ("Accurate", Perk, 83, 5, Unlimited, [Roll_Each]);
      PF ("Area Effect", Perk, 83, 10, Unlimited, []);
      PF ("Armor Piercing", Perk, 83, 5, Unlimited, []);
      PF ("Barrier Buster", Perk, 83, 5, 1, []);
      PF ("Blinding", Perk, 84, 20, 1, []);
      PF ("Continued Effect", Perk, 84, 10, 2, []);
      PF ("Defensive", Perk, 84, 5, Unlimited, []);
      PF ("Disarming", Perk, 84, 10, 1, []);
      PF ("Effective", Perk, 84, 5, Unlimited, [Damage_Each]);
      PF ("Fatiguing", Perk, 84, 0, 1, []);
      PF ("Impairing", Perk, 85, 10, 1, []);
      PF ("Multiple Targets", Perk, 85, 10, Unlimited, []);
      PF ("No Gesture", Perk, 85, 5, 1, []);
      PF ("Overwhelming", Perk, 85, 15, 1, []);
      PF ("Paralyzing", Perk, 85, 10, 2, []);
      PF ("Ranged", Perk, 85, 0, 1, [Ranged_Attack]);
      PF ("Ranged, Strength-Powered", Perk, 86, 5, 1, [Strength_Ranged]);
      PF ("Reach", Perk, 86, 5, Unlimited, []);
      PF ("Redirectable", Perk, 86, 5, 1, []);
      PF ("Strike Through", Perk, 86, 5, 1, []);
      PF ("Stunning", Perk, 86, 10, 1, []);
      PF ("Trap", Perk, 86, 5, 1, []);
      Unique ("Unique Perk", Perk, 86);
      PF ("Vampire", Perk, 86, 5, Unlimited, []);
      PF ("Will Attack", Perk, 86, 0, 1, [Will_Attack]);

      PF ("Activation", Flaw, 87, -10, 1, []);
      PF ("Ammunition", Flaw, 87, -5, 3, []);
      PF ("Assisted", Flaw, 87, -15, Unlimited, []);
      PF ("Backlash", Flaw, 87, -5, Unlimited, []);
      PF ("Break", Flaw, 87, -10, 1, []);
      PF ("Buildup", Flaw, 87, -5, Unlimited, []);
      Range_Flaw ("Cancel", 87, -20, 0);
      PF ("Concentration", Flaw, 87, -20, Unlimited, []);
      PF ("Delayed", Flaw, 88, -5, 1, []);
      PF ("Elaborate Gestures", Flaw, 88, -5, 1, []);
      PF ("Feather Blow", Flaw, 88, -5, 1, []);
      PF ("Finisher", Flaw, 88, -10, 1, []);
      PF ("Inaccurate", Flaw, 88, -5, Unlimited, [Roll_Each]);
      PF ("Ineffective", Flaw, 88, -5, Unlimited, [Damage_Each]);
      PF ("Low Penetration", Flaw, 88, -5, Unlimited, []);
      PF ("No Damage", Flaw, 88, -20, 1, [No_Damage_Done]);
      PF ("Open to Attack", Flaw, 88, -25, 1, []);
      PF ("Recoil", Flaw, 88, -10, 1, []);
      Range_Flaw ("Requirement", 88, -20, -5);
      PF ("Self-Only", Flaw, 88, -5, 1, []);
      Unique ("Unique Flaw", Flaw, 88);
      PF ("Unwieldy", Flaw, 89, -5, Unlimited, []);
      PF ("Weapon", Flaw, 89, -5, 1, []);
   end Perks_And_Flaws;

   --  ---- Finding items ----

   function Count (Of_Kind : Kind) return Natural is (Counts (Of_Kind));

   function Get (Of_Kind : Kind; I : Natural) return not null Item is
     (Items (First (Of_Kind) + I)'Access);

   function Find (Name : String) return Item is
   begin
      for I in 0 .. N_Items - 1 loop
         if Same_Name (To_String (Items (I).Name), Name) then
            return Items (I)'Access;
         end if;
      end loop;
      for I in 1 .. N_Aliases loop
         if Same_Name (To_String (Aliases (I).Alias), Name) then
            return Aliases (I).It;
         end if;
      end loop;
      return null;
   end Find;

   --  ---- What the window shows ----

   function Page_Text (It : Item) return String is
     ("p. " & (if It = null then "?" else Image (It.Page)));

   function Label (It : not null Item) return String is
     (To_String (It.Name) & " (" & Page_Text (It) & ")");

   function Page_Label (Name : String; Page : Positive) return String is
     (Name & " (p. " & Image (Page) & ")");

   function Label_Of (Name : String) return String is
      It : constant Item := Find (Name);
   begin
      if It /= null then
         return Label (It);
      else
         return Name & " (" & Page_Text (null) & ")";
      end if;
   end Label_Of;

   --  ---- The rulebook's small tables ----

   function Tough_Bonus (Level : Integer) return Natural is
     (if Level = 5 then 60 else 10 * Level);

   function Reserve_Bonus (Level : Integer) return Natural is (20 * Level);

   function Endurance_Use_Cost (Level : Integer) return Natural is
     (case -Level is when 0 => 0, when 1 => 5, when 2 => 10, when others => 20);

   function Spell_Cost (Magic, Ability_Level : Integer) return Natural is
     (Spell_Costs (Magic, Ability_Level));

   --  Row Magic of the spell cost table, for Abilities of level 1 to 5.
   procedure Spell_Row (Magic : Positive; A1, A2, A3, A4, A5 : Natural) is
   begin
      Spell_Costs (Magic, 1) := A1;
      Spell_Costs (Magic, 2) := A2;
      Spell_Costs (Magic, 3) := A3;
      Spell_Costs (Magic, 4) := A4;
      Spell_Costs (Magic, 5) := A5;
   end Spell_Row;

begin
   Abilities;
   Weaknesses;
   Perks_And_Flaws;
   Spell_Row (1, 20, 30, 40, 50, 60);
   Spell_Row (2, 10, 20, 30, 40, 50);
   Spell_Row (3, 5, 10, 20, 30, 40);
   Spell_Row (4, 2, 5, 10, 20, 30);
   Spell_Row (5, 0, 2, 5, 10, 20);
   Alias ("Vehicle", "Vehicle (Mecha)");
   Alias ("Ranged, Str.-Powered", "Ranged, Strength-Powered");  --  the Quick List's (p. 90)
end Ova_Cg.Rules;
