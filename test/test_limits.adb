--  Character > Limits..., the totals in red, and the preferences: the
--  rulebook and the viewer.
--
--  Needs a display: run by make test-gui, as test_window is.  The
--  limits dialog driven as the user drives it, on a new character with
--  an Attack +3 (a total of 3; 4 points under Scaled Cost, the
--  Abilities' and the net), checked in the model, in what is saved, and
--  in which total is red; then the Rulebook menu's choices, kept in a
--  preferences file in obj/ and read back.

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Check;
with FLTK.Environment;
with FLTK.Menu_Items;
with Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Rules;
with Ova_Cg.Save;
with Ova_Cg.Settings;
with Ova_Cg.Trait_Panel;
with Ova_Cg.Viewer;
with Ova_Cg.Widgets;
with Ova_Cg.Window;

procedure Test_Limits is

   use Ova_Cg;

   package Ch renames Ova_Cg.Character;
   use type FLTK.Color, Rules.Item, Settings.Window_Access, Window.Window_Access, Window.Database_Access;

   package Env renames FLTK.Environment;
   package S renames Ova_Cg.Settings;

   Prefs_Dir   : constant String := "../obj";  --  the preferences file: obj/ova_cg_ada.prefs
   Vendor      : constant String := "ova_cg_ada";
   Application : constant String := "ova_cg_ada";
   Tab         : constant Standard.Character := ASCII.HT;

   type Group_Access is access all Env.Pref_Group'Class;
   procedure Free is new Ada.Unchecked_Deallocation (Env.Database'Class, Window.Database_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Env.Pref_Group'Class, Group_Access);

   Tells, Pdf_Asks : Natural := 0;
   Pdf_Answer, Text_Answer : Unbounded_String;  --  Null: cancelled
   C     : Ch.Character_Access;
   Prefs : Window.Database_Access;
   Root  : Group_Access;
   OK    : Boolean;

   procedure Tell (Text : String) is
   begin
      Tells := Tells + 1;
      Ada.Text_IO.Put_Line ("    told: " & Text);
   end Tell;

   function Ask (Question : String) return Window.Answer is
      pragma Unreferenced (Question);
   begin
      return Window.Discard;
   end Ask;

   function Choose_Pdf (P : out Unbounded_String) return Boolean is
   begin
      Pdf_Asks := Pdf_Asks + 1;
      P := Pdf_Answer;
      return P /= Null_Unbounded_String;
   end Choose_Pdf;

   function Ask_Text (Prompt : String; Text : in out Unbounded_String) return Boolean is
      pragma Unreferenced (Prompt);
   begin
      if Text_Answer = Null_Unbounded_String then
         return False;
      end if;
      Text := Text_Answer;
      return True;
   end Ask_Text;

   function Has (Text : String; Part : String) return Boolean is
     (Ada.Strings.Fixed.Index (Text, Part) > 0);

   function Saved return String is (Save.To_Text (Window.The_Character));

   function Red (Which : Window.Sheet_Number) return Boolean is
     (Window.Number (Which).Shown.Get_Text_Color = FLTK.Red_Color);

   --  Which of the Abilities' levels, the Total, the points and the
   --  Abilities' points are red: "ATPa" for all four, "-T--" for the
   --  Total alone.
   function Reds return String is
      R : String := "----";
   begin
      if Red (Window.Ability_Levels_Number) then R (1) := 'A'; end if;
      if Red (Window.Total_Number) then R (2) := 'T'; end if;
      if Red (Window.Points_Number) then R (3) := 'P'; end if;
      if Red (Window.Ability_Points_Number) then R (4) := 'a'; end if;
      return R;
   end Reds;

   function Reds_Are (Want : String) return Boolean is (Reds = Want);

   --  Sets check box B, as the user clicks it.
   procedure Turn (B : S.Check_Access; On : Boolean) is
   begin
      B.Set_State (if On then Widgets.Buttons.On else Widgets.Buttons.Off);
      B.Do_Callback;
   end Turn;

   --  Sets spinner Sp to V, as the user types it.
   procedure Spin (Sp : Widgets.Spinner_Access; V : Integer) is
   begin
      Sp.Set_Value (Long_Float (V));
      Sp.Do_Callback;
   end Spin;

   --  Chooses Name in P's Choice, as the user does.
   procedure Pick (P : Trait_Panel.Trait_Panel_Access; Name : String) is
      It : constant Rules.Item := Rules.Find (Name);
   begin
      pragma Assert (It /= null);
      Widgets.Choose (P.all, It);
      P.Choice.Do_Callback;
   end Pick;

   procedure Add_To (P : Trait_Panel.Trait_Panel_Access; Name : String; Level : Integer) is
   begin
      Pick (P, Name);
      P.Spinner.Set_Value (Long_Float (Level));
      P.Text.Set_Value ("");
      P.Add_Button.Do_Callback;
   end Add_To;

   procedure Add_Ability (Name : String; Level : Integer) is
   begin
      Add_To (Window.Abilities, Name, Level);
   end Add_Ability;

   procedure Add_Weakness (Name : String; Level : Integer) is
   begin
      Add_To (Window.Weaknesses, Name, Level);
   end Add_Weakness;

   --  Whether one of P's lines is Head, a tab, Points and a tab if any
   --  are given, and Name's page.
   function Listed (P : Trait_Panel.Trait_Panel_Access; Head, Points, Name : String) return Boolean is
      Want : constant String :=
        Head & Tab & (if Points /= "" then Points & Tab else "") & Rules.Page_Text (Rules.Find (Name));
   begin
      for I in 1 .. P.Browser.Number_Of_Lines loop
         if P.Browser.Get_Line_Text (I) = Want then
            return True;
         end if;
      end loop;
      return False;
   end Listed;

   function Value (Sp : Widgets.Spinner_Access) return Integer is (Widgets.Spin_Value (Sp.all));

   procedure Pick_Item (Item : Window.Item_Index) is
   begin
      Window.Bar.Picked (FLTK.Menu_Items.Menu_Item (Window.Bar.Item (Item).Data.all));
   end Pick_Item;

   --  A new character with Attack +3, unmodified; Limits... opened.
   --  ova_cg_po adopts the character it has; here the window frees the
   --  characters it puts away, so it adopts a copy.
   procedure Fresh is
   begin
      Pick_Item (Window.New_Item);
      Add_Ability ("Attack", 3);
      Window.Adopt (Ch.One (Save.Copy (Window.The_Character)), "");
      C := Window.The_Character;
      Pick_Item (Window.Limits_Item);
   end Fresh;

   function Viewer_Is (Name : String) return Boolean is (Viewer.Name (Window.Viewer) = Name);

   function Modified return Boolean is (Has (Window.Main.Get_Label, " *"));

   function Warned (Text : String) return Boolean is
   begin
      for I in 1 .. Window.Warnings.Number_Of_Lines loop
         if Has (Window.Warnings.Get_Line_Text (I), Text) then
            return True;
         end if;
      end loop;
      return False;
   end Warned;

   procedure Open_Prefs is
   begin
      Prefs := new Env.Database'(Env.Forge.From_Filesystem (Prefs_Dir, Vendor, Application));
      Root := new Env.Pref_Group'Class'(Env.Forge.Root (Env.Database (Prefs.all)));
   end Open_Prefs;

   procedure Close_Prefs is
   begin
      Free (Root);
      Free (Prefs);
   end Close_Prefs;

   function Kept (Name : String) return String is (Root.Get (Name, ""));

   function Total return Integer is (Calc.Value (C.Total));

begin
   Window.Build;
   Window.Tell := Tell'Unrestricted_Access;
   Window.Ask := Ask'Unrestricted_Access;
   Window.Choose_Pdf := Choose_Pdf'Unrestricted_Access;
   Window.Ask_Text := Ask_Text'Unrestricted_Access;
   Window.Main.Show;
   Window.Main.Wait_For_Expose;
   OK := FLTK.Check;
   Check.Check (Window.Bar.Item (Window.Limits_Item).Get_Label = "&Limits...", "Character > Limits...");

   --  ---- Limits... ----
   Fresh;
   Check.Check (S.Dialog /= null and then not S.Base_Zero.Is_On and then not S.Power_Ceiling.Is_On
                and then not S.Starting_Levels.Is_On and then not S.Scaled_Cost.Is_On
                and then not S.Half_Cost.Is_On and then not S.Combined.Is_On,
                "a new character: no limits");
   Check.Check (Value (S.Base_Zero_Range) = 5 and then Value (S.Starting) = 5 and then Value (S.Ceiling) = 15
                and then not S.Base_Zero_Range.Is_Active and then not S.Ceiling.Is_Active
                and then not S.Starting.Is_Active and then not S.Half_Cost.Is_Active,
                "their numbers p. 21's example, inactive; half cost inactive with none of its rules");
   Check.Check (Total = 3 and then Reds_Are ("----") and then not Modified,
                "Attack +3: a total of 3, nothing red");

   Turn (S.Base_Zero, True);
   Check.Check (C.Options.Base_Zero and then C.Options.Base_Zero_Range = 5 and then C.Has_Options
                and then S.Base_Zero_Range.Is_Active and then S.Half_Cost.Is_Active and then Modified
                and then Has (Saved, "base-zero: 5") and then Reds_Are ("----"),
                "Base Zero on: its range 5, saved, the title marked; 3 within it");
   Spin (S.Base_Zero_Range, 2);
   Check.Check (C.Options.Base_Zero_Range = 2 and then Reds_Are ("-T--") and then Warned ("Base Zero")
                and then Has (Saved, "base-zero: 2"),
                "range 2: the Total red, and the warning");
   Spin (S.Base_Zero_Range, 3);
   Check.Check (Reds_Are ("----") and then not Warned ("Base Zero"), "range 3: not red");
   Turn (S.Scaled_Cost, True);
   Check.Check (C.Options.Scaled_Cost and then Calc.Value (C.Points) = 4
                and then Window.Number (Window.Points_Number).Is_Visible and then Reds_Are ("--P-")
                and then Has (Saved, "scaled-cost: true"),
                "Scaled Cost: 4 points, shown, beyond 3: the points red, not the Total");
   Check.Check (Calc.Value (C.Ability_Points) = 4
                and then Window.Number (Window.Ability_Points_Number).Is_Visible,
                "and the Abilities' 4 points shown");
   Turn (S.Power_Ceiling, True);
   Spin (S.Ceiling, 3);
   Check.Check (Reds_Are ("--Pa") and then Warned ("Power Ceiling"),
                "Power Ceiling 3 on Scaled Cost: the Abilities' points red, not their levels");
   Spin (S.Ceiling, 15);
   Turn (S.Power_Ceiling, False);
   Turn (S.Scaled_Cost, False);
   Turn (S.Base_Zero, False);
   Check.Check (not C.Options.Base_Zero and then not S.Base_Zero_Range.Is_Active
                and then not S.Half_Cost.Is_Active and then Value (S.Base_Zero_Range) = 3
                and then Reds_Are ("----") and then not Has (Saved, "base-zero"),
                "Base Zero off: its number kept, inactive, not saved");

   Turn (S.Power_Ceiling, True);
   Check.Check (C.Options.Power_Ceiling and then C.Options.Ceiling = 15 and then Reds_Are ("----")
                and then Has (Saved, "power-ceiling: 15"),
                "Power Ceiling 15: 3 under it");
   Spin (S.Ceiling, 2);
   Check.Check (Reds_Are ("A---") and then Warned ("Power Ceiling"),
                "Power Ceiling 2: the Abilities red, and the warning");
   Turn (S.Power_Ceiling, False);
   Turn (S.Starting_Levels, True);
   Check.Check (C.Options.Starting_Levels and then C.Options.Starting = 5 and then Reds_Are ("----")
                and then Has (Saved, "starting-levels: 5"),
                "5 starting levels: 3 within them");
   Spin (S.Starting, 2);
   Check.Check (Reds_Are ("A---") and then Warned ("starting levels"), "2 starting levels: the Abilities red");
   Turn (S.Starting_Levels, False);

   Add_Ability ("Knowledge", 3);
   Turn (S.Power_Ceiling, True);
   Turn (S.Half_Cost, True);
   Check.Check (C.Options.Half_Cost_Knowledge and then Calc.Value (C.Ability_Levels) = 5
                and then Has (Saved, "half-cost-knowledge: true"),
                "half cost: Knowledge +3 counts 2 (p. 57)");
   Turn (S.Power_Ceiling, False);
   Check.Check (C.Options.Half_Cost_Knowledge and then not S.Half_Cost.Is_Active
                and then Calc.Value (C.Ability_Levels) = 6,
                "with none of its rules: kept, inactive, and Knowledge counts 3");
   Turn (S.Combined, True);
   Check.Check (C.Options.Combined_Effectiveness and then Has (Saved, "combined-effectiveness: true"),
                "Combined Effectiveness on, saved");
   Check.Check (Listed (Window.Abilities, "+3 Attack", "", "Attack"),
                "no points in the lists without Scaled Cost");
   Turn (S.Scaled_Cost, True);
   Check.Check (Listed (Window.Abilities, "+3 Attack", "4 pts", "Attack")
                and then Listed (Window.Abilities, "+3 Knowledge", "2 pts", "Knowledge"),
                "Scaled Cost: each Ability's points listed, Knowledge +3's halved");
   Add_Weakness ("Weak", -1);
   Check.Check (Listed (Window.Weaknesses, "-1 Weak", "1 pt", "Weak"), "and each Weakness's");
   Turn (S.Scaled_Cost, False);
   Check.Check (Listed (Window.Abilities, "+3 Attack", "", "Attack")
                and then Listed (Window.Weaknesses, "-1 Weak", "", "Weak"),
                "Scaled Cost off: the points gone from the lists");

   S.Cancel_Button.Do_Callback;
   Check.Check (S.Dialog = null and then not C.Has_Options and then not C.Options.Half_Cost_Knowledge
                and then not C.Options.Combined_Effectiveness and then not C.Options.Power_Ceiling
                and then not Has (Saved, "options:") and then Reds_Are ("----")
                and then Calc.Value (C.Ability_Levels) = 6 and then not Modified,
                "Cancel: no limits again, nothing saved, the title unmarked");

   Fresh;
   Turn (S.Base_Zero, True);
   Spin (S.Base_Zero_Range, 1);
   S.OK_Button.Do_Callback;
   Check.Check (S.Dialog = null and then C.Options.Base_Zero and then Has (Saved, "base-zero: 1")
                and then Modified and then Reds_Are ("-T--"),
                "OK: kept, saved, the title marked, the Total red");
   Pick_Item (Window.Limits_Item);
   Check.Check (S.Base_Zero.Is_On and then Value (S.Base_Zero_Range) = 1 and then S.Base_Zero_Range.Is_Active,
                "opened again: as left");
   Turn (S.Base_Zero, False);
   S.Dialog.Do_Callback;  --  the window's close button
   Check.Check (S.Dialog = null and then C.Options.Base_Zero and then Reds_Are ("-T--") and then Modified,
                "closed by its close button: as Cancel, the title still marked from before");

   Pick_Item (Window.New_Item);
   C := Window.The_Character;
   C.Has_Options := True;  --  as a file with an empty options: block loads
   Pick_Item (Window.Limits_Item);
   Turn (S.Base_Zero, True);
   Turn (S.Base_Zero, False);
   Check.Check (C.Has_Options and then Has (Saved, "options:"),
                "an empty options: block, changed and changed back: kept");
   Turn (S.Combined, True);
   Turn (S.Combined, False);
   Turn (S.Base_Zero, True);
   S.OK_Button.Do_Callback;
   OK := Window.Load ("data/Sheet.yaml");
   Pick_Item (Window.Limits_Item);
   Check.Check (OK and then not S.Base_Zero.Is_On and then S.Power_Ceiling.Is_On and then Value (S.Ceiling) = 30
                and then S.Starting_Levels.Is_On and then Value (S.Starting) = 20 and then S.Half_Cost.Is_On
                and then S.Half_Cost.Is_Active and then not S.Scaled_Cost.Is_On,
                "Sheet's: Power Ceiling 30, 20 starting levels, half cost");
   S.Cancel;

   --  ---- The rulebook and the viewer, kept ----
   Open_Prefs;
   Root.Clear;
   Window.Use_Preferences (Prefs);
   Check.Check (Window.Saved_Rulebook = "", "no rulebook kept");
   Pdf_Answer := To_Unbounded_String ("data/Sheet.yaml");  --  any file stands for the PDF
   Pick_Item (Window.Choose_Pdf_Item);
   Check.Check (Pdf_Asks = 1 and then To_String (Window.Rulebook_Option) = Window.Saved_Rulebook
                and then Has (Kept ("rulebook"), "/test/data/Sheet.yaml")
                and then Kept ("rulebook") (Kept ("rulebook")'First) = '/',
                "Choose PDF...: used from now on, and kept, absolute");

   Text_Answer := To_Unbounded_String ("evince");
   Pick_Item (Window.Viewer_Item);
   Check.Check (Viewer_Is ("evince") and then Kept ("viewer") = "evince", "Viewer...: evince, kept");
   Text_Answer := To_Unbounded_String ("cat %f");
   Pick_Item (Window.Viewer_Item);
   Check.Check (Viewer_Is ("cat %f") and then Kept ("viewer") = "cat %f", "a command, kept");
   Tells := 0;
   Text_Answer := To_Unbounded_String ("nonsense");
   Pick_Item (Window.Viewer_Item);
   Check.Check (Viewer_Is ("cat %f") and then Kept ("viewer") = "cat %f" and then Tells = 1,
                "not a viewer: said so, nothing changed");
   Text_Answer := Null_Unbounded_String;
   Pick_Item (Window.Viewer_Item);
   Check.Check (Viewer_Is ("cat %f"), "cancelled: nothing changed");

   --  The window's group outlives the database freed here: fltkada
   --  counts a database's groups, and frees it after the last.
   Close_Prefs;
   Open_Prefs;
   Viewer.Default (Window.Viewer);
   Window.Rulebook_Option := Null_Unbounded_String;
   Window.Use_Preferences (Prefs);
   Check.Check (Viewer_Is ("cat %f") and then Has (Window.Saved_Rulebook, "/test/data/Sheet.yaml"),
                "read back on the next run: the viewer and the rulebook");
   Viewer.Default (Window.Viewer);
   Window.Viewer_Option := True;
   Window.Use_Preferences (Prefs);
   Check.Check (not Viewer_Is ("cat %f"), "--viewer's wins over the one kept");
   Window.Viewer_Option := False;
   Root.Set ("viewer", "nonsense");
   OK := Viewer.Parse ("mupdf", Window.Viewer);
   Window.Use_Preferences (Prefs);
   Check.Check (Viewer_Is ("mupdf"), "a viewer kept that isn't one: ignored");

   --  Not found: asked for once, then opened with it.
   OK := Viewer.Parse ("true %f %p", Window.Viewer);
   Window.Rulebook_Option := To_Unbounded_String ("no/such/rulebook.pdf");
   Pdf_Asks := 0;
   Tells := 0;
   Pdf_Answer := Null_Unbounded_String;
   Pick_Item (Window.Rulebook_Item);
   Check.Check (Pdf_Asks = 1 and then Tells = 1,
                "the rulebook not found: asked for, and cancelled, said where it isn't");
   Pdf_Answer := To_Unbounded_String ("data/Sheet.yaml");
   Tells := 0;
   Pick_Item (Window.Rulebook_Item);
   Check.Check (Pdf_Asks = 2 and then Tells = 0
                and then Has (To_String (Window.Rulebook_Option), "/test/data/Sheet.yaml")
                and then Has (Kept ("rulebook"), "/test/data/Sheet.yaml"),
                "chosen: opened, and kept");
   Pick_Item (Window.Rulebook_Item);
   Check.Check (Pdf_Asks = 2, "found the next time: not asked again");

   Window.Use_Preferences (null);
   Close_Prefs;
   Window.Close;
   --  fltkada counts neither the widgets nor the databases open, as
   --  pofltk does: the window's widgets and this test's database are
   --  forgotten, and valgrind-headless finds none of them leaked.
   Check.Check (Window.Main = null and then S.Dialog = null and then Prefs = null and then Root = null,
                "every widget and database closed");
   Check.Summary;
end Test_Limits;
