private async void execute_queries (SQLHeavy.Transaction trans, int source) {
  try {
    var stmt = trans.prepare ("INSERT INTO `foo` (`source`, `iter`) VALUES (:source, :iter);");
    stmt.bind_int (":source", source);

    for ( int i = 0 ; i < 0xff ; i++ ) {
      try {
        stmt.bind_int (":iter", i);
        yield stmt.execute_async ();
      } catch ( SQLHeavy.Error ep ) {
        GLib.error (ep.message);
      }
    }
    GLib.debug ("Committing...");
    trans.commit ();
  } catch ( SQLHeavy.Error e ) {
    GLib.error (e.message);
  }
}

private static int main (string[] args) {
  try {
    var pool = new SQLHeavy.DatabasePool ("foo.db");
    var trans = pool.begin_transaction ();
    trans.execute ("CREATE TABLE IF NOT EXISTS `foo` ( `source` INT, `iter` INT );");
    trans.commit ();

    for ( int source = 0 ; source < 8 ; source++ ) {
      execute_queries.begin (pool.begin_transaction (), source);
    }

    new GLib.MainLoop ().run ();
  }
  catch ( SQLHeavy.Error e ) {
    GLib.error (e.message);
  }

  return 0;
}
