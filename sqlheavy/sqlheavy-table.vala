namespace SQLHeavy {
  /**
   * A database table
   */
  public class Table : GLib.Object {
    /**
     * Table name
     */
    public string name { get; construct; }

    /**
     * The queryable that this table is a member of
     */
    public SQLHeavy.Queryable queryable { get; construct; }

    private class FieldInfo : GLib.Object {
      public int index;
      public string name;
      public string affinity;
      public bool not_null;

      public FieldInfo (int index, string name, string affinity, bool not_null) {
        this.index = index;
        this.name = name;
        this.affinity = affinity;
        this.not_null = not_null;
      }

      public FieldInfo.from_stmt (SQLHeavy.Statement stmt) throws SQLHeavy.Error {
        this.index = stmt.fetch_int (0);
        this.name = stmt.fetch_string (1);
        this.affinity = stmt.fetch_string (2);
        this.not_null = stmt.fetch_int (3) > 0;
      }
    }

    private GLib.Sequence<FieldInfo>? _field_data = null;
    private GLib.HashTable<string, int?>? _field_names = null;

    private unowned GLib.Sequence<FieldInfo> get_field_data () throws SQLHeavy.Error {
      if ( this._field_data == null ) {
        this._field_data = new GLib.Sequence<FieldInfo> (GLib.g_object_unref);
        this._field_names = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);

        var stmt = this.queryable.prepare (@"PRAGMA table_info (`$(escape_string (this.name))`);");
        while ( stmt.step () ) {
          var row = new FieldInfo.from_stmt (stmt);
          this._field_data.insert_sorted (row, (a, b) => {
              return ((FieldInfo) a).index - ((FieldInfo) b).index;
            });
          this._field_names.insert (row.name, row.index);
        }
      }

      return (!) this._field_data;
    }

    /**
     * Number of fields (columns) in the table
     */
    public int field_count {
      get {
        try {
          return this.get_field_data ().get_length ();
        } catch ( SQLHeavy.Error e ) {
          GLib.critical ("Unable to get number of fields: %s (%d)", e.message, e.code);
          return -1;
        }
      }
    }

    private FieldInfo field_info (int field) throws SQLHeavy.Error {
      var iter = this.get_field_data ().get_iter_at_pos (field);
      if ( iter == null )
        throw new SQLHeavy.Error.RANGE ("Invalid field index (%d)", field);

      return iter.get ();
    }

    /**
     * Get the name of a field
     *
     * @param index index of the field
     * @return name of the field by index
     */
    public string field_name (int field) throws SQLHeavy.Error {
      return this.field_info (field).name;
    }

    /**
     * The field affinity according to the schema
     *
     * @param field the field index
     * @return the field affinity
     */
    public string field_affinity (int field) throws SQLHeavy.Error {
      return this.field_info (field).affinity;
    }

    /**
     * Get the index of a field by name
     *
     * @param name name of the field
     * @return index of the field
     */
    public int field_index (string name) throws SQLHeavy.Error {
      if ( this._field_names == null )
        this.get_field_data ();

      var index = this._field_names.lookup (name);
      if ( index == null )
        throw new SQLHeavy.Error.RANGE ("Invalid field name (`%s')", name);

      return index;
    }

    /**
     * Load a table
     *
     * @param queryable the queryable to load the table from
     * @param name the name of the table
     */
    public Table (SQLHeavy.Queryable queryable, string name) throws SQLHeavy.Error {
      Object (queryable: queryable, name: name);
    }
  }
}
