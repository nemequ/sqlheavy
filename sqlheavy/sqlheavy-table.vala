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

    /**
     * A new row was inserted into the table
     */
    public signal void row_inserted (int64 row_id);

    /**
     * A row was deleted from the table
     */
    public signal void row_deleted (int64 row_id);

    private class FieldInfo : GLib.Object {
      public int index;
      public string name;
      public string affinity;
      public bool not_null;

      public FieldInfo.from_query_result (SQLHeavy.QueryResult query_result) throws SQLHeavy.Error {
        this.index = query_result.fetch_int (0);
        this.name = query_result.fetch_string (1);
        this.affinity = query_result.fetch_string (2);
        this.not_null = query_result.fetch_int (3) > 0;
      }
    }

    private class ForeignKeyInfo : GLib.Object {
      public int id;
      public int seq;
      public string table;
      public string from;
      public string to;
      // public string on_update;
      // public string on_delete;
      // public string match;

      public ForeignKeyInfo.from_query_result (SQLHeavy.QueryResult query_result) throws SQLHeavy.Error {
        this.id = query_result.fetch_int (0);
        this.seq = query_result.fetch_int (1);
        this.table = query_result.fetch_string (2);
        this.from = query_result.fetch_string (3);
        this.to = query_result.fetch_string (4);
        // this.on_update = query_result.fetch_string (5);
        // this.on_delete = query_result.fetch_string (6);
        // this.match = query_result.fetch_string (7);
      }
    }

    private GLib.Sequence<FieldInfo>? _field_data = null;
    private GLib.HashTable<string, int?>? _field_names = null;

    private unowned GLib.Sequence<FieldInfo> get_field_data () throws SQLHeavy.Error {
      lock ( this._field_data ) {
        if ( this._field_data == null ) {
          this._field_data = new GLib.Sequence<FieldInfo> (GLib.g_object_unref);
          this._field_names = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);

          var result = new SQLHeavy.Query (this.queryable, @"PRAGMA table_info (`$(escape_string (this.name))`);").execute ();

          while ( !result.finished ) {
            var row = new FieldInfo.from_query_result (result);
            this._field_data.insert_sorted (row, (a, b) => {
                return ((FieldInfo) a).index - ((FieldInfo) b).index;
              });
            this._field_names.insert (row.name, row.index);

            result.next ();
          }
        }
      }

      return (!) this._field_data;
    }

    private GLib.Sequence<ForeignKeyInfo>? _foreign_key_data = null;
    private GLib.HashTable<string, int?>? _foreign_key_names = null;

    private unowned GLib.Sequence<ForeignKeyInfo> get_foreign_key_data () throws SQLHeavy.Error {
      lock (this._foreign_key_data) {
        if ( this._foreign_key_data == null ) {
          this._foreign_key_data = new GLib.Sequence<ForeignKeyInfo> (GLib.g_object_unref);
          this._foreign_key_names = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);

          var result = new SQLHeavy.Query (this.queryable, @"PRAGMA foreign_key_list (`$(escape_string (this.name))`);").execute ();

          while ( !result.finished ) {
            var row = new ForeignKeyInfo.from_query_result (result);
            this._foreign_key_data.insert_sorted (row, (a, b) => {
                return ((ForeignKeyInfo) a).id - ((ForeignKeyInfo) b).id;
              });
            this._foreign_key_names.insert (row.from, row.id);

            result.next ();
          }
        }
      }

      return (!) this._foreign_key_data;
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
     * Number of foreign keys which reference a column in the table
     */
    public int foreign_key_count {
      get {
        try {
          return this.get_foreign_key_data ().get_length ();
        } catch ( SQLHeavy.Error e ) {
          GLib.critical ("Unable to get number of foreign keys: %s (%d)", e.message, e.code);
          return -1;
        }
      }
    }

    private ForeignKeyInfo foreign_key_info (int foreign_key) throws SQLHeavy.Error {
      var iter = this.get_foreign_key_data ().get_iter_at_pos (foreign_key);
      if ( iter == null )
        throw new SQLHeavy.Error.RANGE ("Invalid foreign key index (%d)", foreign_key);

      return iter.get ();
    }

    /**
     * Retrieve the table of the foreign key references
     *
     * @param foreign_key the id of the foreign key
     * @return the table name
     */
    public string foreign_key_table_name (int foreign_key) throws SQLHeavy.Error {
      return this.foreign_key_info (foreign_key).table;
    }

    /**
     * Retrieve the table of the foreign key references
     *
     * @param foreign_key the id of the foreign key
     * @return the table name
     */
    public SQLHeavy.Table foreign_key_table (int foreign_key) throws SQLHeavy.Error {
      return new SQLHeavy.Table (this.queryable, this.foreign_key_table_name (foreign_key));
    }

    /**
     * Retrieve the column of the table of the foreign key
     *
     * @param foreign_key the id of the foreign key
     * @return the column name
     */
    public string foreign_key_from (int foreign_key) throws SQLHeavy.Error {
      return this.foreign_key_info (foreign_key).from;
    }

    /**
     * Retrieve the column of which references the foreign key
     *
     * @param foreign_key the id of the foreign key
     * @return the column name
     */
    public string foreign_key_to (int foreign_key) throws SQLHeavy.Error {
      return this.foreign_key_info (foreign_key).to;
    }

    /**
     * Retrieve the index of the foreign key
     *
     * @param foreign_key the name of the foreign key column
     * @return the column index
     */
    public int foreign_key_index (string foreign_key) throws SQLHeavy.Error {
      if ( this._foreign_key_names == null )
        this.get_foreign_key_data ();

      var index = this._foreign_key_names.lookup (foreign_key);
      if ( index == null )
        throw new SQLHeavy.Error.RANGE ("Invalid foreign key name (`%s')", foreign_key);

      return index;
    }

    /**
     * Return the row with the specified ID
     *
     * @param id the id (ROWID) of the requested row
     * @return the reqested row
     */
    public new SQLHeavy.Row get (int64 id) throws SQLHeavy.Error {
      return new SQLHeavy.Row (this, id);
    }

    /**
     * Register the triggers necessary for change notifications
     */
    public void register_notify_triggers () throws SQLHeavy.Error {
      this.queryable.execute (@"CREATE TEMPORARY TRIGGER IF NOT EXISTS `__SQLHeavy_$(this.name)_update_notifier` AFTER UPDATE ON `$(this.name)` FOR EACH ROW BEGIN SELECT __SQLHeavy_notify (1, '$(this.name)', `OLD`.`ROWID`); END;");
    }

    construct {
      this.queryable.database.register_orm_table (this);
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
