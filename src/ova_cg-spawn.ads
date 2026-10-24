--  Running other programs: the rulebook's viewer and its D-Bus queries.
--
--  ova_cg_po's PLAN.md, "The rulebook viewer": a viewer is started
--  detached, in a session of its own, so a hangup of the program's
--  terminal doesn't end it, and a failed start comes back as an errno
--  instead of a shell's message on the terminal.  Capture runs a
--  program and returns its standard output, for gdbus.  A program is an
--  argument vector built with Clear and Add, run with execvp: never a
--  shell command line, so nothing needs quoting.  The work is in the C
--  part, ova_cg_spawn.c.  Needs no display, and uses no fltkada.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C;

package Ova_Cg.Spawn is

   --  errno values the package returns itself (Linux's).
   ENOENT : constant := 2;
   ESRCH  : constant := 3;
   EINVAL : constant := 22;
   E2BIG  : constant := 7;

   --  An argument vector.  One too long to fit (more than 8192 bytes,
   --  each argument's NUL included) fails to run with E2BIG.  Empty to
   --  start with.
   type Args is private;

   procedure Clear (A : in out Args);

   --  Appends S as the next argument.  S holding a NUL would end the
   --  argument there, as C sees it; none of this program's do.
   procedure Add (A : in out Args; S : String);
   procedure Add (A : in out Args; S : Unbounded_String);

   function Count (A : Args) return Natural;

   --  Argument I (0 is the program), for tests and messages; "" past
   --  the end.
   function Arg (A : Args; I : Natural) return String;

   --  A program Detached started: its pid, and when it started, which
   --  tells it from a later process given the same pid.  None to start
   --  with.
   type Process is private;

   --  P's pid; 0 for none.
   function Pid (P : Process) return Integer;

   --  Starts A's program detached (ova_cg_spawn.c): in its own session,
   --  with standard input, output and error on /dev/null, never a
   --  zombie of ours.  P is the program; 0, or the errno of a failed
   --  start, whose P is none.
   function Detached (A : Args; P : out Process) return Integer;

   --  Runs A's program and waits for it, with its standard output in
   --  Output and its standard input and error on /dev/null.  Status is
   --  its exit status, or -1 if a signal ended it.  0, or the errno of a
   --  failed start, when Output is "" and Status -1.
   function Capture (A : Args; Output : out Unbounded_String; Status : out Integer)
     return Integer;

   procedure None (P : out Process);

   --  Whether P is still running: the same process, not a later one
   --  given its pid.
   function Alive (P : Process) return Boolean;

   --  Ends P with SIGTERM, if it is still running, and makes it none.
   --  Only a process this program started is ended, never one found by
   --  name, which could be the user's own.  (Terminate is a reserved
   --  word.)
   function Terminate_Process (P : in out Process) return Boolean;

   --  Pid's session, -1 if there is no such process: for tests.
   function Session (Pid : Integer) return Integer;

   --  Whether execvp would find Name and could run it: a name with a
   --  "/" as it is, any other in PATH.
   function On_Path (Name : String) return Boolean;

   --  Err's text, as strerror gives it ("No such file or directory").
   function Error_Text (Err : Integer) return String;

private

   use type Interfaces.C.size_t, Interfaces.Integer_64;

   --  The bytes an argument vector holds, its strings' NULs included.
   Max_Args : constant := 8192;

   --  N strings, each ended by NUL, packed in Buf (0 .. Len - 1).
   type Args is record
      Buf      : Interfaces.C.char_array (0 .. Max_Args - 1);
      Len      : Natural := 0;
      N        : Natural := 0;
      Overflow : Boolean := False;
   end record;

   type Process is record
      Pid   : Integer := 0;
      Start : Interfaces.Integer_64 := -1;
   end record;

end Ova_Cg.Spawn;
