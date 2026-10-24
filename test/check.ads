--  Shared ok/FAIL reporting for the test programs (ova_cg_po's Check).
--
--  Each test program calls Check once per check and Summary at the very
--  end.  Output, per check:
--    ok   - <label>
--    FAIL - <label>
--  then "All checks passed." or "<N> check(s) failed."
--
--  Summary sets exit status 1 only when something failed, and returns
--  either way, so the main program's own objects are finalized before
--  it ends (valgrind's leak report on a passing run means something).

package Check is

   procedure Check (OK : Boolean; Label : String);

   procedure Summary;

   --  The number of checks failed so far.
   function Failed return Natural;

end Check;
