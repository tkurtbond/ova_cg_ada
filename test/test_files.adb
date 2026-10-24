--  Ova_Cg.Character and Ova_Cg.Save: loading, saving, and loading
--  again.
--
--  ova_cg_po's PLAN.md, "Files".  Each fixture, every character in it,
--  is loaded, saved into ../obj/files/ (for test/files.sh, which formats
--  both with ova_fmt and compares), and loaded again: the second load
--  must give the same YAML, and no notices, since the copy's overrides:
--  keys list every number kept as an override.  The notices are the
--  numbers the first load kept as overrides, those the file differs
--  from the rules on without listing them.  Then the files that can't
--  be loaded, a failed save, and a character with text plain YAML can't
--  hold.  Needs no display.
--
--  Each fixture's Markdown sheet (Ova_Cg.Markdown), its characters'
--  in order, is saved beside its copy as NAME.md, for files.sh to
--  compare with ova_fmt -M's of the copy; and its inline paragraphs
--  (Markdown.Inline), as NAME.inline.md, for ova_fmt -i's.

with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Check;
with Libfyaml.Documents;
with Libfyaml.Nodes;
with Ova_Cg.Calc;
with Ova_Cg.Character;
with Ova_Cg.Markdown;
with Ova_Cg.Save;
with Ova_Fmt.Entities;

procedure Test_Files is

   package Calc renames Ova_Cg.Calc;
   package Ch renames Ova_Cg.Character;
   package Markdown renames Ova_Cg.Markdown;
   package Save renames Ova_Cg.Save;
   package E renames Ova_Fmt.Entities;
   package Nodes renames Libfyaml.Nodes;

   use type Ch.Character_Access;
   use type Ch.Slot;

   Data_Dir  : constant String := "data/";
   Saved_Dir : constant String := "../obj/files/";

   LF : constant Character := ASCII.LF;

   function L (Name, What : String) return String is (Name & ": " & What);

   function Path (Dir, Name : String) return String is (Dir & Name & ".yaml");

   --  Whether S holds Part.
   function Holds (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);

   --  Whether S holds the line Line, ending in a line feed.
   function Holds_Line (S, Line : String) return Boolean is (Holds (S, Line & LF));

   procedure Say (S : String) is
   begin
      Ada.Text_IO.Put_Line ("    " & S);
   end Say;

   procedure Show_Notices is
   begin
      for N of Ch.Notices loop
         Say (To_String (N));
      end loop;
   end Show_Notices;

   function Notice_Count return Natural is (Natural (Ch.Notices.Length));

   procedure Free (C : in out Ch.Character_Access) is
      S : Calc.Sheet := Calc.Sheet (C);
   begin
      if C /= null then
         Calc.Free (S);
         C := null;
      end if;
   end Free;

   --  Deletes the file at Path, if there is one.
   procedure Remove (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Remove;

   --  Loads Name, every character in it, saves them, loads the copy;
   --  Want: the notices expected.
   procedure Round_Trip (Name : String; Want : Natural) is
      From  : constant String := Path (Data_Dir, Name);
      Saved : constant String := Path (Saved_Dir, Name);
      C, C2 : Ch.Characters;
      Msg   : Unbounded_String;
      Ok    : Boolean;
      N     : Natural;
   begin
      Ok := Ch.Load_All (From, C, Msg);
      Check.Check (Ok, L (Name, "loaded"));
      if not Ok then
         Say (To_String (Msg));
         return;
      end if;
      N := Notice_Count;
      Check.Check (N = Want, L (Name, "notices"));
      if N /= Want or else N > 0 then
         Show_Notices;
      end if;
      declare
         Text : constant String := Save.All_To_Text (C);
      begin
         Check.Check (Save.Save_All (C, Saved, Msg), L (Name, "saved"));
         declare
            Md     : constant String := Saved_Dir & Name & ".md";
            Imd    : constant String := Saved_Dir & Name & ".inline.md";
            Sheet  : Unbounded_String;
            Inline : Unbounded_String;
            Part   : Unbounded_String;
         begin
            Ok := True;
            for X of C loop
               Ok := Markdown.Sheet (X, Part) and then Ok;
               Append (Sheet, Part);
               Ok := Markdown.Inline (X, Part) and then Ok;
               Append (Inline, Part);
            end loop;
            --  so files.sh never compares a file from before
            Remove (Md);
            Remove (Imd);
            Check.Check (Ok and then Markdown.Save (To_String (Sheet), Md, Msg),
                         L (Name, "its Markdown sheet saved"));
            Check.Check (Markdown.Save (To_String (Inline), Imd, Msg),
                         L (Name, "its inline paragraphs saved"));
         end;
         Ok := Ch.Load_All (Saved, C2, Msg);
         Check.Check (Ok, L (Name, "the copy loaded"));
         if Ok then
            Check.Check (Notice_Count = 0, L (Name, "the copy has no notices: it lists its overrides"));
            if Notice_Count > 0 then
               Show_Notices;
            end if;
            Check.Check (Text = Save.All_To_Text (C2), L (Name, "the copy saves the same"));
            Ch.Free_All (C2);
         end if;
      end;
      Ch.Free_All (C);
   end Round_Trip;

   procedure Fixtures is
   begin
      --  The samples: every number is the rules', given the keys the
      --  fixtures carry (Ai's attacks made with Telekinesis, Fukiko's
      --  sheet shown transformed, Miho's Mode SP made transformed), but
      --  the book's two rulings, Braun's ROLL and Natsuki's Stiletto
      --  Kick's DX, which their overrides: list.  Sheet uses every key;
      --  Defenses and Wisp, the three Defense values, and Incorporeal
      --  Form's alone.
      Round_Trip ("Ai", 0); Round_Trip ("Auren", 0); Round_Trip ("Braun", 0); Round_Trip ("Cora", 0);
      Round_Trip ("Daisuke", 0); Round_Trip ("Fukiko", 0); Round_Trip ("Karis", 0); Round_Trip ("Miho", 0);
      Round_Trip ("Natsuki", 0); Round_Trip ("Raine", 0); Round_Trip ("Shou", 0); Round_Trip ("Yuu", 0);
      Round_Trip ("Sheet", 0); Round_Trip ("Defenses", 0); Round_Trip ("Wisp", 0);
      --  ova_fmt's own, for its formats: their numbers were never the
      --  rules', so they come back as overrides.
      Round_Trip ("Escaping", 5); Round_Trip ("Unsorted", 8); Round_Trip ("Vehicle", 5);
      --  The Sample NPCs: a Secondary NPC's sheet is a Companion's
      --  (npc-type:), so Dr. Tomori's and Jiro's numbers are the rules';
      --  Nazo's and Shadowman's single Defense is their best, as the
      --  book prints it, but Nazo's TV is the book's own.  Acacia and
      --  Zurkrieg hold more than one entity (Several); Acacia's notice
      --  is its Lock Heaven's Door's END.
      Round_Trip ("Acacia", 1); Round_Trip ("Zurkrieg", 0);
      Round_Trip ("Ancel", 0); Round_Trip ("Dr-Tomori", 0); Round_Trip ("Jiro", 0); Round_Trip ("Nazo", 1);
      Round_Trip ("Saspar", 0); Round_Trip ("Shadowman", 0);
      --  The NPC Fragments: no combat: block, so nothing to compare.
      Round_Trip ("Beat-Cop", 0); Round_Trip ("Cat-Burglar", 0); Round_Trip ("Dragon", 0);
      Round_Trip ("Ebullient-Club-President", 0); Round_Trip ("Ghosts", 0); Round_Trip ("Goblin", 0);
      Round_Trip ("GPL-Agents", 0); Round_Trip ("Indebted-Yakuza", 0); Round_Trip ("Magical-Fairies", 0);
      Round_Trip ("Ninja", 0); Round_Trip ("Oni", 0); Round_Trip ("Sentry-Bots", 0);
      Round_Trip ("Shady-Teacher", 0); Round_Trip ("Shinto-Priest", 0); Round_Trip ("Snobbish-Upperclassman", 0);
      Round_Trip ("Spider-Tank", 0); Round_Trip ("Thugs", 0); Round_Trip ("Venomous-Killer", 0);
      Round_Trip ("Weathered-Salaryman", 0); Round_Trip ("Weird-Exchange-Student", 0);
      Round_Trip ("Wild-Beast", 0); Round_Trip ("Zombies", 0);
      --  ova_fmt's two of two Fragments each, and the generator's own of
      --  two YAML documents.
      Round_Trip ("Fragment", 0); Round_Trip ("Options", 0); Round_Trip ("two-documents", 0);
   end Fixtures;

   --  Whether Cs are N characters named by Names, "|" between them.
   function Named (Cs : Ch.Characters; N : Natural; Names : String) return Boolean is
      S : Unbounded_String;
   begin
      if Natural (Cs.Length) /= N then
         return False;
      end if;
      for C of Cs loop
         if S /= Null_Unbounded_String then
            Append (S, "|");
         end if;
         Append (S, C.Name);
      end loop;
      return S = Names;
   end Named;

   --  Files of several characters (ova_cg_po's PLAN.md, "Several
   --  characters in a file"): every one loaded, in order, each its
   --  notices, and saved in that order; Load still takes exactly one.
   procedure Several is
      Cs, Cs2 : Ch.Characters;
      C       : Ch.Character_Access;
      Msg     : Unbounded_String;
      Ok      : Boolean;
   begin
      Ok := Ch.Load_All ("data/Acacia.yaml", Cs, Msg);
      Check.Check (Ok and then Named (Cs, 3, "Acacia|Sazza and Fraz|High Fructo Cezar"),
                   "Acacia.yaml: her and her two demons, in the file's order");
      Check.Check (Notice_Count = 1 and then Holds (To_String (Ch.Notices.First_Element),
                                                     "Acacia: Lock Heaven's Door: END"),
                   "its one notice names its character");
      Ch.Free_All (Cs);
      Ok := Ch.Load_All ("data/two-documents.yaml", Cs, Msg);
      Check.Check (Ok and then Named (Cs, 2, "First Of Two|Second Of Two"),
                   "two-documents.yaml: a character from each document");
      Ok := Save.Save_All (Cs, "../obj/two-documents.yaml", Msg)
        and then Ch.Load_All ("../obj/two-documents.yaml", Cs2, Msg);
      declare
         Text : constant String := Save.All_To_Text (Cs);
      begin
         Check.Check (Ok and then Named (Cs2, 2, "First Of Two|Second Of Two")
                      and then Ada.Strings.Fixed.Index (Text (Text'First + 1 .. Text'Last), "---") = 0,
                      "saved as one document, the two in order");
      end;
      Ch.Free_All (Cs);
      Ch.Free_All (Cs2);
      Ok := Ch.Load_All ("data/Zurkrieg.yaml", Cs, Msg);
      Check.Check (Ok and then Named (Cs, 2, "Zurkrieg|Men in Black") and then Cs (1).Has_Combat
                   and then Cs (2).Is_Fragment and then not Cs (2).Has_Combat and then Notice_Count = 0,
                   "Zurkrieg.yaml: him, with combat stats, and his Men in Black, a Fragment; no notices");
      Ch.Free_All (Cs);
      Ok := Ch.Load ("data/Zurkrieg.yaml", C, Msg);
      Check.Check (not Ok and then C = null and then Holds (To_String (Msg), "holds 2 characters, not one"),
                   "Load, for one character, refuses it, saying how many it holds");
   end Several;

   --  A file that can't be loaded: Msg must hold Want.
   procedure Refused (From, Want, What : String) is
      C     : Ch.Character_Access;
      Msg   : Unbounded_String;
      Ok    : Boolean;
      Found : Boolean;
   begin
      Ok := Ch.Load (From, C, Msg);
      Found := Holds (To_String (Msg), Want);
      Check.Check (not Ok and then C = null and then Found, What & ": refused, saying " & Want);
      if not Found then
         Say ("said: " & To_String (Msg));
      end if;
      Free (C);
   end Refused;

   procedure Errors is
      C   : Ch.Character_Access;
      Msg : Unbounded_String;
      Ok  : Boolean;
   begin
      Refused ("data/Broken.yaml", "level", "Broken.yaml");
      Refused ("data/no-such-file.yaml", "no-such-file.yaml", "a missing file");
      C := Ch.New_Character;
      C.Name := To_Unbounded_String ("Nobody");
      Ok := Save.Save (C, "../obj/no-such-dir/x.yaml", Msg);
      Check.Check (not Ok and then Msg /= Null_Unbounded_String, "a save to a missing directory fails, with a message");
      Free (C);
   end Errors;

   --  Name, loaded, saved: its text holds the line Want.
   procedure Saves_As (Name, Want : String) is
      C   : Ch.Character_Access;
      Msg : Unbounded_String;
   begin
      if Ch.Load (Path (Data_Dir, Name), C, Msg) then
         declare
            Text : constant String := Save.To_Text (C);
         begin
            Check.Check (Holds_Line (Text, Want), L (Name, "saved with " & Want));
            if not Holds_Line (Text, Want) then
               Ada.Text_IO.Put (Text);
            end if;
         end;
         Free (C);
      else
         Check.Check (False, L (Name, "saved with " & Want));
      end if;
   end Saves_As;

   --  Up to three Defense values (ova_cg_po's PLAN.md, Phase 11): one
   --  where the rules give more is the best; two, the Defense and the
   --  first alternate; an overridden alternate the character doesn't
   --  have is saved where it is read back.
   procedure Defenses is
      C, C2 : Ch.Character_Access;
      Msg   : Unbounded_String;
      Ok    : Boolean;
      Which : Ch.Slot;
   begin
      Round_Trip ("defense-best", 0);
      Saves_As ("defense-best", "defense: 4");
      Round_Trip ("defense-best-differs", 1);
      Saves_As ("defense-best-differs", "defense: 3");
      Ok := Ch.Load ("data/defense-best-differs.yaml", C, Msg);
      Check.Check (Ok and then Calc.Overridden (C.Incorporeal) and then not Calc.Overridden (C.Barrier)
                   and then not Calc.Overridden (C.Defense)
                   and then Ch.Single_Defense (C, Which) and then Which = Ch.Incorporeal_Slot,
                   "defense-best-differs: read as Incorporeal Form's, the best by the rules, and saved as one");
      Free (C);
      Round_Trip ("defense-two", 0);
      Saves_As ("defense-two", "defense: 2/3/4");

      --  One value, but another overridden since: all of them saved.
      Ok := Ch.Load ("data/defense-best.yaml", C, Msg);
      if Ok then
         Calc.Override (C.Defense, 3, False, False);
         Ch.Recompute (C);
      end if;
      Check.Check (Ok and then not Ch.Single_Defense (C, Which)
                   and then Holds_Line (Save.To_Text (C), "defense: 3/4/4")
                   and then Holds_Line (Save.To_Text (C), "    - defense"),
                   "defense-best, its DEFENSE overridden: saved with all three");
      Free (C);

      --  An overridden Incorporeal Form's Defense the character doesn't
      --  have: Barrier's is saved before it, so it is read back as the
      --  third.
      C := Ch.New_Character;
      C.Name := To_Unbounded_String ("Ghostless");
      Calc.Override (C.Incorporeal, 7, False, False);
      Ch.Recompute (C);
      Check.Check (Holds_Line (Save.To_Text (C), "defense: 2/0/7")
                   and then Holds_Line (Save.To_Text (C), "    - defense-3"),
                   "an overridden Incorporeal Form's DEFENSE without it: saved third, after Barrier's 0");
      Ok := Save.Save (C, "../obj/ghostless.yaml", Msg) and then Ch.Load ("../obj/ghostless.yaml", C2, Msg);
      Check.Check (Ok and then Notice_Count = 0 and then Calc.Overridden (C2.Incorporeal)
                   and then Calc.Value (C2.Incorporeal) = 7 and then not Calc.Overridden (C2.Barrier),
                   "and read back as Incorporeal Form's, with no notice");
      Free (C);
      Free (C2);
   end Defenses;

   --  Text plain YAML can't hold, saved and loaded back.
   procedure Awkward_Text is
      C, C2 : Ch.Character_Access;
      Msg   : Unbounded_String;
      Ok    : Boolean;
      Note  : E.Note_Item;
   begin
      C := Ch.New_Character;
      C.Name := To_Unbounded_String ("#1 ""Ace""");
      C.Has_Tagline := True;
      C.Tagline := To_Unbounded_String ("'Til the end: - and | >");
      C.Has_Background := True;
      C.Background := To_Unbounded_String ("  Indented first line," & LF & "then a second; # not a comment");
      Note.Header := To_Unbounded_String ("? Header");
      Note.Text := To_Unbounded_String ("@line one" & LF & LF & "%line three");
      C.Notes.Append (Note);
      C.Has_Fluff := True;
      C.Has_Fluff_Field (Ch.Hobbies) := True;
      C.Fluff (Ch.Hobbies) := To_Unbounded_String ("#1 fan");
      Calc.Compute (Calc.Sheet (C));
      Check.Check (Save.Save (C, "../obj/files/awkward.yaml", Msg), "awkward text: saved");
      Ok := Ch.Load ("../obj/files/awkward.yaml", C2, Msg);
      Check.Check (Ok, "awkward text: loaded");
      if not Ok then
         Say (To_String (Msg));
         Free (C);
         return;
      end if;
      Check.Check (C2.Name = C.Name, "awkward text: the name");
      Check.Check (C2.Tagline = C.Tagline, "awkward text: the tagline");
      --  The file keeps the background's first blanks; Ova_Fmt.Entities
      --  trims it on loading, as ova_fmt does.
      declare
         D : constant Libfyaml.Documents.Document := Libfyaml.Documents.Parse_File ("../obj/files/awkward.yaml");
         N : constant Nodes.Node := Nodes.By_Path (D.Root, "/0/background");
      begin
         Check.Check (Nodes.Is_Valid (N) and then Nodes.Is_Scalar (N)
                      and then Nodes.Scalar_Value (N) = To_String (C.Background),
                      "awkward text: the file holds the background exactly, its first blanks too");
      end;
      Check.Check (C2.Background = Ada.Strings.Fixed.Trim (To_String (C.Background), Ada.Strings.Both),
                   "awkward text: the background loads trimmed");
      Check.Check (Natural (C2.Notes.Length) = 1 and then C2.Notes (1).Header = Note.Header
                   and then C2.Notes (1).Text = Note.Text,
                   "awkward text: the note");
      Check.Check (C2.Has_Fluff_Field (Ch.Hobbies) and then C2.Fluff (Ch.Hobbies) = C.Fluff (Ch.Hobbies),
                   "awkward text: hobbies #1 fan");
      Check.Check (Notice_Count = 0, "awkward text: no notices");
      Free (C);
      Free (C2);
   end Awkward_Text;

   --  The whole of the file at Path.
   function Read_File (Path : String) return String is
      package SIO renames Ada.Streams.Stream_IO;
      F : SIO.File_Type;
   begin
      SIO.Open (F, SIO.In_File, Path);
      declare
         S : String (1 .. Natural (SIO.Size (F)));
      begin
         String'Read (SIO.Stream (F), S);
         SIO.Close (F);
         return S;
      end;
   end Read_File;

   --  Markdown.Save: a file that can't be written is said so, and the
   --  next save, to a file that can, works.
   procedure Markdown_Save is
      Msg  : Unbounded_String;
      Ok   : Boolean;
      Path : constant String := "../obj/sheet.md";
   begin
      Ok := Markdown.Save ("# A", "../obj/no/such/dir/sheet.md", Msg);
      Check.Check (not Ok and then Holds (To_String (Msg), "couldn't write ../obj/no/such/dir/sheet.md"),
                   "a Markdown sheet that can't be written: said so");
      Remove (Path);
      Ok := Markdown.Save ("# B", Path, Msg);
      Check.Check (Ok and then Msg = Null_Unbounded_String and then Read_File (Path) = "# B",
                   "then one that can: written, all of it");
   end Markdown_Save;

begin
   if not Ada.Directories.Exists (Saved_Dir) then
      Ada.Directories.Create_Path (Saved_Dir);
   end if;
   Fixtures;
   Markdown_Save;
   Errors;
   Defenses;
   Several;
   Awkward_Text;
   Check.Summary;
end Test_Files;
