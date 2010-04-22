/**
 * Some basic testing for the asnychronous functions.
 */

private async void test (SQLHeavy.Database db) {
  GLib.Cancellable? cancellable = null;

  var id = GLib.Timeout.add_seconds (1, () => {
      if ( cancellable != null ) {
        // Comment these three lines if you don't want to cancel.
        GLib.debug ("Canceling...");
        cancellable.cancel ();
        return false;
      }
      return true;
    });

  GLib.debug ("Running query...");
  try {
    var stmt = db.prepare ("UPDATE `foo` SET `bar` = ((`bar` + 1729) / 7) % 3;");
    cancellable = new GLib.Cancellable ();
    yield stmt.execute_async (cancellable);
  } catch ( SQLHeavy.Error e ) {
    if ( e is SQLHeavy.Error.INTERRUPTED )
      GLib.debug ("Query cancelled.");
    else
      GLib.error ("Execution threw an error: %s (%d)", e.message, e.code);
  }
  GLib.debug ("Finished running query.");

  GLib.Source.remove (id);

  loop.quit ();
}

private GLib.MainLoop loop;

private static int main (string[] args) {
  try {
    var db = new SQLHeavy.Database ();
    var stmt = db.prepare ("CREATE TABLE `foo` ( `bar` INT );");
    stmt.execute ();

    GLib.debug ("Populating database...");
    var trans = new SQLHeavy.Transaction (db);

    stmt = trans.prepare ("INSERT INTO `foo` (`bar`) VALUES (:value);");
    for ( int i = 0 ; i < 65536 * 8 ; i++ ) {
      if ( (i & 0xffff) == 0xffff )
        GLib.debug ("%d...", i);

      stmt.bind_named_int (":value", i);
      stmt.execute ();
    }
    trans.commit ();

    test.begin (db);
  }
  catch ( SQLHeavy.Error e ) {
    GLib.debug ("Error: %s (%d)", e.message, e.code);
  }

  loop = new GLib.MainLoop ();
  loop.run ();

  return 0;
}
