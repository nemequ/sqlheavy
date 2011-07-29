namespace SQLHeavyGtk {
  /**
   * Gtk.TreeModel implementation
   */
  public class Model : GLib.Object, Gtk.TreeModel {
    private SQLHeavy.Table _table;
    /**
     * The table that this model is based on
     */
    public SQLHeavy.Table table {
      get {
        return this._table;
      }

      construct {
        this._table = value;
        this.queryable = table.queryable;
      }
    }

    /**
     * Cache of the table's queryable
     */
    private SQLHeavy.Queryable queryable;

    private SQLHeavy.Row? get_row_from_iter (Gtk.TreeIter iter) {
      if ( iter.user_data != null ) {
        return (SQLHeavy.Row) iter.user_data;
      } else {
        try {
          var row = this.table.get (iter.stamp);
          iter.user_data = row;
          row.ref ();
          return row;
        } catch ( SQLHeavy.Error e ) {
          GLib.critical ("Unable to get row from iterator: %s", e.message);
          return null;
        }
      }
    }

    // Begin GtkTreeModel methods

    public GLib.Type get_column_type (int index) {
      try {
        if ( index == 0 ) // ROWID
          return typeof (int64);
        else
          return this.table.field_affinity_type (index - 1);
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to determine column affinity (column #%d): %s", index, e.message);
        return typeof (void);
      }
    }

    public Gtk.TreeModelFlags get_flags () {
      return Gtk.TreeModelFlags.LIST_ONLY;
    }

    public bool get_iter (out Gtk.TreeIter iter, Gtk.TreePath path) {
      int64 offset = 0;
      unowned int[] indices = path.get_indices ();
      if ( indices.length == -1 )
        offset = 0;
      else if ( indices.length == 1 )
        offset = indices[0];
      else
        return false;

      try {
        var res = this.queryable.prepare (@"SELECT `ROWID` FROM `$(SQLHeavy.escape_string (this.table.name))` ORDER BY `ROWID` ASC LIMIT $(indices[0]),1;").execute ();
        if ( res.finished )
          return false;
        iter.stamp = res.fetch_int ();
        return true;
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to get row ID for iterator: %s", e.message);
        return false;
      }
    }

    public int get_n_columns () {
      return this.table.field_count + 1;
    }

    public Gtk.TreePath? get_path (Gtk.TreeIter iter) {
      try {
        SQLHeavy.QueryResult res = this.queryable.prepare (@"SELECT COUNT(*) FROM `$(SQLHeavy.escape_string (this.table.name))` WHERE `ROWID` < :rid ORDER BY `ROWID` ASC LIMIT 1").execute (":rid", typeof (int), iter.stamp);
        return new Gtk.TreePath.from_indices (res.fetch_int ());
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to get path from iterator: %s", e.message);
        return (!) null;
      }
    }

    private int get_value_calls = 0;
    public void get_value (Gtk.TreeIter iter, int column, out GLib.Value value) {
      try {
        SQLHeavy.Row row = this.get_row_from_iter (iter);
        value = row.fetch (column - 1);
        if ( value.holds (typeof (void*)) )
          value = GLib.Value (typeof (string));
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to get value: %s", e.message);
      }
    }

    public bool iter_children (out Gtk.TreeIter iter, Gtk.TreeIter? parent) {
      return false;
    }

    public bool iter_has_child (Gtk.TreeIter iter) {
      return false;
    }

    public int iter_n_children (Gtk.TreeIter? iter) {
      return 0;
    }

    private int next_calls = 0;
    public bool iter_next (ref Gtk.TreeIter iter) {
      try {
        SQLHeavy.QueryResult res = this.queryable.prepare (@"SELECT `ROWID` FROM `$(SQLHeavy.escape_string (this.table.name))` WHERE `ROWID` > $(iter.stamp) ORDER BY `ROWID` ASC LIMIT 1").execute ();
        if ( res.finished ) {
          return false;
        }
        else {
          iter.stamp = res.fetch_int ();
          iter.user_data = null;
          return true;
        }
      } catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to determine next row id: %s", e.message);
        return false;
      }
    }

    public bool iter_nth_child (out Gtk.TreeIter iter, Gtk.TreeIter? parent, int n) {
      return false;
    }

    public bool iter_parent (out Gtk.TreeIter iter, Gtk.TreeIter child) {
      return false;
    }

    public virtual void ref_node (Gtk.TreeIter iter) {
      if ( iter.user_data != null )
        ((SQLHeavy.Row) iter.user_data).ref ();
    }

    public virtual void unref_node (Gtk.TreeIter iter) {
      if ( iter.user_data != null )
        ((SQLHeavy.Row) iter.user_data).unref ();
    }

    // End GtkTreeModel methods

    /**
     * Create a new Model
     *
     * @param table the table this model is based on
     * @see table
     */
    public Model (SQLHeavy.Table table) {
      GLib.Object (table: table);
    }
  }
}
