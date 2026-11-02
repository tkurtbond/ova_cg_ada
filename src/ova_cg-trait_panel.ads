--  A list of Abilities or Weaknesses and its editor: a character's, a
--  form's, a partner's.
--
--  ova_cg_po's PLAN.md, "The window": the Abilities and the Weaknesses
--  are each a browser of lines ("+3 Attack (Kaze Satsujinsha)", a tab,
--  "p. 50"; under Scaled Cost, its points between: "+3 Attack", "4
--  pts", "p. 50") with Ova_Cg.Widgets.Panel's controls.  The same panel
--  edits the character's own (Ova_Cg.Window), a Transformation's form,
--  and a Companion's or Vehicle's (Ova_Cg.Linked_Dialog): its list is a
--  sheet's traits, or, given an owner, the owner's form.
--
--  After each change the panel recomputes Top, the character the list
--  belongs to, so what is shown is Ova_Cg.Calc's; then calls Changed,
--  the window's or the dialog's.  Selected tells which trait the user
--  chose (null after Remove), for the controls that act on one.
--
--  A Boss's own Abilities (not a form's, not a partner's) offer the Boss
--  Abilities, which have no level: the file's level: is always 1, and
--  the Spinner is off while one is chosen.

private with Ada.Containers.Vectors;
with Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Rules;
with Ova_Cg.Widgets;

package Ova_Cg.Trait_Panel is

   type Trait_Panel is new Widgets.Panel with private;
   type Trait_Panel_Access is access all Trait_Panel'Class;

   type Selected_Handler is access procedure (P : in out Trait_Panel'Class; T : Character.Trait);
   type Changed_Handler is access procedure (P : in out Trait_Panel'Class);

   --  Shows a message: the window's.
   type Tell_Handler is access procedure (Text : String);
   Tell : Tell_Handler;

   --  What the window or dialog sets.
   procedure Set_Handlers (P : in out Trait_Panel'Class; Selected : Selected_Handler;
                           Changed : Changed_Handler);

   --  Whose traits are listed, or, if Owner isn't null, whose form; and
   --  the character recomputed after a change.
   function Sheet (P : Trait_Panel'Class) return Calc.Sheet;
   function Owner (P : Trait_Panel'Class) return Calc.Trait;
   function Top (P : Trait_Panel'Class) return Character.Character_Access;

   --  The names' column's width, as Fit set it.
   function Name_W (P : Trait_Panel'Class) return Integer;

   --  The trait on line Line (from 1); null for none.
   function Trait_At (P : Trait_Panel'Class; Line : Natural) return Character.Trait;

   --  The selected trait; null for none.
   function Selected (P : Trait_Panel'Class) return Character.Trait;

   --  Whether the lines show Scaled Cost's points: a sheet's own traits
   --  under it, not a form's, which no total counts (p. 63).
   function Shows_Points (P : Trait_Panel'Class) return Boolean;

   --  Sets the columns' widths from the browser's width, as it is now:
   --  the name's column takes what the points and the page leave.
   procedure Fit (P : in out Trait_Panel'Class);

   --  After the Choice changes: a Boss Ability's Spinner is 1, and off.
   overriding procedure Chosen (P : in out Trait_Panel);

   overriding procedure Fill (P : in out Trait_Panel);
   overriding procedure Load (P : in out Trait_Panel; Line : Positive);
   overriding function Add (P : in out Trait_Panel) return Natural;

   --  A name the tables don't have stays, if none is chosen.
   overriding function Change (P : in out Trait_Panel; Line : Positive) return Natural;

   --  Frees the trait removed, once Selected is told it's gone.
   overriding function Remove (P : in out Trait_Panel; Line : Positive) return Boolean;

   overriding procedure Changed (P : in out Trait_Panel);

   --  Lists Sheet's traits (Owner null) or Owner's form, recomputing Top
   --  after a change; nothing selected.
   procedure Show (P : in out Trait_Panel'Class; Sheet : Calc.Sheet; Owner : Calc.Trait;
                   Top : Character.Character_Access);

   --  Opens a panel at X, Y, W wide, its browser H high, in the current
   --  group, for Kind's traits: levels +1 to +5 for an Ability, -1 to
   --  -3 for a Weakness.  Title as Widgets.Open_Panel's.
   function Open (X, Y, W, H : Integer; Kind : Rules.Kind; Title : String)
     return not null Trait_Panel_Access;

   --  Closes P (Widgets.Close_Panel) and frees it; P null after.
   procedure Free (P : in out Trait_Panel_Access);

private

   package Trait_Vectors is new Ada.Containers.Vectors (Positive, Character.Trait, Character."=");

   type Trait_Panel is new Widgets.Panel with record
      Sheet    : Calc.Sheet;
      Owner    : Calc.Trait;
      Top      : Character.Character_Access;
      Shown    : Trait_Vectors.Vector;  --  Shown (I): line I's
      Name_W   : Integer := 0;
      Selected : Selected_Handler;
      Changed  : Changed_Handler;
   end record;

end Ova_Cg.Trait_Panel;
