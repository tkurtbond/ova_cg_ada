--  Ova_Cg.Spawn: starting a program detached, and capturing one's
--  output.
--
--  Run from test/, as make test does.  The viewer is fake-viewer.sh,
--  which records its arguments, parent, session, terminal and standard
--  files in ../obj/fake-viewer.log, then runs until ended: every one
--  started here is ended by its pid (Terminate_Process), never by name.
--  Needs no display.

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Check;
with Ova_Cg.Spawn; use Ova_Cg.Spawn;

procedure Test_Spawn is

   Viewer : constant String := "./fake-viewer.sh";
   Log    : constant String := "../obj/fake-viewer.log";
   --  An argument holding a blank and a "'", which a shell would need
   --  quoted.
   Odd    : constant String := "/tmp/an O'Brien book.pdf";
   LF     : constant Standard.Character := Standard.Character'Val (10);

   function Getpid return Integer
     with Import, Convention => C, External_Name => "getpid";

   A          : Args;
   P          : Process;
   Output     : Unbounded_String;
   Line_6     : Unbounded_String;
   Err        : Integer;
   Status     : Integer;
   I, N       : Integer;
   OK         : Boolean;

   --  The text of file Name, by cat; "" if it can't be read.
   function Contents (Name : String) return Unbounded_String is
      C  : Args;
      R  : Unbounded_String;
      St : Integer;
   begin
      Add (C, "cat");
      Add (C, Name);
      if Capture (C, R, St) /= 0 or else St /= 0 then
         R := Null_Unbounded_String;
      end if;
      return R;
   end Contents;

   --  Waits up to 5 s for file Name to exist.
   function Wait_For (Name : String) return Boolean is
      N : Natural := 0;
   begin
      while not Ada.Directories.Exists (Name) and then N < 100 loop
         delay 0.05;
         N := N + 1;
      end loop;
      return N < 100;
   end Wait_For;

   --  Waits up to 5 s for P to end.
   function Wait_End (P : Process) return Boolean is
      N : Natural := 0;
   begin
      while Alive (P) and then N < 100 loop
         delay 0.05;
         N := N + 1;
      end loop;
      return not Alive (P);
   end Wait_End;

   --  Line I (from 0) of R, without its newline; Present False past
   --  the end.
   type Line_Result (Present : Boolean := False) is record
      case Present is
         when True  => Text : Unbounded_String;
         when False => null;
      end case;
   end record;

   function Line (R : Unbounded_String; I : Natural) return Line_Result is
      Start : Natural := 1;
      Stop  : Natural;
   begin
      for K in 1 .. I loop
         Start := Index (R, [LF], Start);
         exit when Start = 0;
         Start := Start + 1;
      end loop;
      if Start = 0 or else Start > Length (R) then
         return (Present => False);
      end if;
      Stop := Index (R, [LF], Start);
      if Stop = 0 then
         Stop := Length (R) + 1;
      end if;
      return (Present => True, Text => Unbounded_Slice (R, Start, Stop - 1));
   end Line;

   function Is_Line (R : Unbounded_String; I : Natural; Want : String) return Boolean is
      L : constant Line_Result := Line (R, I);
   begin
      return L.Present and then L.Text = Want;
   end Is_Line;

   --  The decimal number after the first blank of S's word Word (from
   --  0), as "ppid 1 sid 2" holds: Field (S, 1) is 1, Field (S, 3) 2;
   --  -1 if none.
   function Field (S : Unbounded_String; Word : Natural) return Integer is
      Pos : Natural := 1;
      N   : Integer := 0;
   begin
      for K in 1 .. Word loop
         Pos := Index (S, " ", Pos);
         exit when Pos = 0;
         Pos := Pos + 1;
      end loop;
      if Pos = 0 or else Pos > Length (S) or else Element (S, Pos) not in '0' .. '9' then
         return -1;
      end if;
      while Pos <= Length (S) and then Element (S, Pos) in '0' .. '9' loop
         N := N * 10 + Standard.Character'Pos (Element (S, Pos)) - Standard.Character'Pos ('0');
         Pos := Pos + 1;
      end loop;
      return N;
   end Field;

   function Image (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (N'Image, Ada.Strings.Left));

   --  Detached's result, its process not wanted.
   function Detached_Error (A : Args) return Integer is
      P : Process;
   begin
      return Detached (A, P);
   end Detached_Error;

   --  Our children in state Z (zombies), by ps: its output's lines.
   function Zombies return Integer is
      C  : Args;
      R  : Unbounded_String;
      St : Integer;
      N  : Integer := -1;
   begin
      Add (C, "ps");
      Add (C, "-o");
      Add (C, "stat=");
      Add (C, "--ppid");
      Add (C, Image (Getpid));
      if Capture (C, R, St) = 0 then
         N := Ada.Strings.Unbounded.Count (R, "Z");
      end if;
      return N;
   end Zombies;

begin
   --  ---- Argument vectors ----
   Add (A, "one");
   Add (A, To_Unbounded_String ("two words"));
   Add (A, "");
   Check.Check (Ova_Cg.Spawn.Count (A) = 3 and then Arg (A, 0) = "one"
                and then Arg (A, 1) = "two words" and then Arg (A, 2) = ""
                and then Arg (A, 3) = "", "Args: Add, AddRope, an empty argument, Arg");

   --  ---- A missing program ----
   Clear (A);
   Add (A, "ova-cg-no-such-viewer");
   Add (A, "x.pdf");
   Err := Detached (A, P);
   Check.Check (Err = ENOENT and then Pid (P) = 0, "Detached: a missing program is ENOENT, and no process");
   Check.Check (Error_Text (Err) = "No such file or directory", "ErrorText: ENOENT's text");
   Check.Check (not Alive (P) and then not Terminate_Process (P),
                "a failed start is neither alive nor terminated");
   Clear (A);
   Add (A, "/etc/passwd");
   Check.Check (Detached_Error (A) /= 0, "Detached: a file that isn't a program fails");
   Clear (A);
   Check.Check (Detached_Error (A) = EINVAL, "Detached: no program at all is EINVAL");

   --  ---- Arguments arriving exactly ----
   if Ada.Directories.Exists (Log) then
      Ada.Directories.Delete_File (Log);
   end if;
   Clear (A);
   Add (A, Viewer);
   Add (A, "-p");
   Add (A, "62");
   Add (A, Odd);
   Add (A, "");
   Add (A, "$HOME *.pdf; `x` %f|&");
   Err := Detached (A, P);
   Check.Check (Err = 0 and then Pid (P) > 0, "Detached: the fake viewer starts");
   Check.Check (Wait_For (Log), "the fake viewer wrote its record");
   Output := Contents (Log);
   OK := Is_Line (Output, 0, "argc 5")
     and then Is_Line (Output, 1, "arg <-p>")
     and then Is_Line (Output, 2, "arg <62>")
     and then Is_Line (Output, 3, "arg </tmp/an O'Brien book.pdf>")
     and then Is_Line (Output, 4, "arg <>")
     and then Is_Line (Output, 5, "arg <$HOME *.pdf; `x` %f|&>");
   Check.Check (OK, "the arguments arrive exactly: a blank, a ', an empty one, shell characters");

   --  ---- Its own session, no terminal, no zombie ----
   declare
      L : constant Line_Result := Line (Output, 6);
   begin
      if L.Present then
         Line_6 := L.Text;
      end if;
   end;
   Check.Check (Field (Line_6, 3) > 0 and then Field (Line_6, 3) /= Session (Getpid)
                and then Field (Line_6, 3) = Session (Pid (P)), "the viewer is in a session of its own");
   Check.Check (Field (Line_6, 1) > 0 and then Field (Line_6, 1) /= Getpid, "the viewer isn't our child");
   Check.Check (Is_Line (Output, 7, "tty ?"), "the viewer has no terminal");
   Check.Check (Is_Line (Output, 8, "fds /dev/null /dev/null /dev/null"),
                "the viewer's standard input, output and error are /dev/null");
   Check.Check (Zombies = 0, "no zombie is left behind");

   --  ---- Alive and Terminate ----
   Check.Check (Alive (P), "Alive: the viewer is running");
   I := Pid (P);
   Check.Check (Terminate_Process (P) and then Pid (P) = 0, "Terminate: ends it, and the record is none");
   Clear (A);
   Add (A, "true");
   Err := Detached (A, P);
   Check.Check (Err = 0 and then Wait_End (P), "a program that ends by itself is no longer Alive");
   Check.Check (not Terminate_Process (P), "Terminate: false for one already ended");
   N := 0;
   while Session (I) /= -1 and then N < 100 loop
      delay 0.05;
      N := N + 1;
   end loop;
   Check.Check (Session (I) = -1, "the terminated viewer is gone");

   --  ---- Capture ----
   Clear (A);
   Add (A, "sh");
   Add (A, "-c");
   Add (A, "printf ""%s|"" ""$@""; echo; exit 3");
   Add (A, "sh");
   Add (A, Odd);
   Add (A, "");
   Err := Capture (A, Output, Status);
   Check.Check (Err = 0 and then Status = 3 and then Output = "/tmp/an O'Brien book.pdf||" & LF,
                "Capture: the output and the exit status");
   Clear (A);
   Add (A, "seq");
   Add (A, "20000");
   Err := Capture (A, Output, Status);
   --  seq 1 20000's bytes: 9 of 2, 90 of 3, 900 of 4, 9000 of 5, 10001
   --  of 6.
   Check.Check (Err = 0 and then Status = 0 and then Length (Output) = 108894
                and then Is_Line (Output, 19999, "20000") and then not Line (Output, 20000).Present,
                "Capture: output of many chunks, whole");
   Clear (A);
   Add (A, "true");
   Err := Capture (A, Output, Status);
   Check.Check (Err = 0 and then Status = 0 and then Output = "", "Capture: no output is NIL");
   Clear (A);
   Add (A, "sh");
   Add (A, "-c");
   Add (A, "echo x >&2; kill -TERM $$");
   Err := Capture (A, Output, Status);
   Check.Check (Err = 0 and then Status = -1 and then Output = "",
                "Capture: a signal is status -1; standard error isn't captured");
   Clear (A);
   Add (A, "ova-cg-no-such-program");
   Err := Capture (A, Output, Status);
   Check.Check (Err = ENOENT and then Status = -1 and then Output = "", "Capture: a missing program is ENOENT");
   Check.Check (Zombies = 0, "Capture leaves no zombie");

   --  ---- Too long ----
   Clear (A);
   Add (A, "true");
   Add (A, String'(1 .. 8999 => 'x'));
   Check.Check (Detached_Error (A) = E2BIG and then Capture (A, Output, Status) = E2BIG,
                "an argument vector too long is E2BIG");

   --  ---- OnPath ----
   Check.Check (On_Path ("sh") and then On_Path ("/bin/sh") and then On_Path (Viewer),
                "OnPath: a program on PATH, by path, and relative");
   Check.Check (not On_Path ("ova-cg-no-such-program") and then not On_Path ("/etc/passwd")
                and then not On_Path (""), "OnPath: missing, not executable, empty");

   Check.Summary;
end Test_Spawn;
