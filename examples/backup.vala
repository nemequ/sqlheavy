private static async void copy (GLib.MainLoop loop) {
  try {
    var src = new SQLHeavy.Database (GLib.Path.build_filename (GLib.Environment.get_home_dir (), ".liferea_1.6", "liferea.db"), SQLHeavy.FileMode.READ);
    var dest = new SQLHeavy.Database ("liferea.db");
    var backup = new SQLHeavy.Backup (src, dest);
    yield backup.execute_async ();
  }
  catch ( SQLHeavy.Error e ) {
    GLib.error ("Error: %s", e.message);
  }

  loop.quit ();
}

private static int main (string[] args) {
  var loop = new GLib.MainLoop ();
  copy.begin (loop);
  loop.run ();

  return 0;
}
