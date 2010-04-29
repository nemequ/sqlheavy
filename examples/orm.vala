private static int main (string[] args) {
  try {
    var db = new SQLHeavy.Database ();
    db.sql_executed.connect ((sql) => { GLib.debug (":: %s", sql); });

    db.execute ("CREATE TABLE `foo` ( `bar` FLOAT );");

    var table = new SQLHeavy.Table (db, "foo");
    var row = new SQLHeavy.Row (table);
    var prng = new GLib.Rand ();

    row.put_named_double ("bar", prng.next_double ());
    row.save ();
    GLib.debug ("bar = %g", row.fetch_named_double ("bar"));

    row.put_named_double ("bar", prng.next_double ());
    // Note that fetch_named_field will return the value we just set,
    // even though it hasn't yet been saved.
    GLib.debug ("bar = %g", row.fetch_named_double ("bar"));
    row.save ();
    // Now we make a trip to the database to get the value.
    GLib.debug ("bar = %g", row.fetch_named_double ("bar"));
  } catch ( SQLHeavy.Error e ) {
    GLib.error (e.message);
  }

  return 0;
}