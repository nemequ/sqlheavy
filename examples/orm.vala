private static int main (string[] args) {
  try {
    var db = new SQLHeavy.Database ();
    db.sql_executed.connect ((sql) => { GLib.debug (":: %s", sql); });

    db.execute ("CREATE TABLE `foo` ( `bar` FLOAT );");

    var table = new SQLHeavy.Table (db, "foo");
    var row = new SQLHeavy.Row (table);
    var prng = new GLib.Rand ();

    row.set_double ("bar", prng.next_double ());
    row.save ();
    GLib.debug ("bar = %g", row.get_double ("bar"));

    row.set_double ("bar", prng.next_double ());
    // Note that get_field will return the value we just set,
    // even though it hasn't yet been saved.
    GLib.debug ("bar = %g", row.get_double ("bar"));
    row.save ();
    // Now we make a trip to the database to get the value.
    GLib.debug ("bar = %g", row.get_double ("bar"));

    int64 row_id = row.id;
    table[row_id]["bar"] = prng.next_double ();
    GLib.debug ("bar = %g", (double) table[row_id]["bar"]);
  } catch ( SQLHeavy.Error e ) {
    GLib.error (e.message);
  }

  return 0;
}