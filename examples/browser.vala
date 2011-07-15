private static int main (string[] args) {
  Gtk.init (ref args);

  if ( args.length != 3 ) {
    GLib.stderr.printf ("Usage: %s database table\n", args[0]);
    return -1;
  }

  try {
    SQLHeavy.Database db = new SQLHeavy.Database (args[1]);

    Gtk.Window window = new Gtk.Window ();
    window.title = "SQLHeavy Database Browser";
    window.destroy.connect (Gtk.main_quit);

    SQLHeavy.Table table = db.get_table (args[2]);
    SQLHeavy.GtkModel model = new SQLHeavy.GtkModel (table);

    Gtk.ScrolledWindow scroll = new Gtk.ScrolledWindow (null, null);
    window.add (scroll);

    Gtk.TreeView view = new Gtk.TreeView.with_model (model);
    scroll.add (view);

    for ( int i = 0 ; i < table.field_count ; i++ ) {
      view.insert_column_with_attributes (-1, table.field_name (i), new Gtk.CellRendererText (), "text", i + 1);
    }

    window.show_all ();
    Gtk.main ();
  } catch ( SQLHeavy.Error e ) {
    GLib.error (e.message);
  }

  return 0;
}
