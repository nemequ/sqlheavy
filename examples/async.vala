/**
 * Some basic testing for the asnychronous functions.
 */

private async void test (SQLHeavy.Database db) {
  GLib.Cancellable? cancellable = null;

  var id = GLib.Timeout.add_seconds (1, () => {
      if ( cancellable != null ) {
        GLib.debug ("Canceling...");
        cancellable.cancel ();
        return false;
      }
      GLib.debug ("Tick");
      return true;
    });

  GLib.debug ("Running query...");
  try {
    var stmt = db.prepare ("UPDATE `foo` SET `bar` = ((`bar` + 1729) / 7) % 3;");
    // Comment out this line if you want to cancel the query.
    cancellable = new GLib.Cancellable ();
    yield stmt.execute_async (cancellable);
  } catch ( SQLHeavy.Error e ) {
    if ( e is SQLHeavy.Error.INTERRUPTED )
      GLib.debug ("Query canceled.");
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
    var trans = db.begin_transaction ();

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
