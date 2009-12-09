GLib.MainLoop main_loop;

async void run(SQLHeavy.Database db) throws SQLHeavy.Error {
  var stmt = db.prepare ("VACUUM;");
  var res = yield stmt.step_async ();
}

private static int main (string[] args) {
  try {
    var db = new SQLHeavy.Database ("/home/nemequ/t/liferea.db");
    var stmt = db.prepare ("SELECT * FROM `items` LIMIT 1;");

    run.begin (db);
    GLib.Idle.add(() => {
        try {
          stmt.step ();
          GLib.debug ("Result: %s", stmt.fetch<string> (0));
        }
        catch ( SQLHeavy.Error e ) {
          GLib.error ("%d: %s", e.code, e.message);
        }
        return false;
      });

    main_loop = new GLib.MainLoop (null, false);
    main_loop.run ();
  }
  catch ( SQLHeavy.Error e ) {
    GLib.error ("%d: %s", e.code, e.message);
  }

  return 0;
}