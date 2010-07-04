namespace SQLHeavy {
  /**
   * A table row
   */
  public class Row : GLib.Object, SQLHeavy.Record {
    /**
     * The table that this row is a record of
     */
    public Table table { get; construct; }

    private int64 _id = 0;
    /**
     * The row ID of this row, or 0 if it has not yet been inserted
     */
    public int64 id {
      get { return this._id; }
      construct { this._id = value; }
    }

    /**
     * One or more field in this row has changed in the database
     *
     * @see put
     */
    public signal void changed ();

    /**
     * The row was deleted from the database
     *
     * @see delete
     */
    public signal void deleted ();

    /**
     * {@inheritDoc}
     */
    public int field_count { get { return this.table.field_count; } }

    /**
     * Cache of values waiting to be written to the database
     *
     * @see Record.save
     * @see Record.put
     */
    private GLib.Value?[]? values = null;

    /**
     * Cache of values for reading from the database
     *
     * When this row is changed, these values are compared with the
     * new values to determine which fields have been altered.
     */
    private GLib.Value?[]? cache = null;

    /**
     * Whether or not to enable caching for this row
     *
     * Caching is required for field-level change notifications.
     */
    public bool enable_cache { get; construct set; default = true; }

    /**
     * The specified field changed in the database
     */
    public signal void field_changed (int field);

    /**
     * {@inheritDoc}
     */
    public void save () throws SQLHeavy.Error {
      lock ( this.values ) {
        if ( this.values == null )
          return;

        var field = 0;
        var field_count = this.table.field_count;
        var query = new GLib.StringBuilder ();
        var first_field = true;

        if ( this._id > 0 ) {
          query.printf ("UPDATE `%s` SET ", this.table.name);

          for ( field = 0 ; field < field_count ; field++ ) {
            if ( this.values[field] != null ) {
              if ( !first_field )
                query.append (", ");
              var field_name = this.table.field_name (field);
              query.append (@"`$(field_name)` = :$(field_name)");
              first_field = false;
            }
          }
          query.append (" WHERE `ROWID` = :ROWID;");
        } else {
          query.printf ("INSERT INTO `%s` (", this.table.name);
          var qvalues = new GLib.StringBuilder ();

          for ( field = 0 ; field < field_count ; field++ ) {
            if ( this.values[field] != null ) {
              if ( !first_field ) {
                query.append (", ");
                qvalues.append (", ");
              }

              var field_name = this.table.field_name (field);
              query.append (@"`$(field_name)`");
              qvalues.append (@":$(field_name)");
            }
          }

          query.append (") VALUES (");
          query.append (qvalues.str);
          query.append (");");
        }

        var stmt = this.table.queryable.prepare (query.str);

        for ( field = 0 ; field < field_count ; field++ ) {
          if ( this.values[field] != null ) {
            var field_name = this.table.field_name (field);
            stmt.bind_value (@":$(field_name)", this.values[field]);
          }
        }

        if ( this._id > 0 ) {
          stmt.bind_int64 (":ROWID", this._id);
          stmt.execute ();
        }
        else {
          var db = this.table.queryable.database;
          this._id = stmt.execute_insert ();
          db.register_orm_row (this);
          this.update_cache ();
        }

        this.values = null;
      }
    }

    /**
     * {@inheritDoc}
     */
    public int field_index (string field) throws SQLHeavy.Error {
      return this.table.field_index (field);
    }

    /**
     * {@inheritDoc}
     */
    public string field_name (int field) throws SQLHeavy.Error {
      return this.table.field_name (field);
    }

    /**
     * {@inheritDoc}
     */
    public GLib.Type field_type (int field) throws SQLHeavy.Error {
      return this.fetch (field).type ();
    }

    /**
     * {@inheritDoc}
     */
    public void put (int field, GLib.Value value) throws SQLHeavy.Error {
      var field_count = this.table.field_count;

      if ( field < 0 || field >= field_count )
        throw new SQLHeavy.Error.RANGE ("Invalid field index (%d)", field);

      lock ( this.values ) {
        if ( this.values == null )
          this.values = new GLib.Value[field_count];

        this.values[field] = value;
      }
    }

    internal void on_delete () {
      this._id = 0;
      this.deleted ();
    }

    /**
     * {@inheritDoc}
     *
     * @see deleted
     */
    public void delete () throws SQLHeavy.Error {
      if ( this._id > 0 ) {
        var stmt = this.table.queryable.prepare (@"DELETE FROM `$(this.table.name)` WHERE `ROWID` = :id;");
        stmt.bind_int64 (":id", this._id);
        stmt.execute ();
      }
    }

    /**
     * {@inheritDoc}
     */
    public GLib.Value fetch (int field) throws SQLHeavy.Error {
      if ( this.values != null && this.values[field] != null )
        return this.values[field];

      if ( this.enable_cache && this.cache[field] != null )
        return this.cache[field];

      var field_name = this.table.field_name (field);
      if ( this._id <= 0 )
        throw new SQLHeavy.Error.MISUSE ("Cannot read field `%s` from row not persisted to database.", field_name);

      var stmt = this.table.queryable.prepare (@"SELECT `$(field_name)` FROM `$(this.table.name)` WHERE `ROWID` = :id;");
      stmt.bind_int64 (":id", this._id);
      return stmt.fetch_result (0);
    }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Row fetch_foreign_row (int field) throws SQLHeavy.Error {
      return this.fetch_named_foreign_row (this.field_name (field));
    }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Row fetch_named_foreign_row (string field) throws SQLHeavy.Error {
      var foreign_key_idx = this.table.foreign_key_index (field);
      var foreign_table = this.table.foreign_key_table (foreign_key_idx);
      return new SQLHeavy.Row (foreign_table, this.fetch_named_int64 (field));
    }

    /**
     * Updates the cache of the row
     */
    internal void update_cache () throws SQLHeavy.Error {
      lock ( this.cache ) {
        if ( this._id == 0 )
          return;

        int fc;

        if ( !this.enable_cache ) {
          this.cache = null;
          return;
        } else {
          fc = this.field_count;

          if ( this.cache == null )
            this.cache = new GLib.Value[fc];
        }

        var stmt = this.table.queryable.prepare (@"SELECT * FROM `$(this.table.name)` WHERE `ROWID` = :id;");
        stmt.bind_int64 (":id", this._id);
        stmt.step_internal ();
        var res = stmt.fetch_row ();

        var fields_changed = new bool[fc];
        int f = 0;
        for ( f = 0 ; f < fc ; f++ ) {
          if ( this.cache[f] == null || !value_equal (this.cache[f], res.values[f]) ) {
            fields_changed[f] = this.cache[f] != null;
            this.cache[f] = res.values[f];
          } else {
            fields_changed[f] = false;
          }
        }

        for ( f = 0 ; f < fc ; f++ )
          if ( fields_changed[f] )
            this.field_changed (f);
      }
    }

    construct {
      if ( this._id != 0 )
        this.table.queryable.database.register_orm_row (this);

      if ( this.enable_cache ) {
        try {
          this.update_cache ();
        } catch ( SQLHeavy.Error e ) {
          GLib.warning ("Unable to initialize cache: %s", e.message);
        }
      }

      this.changed.connect (() => {
          this.table.queryable.database.add_step_unlock_notify_row (this);
        });

      this.notify["enable-cache"].connect ((pspec) => {
          try {
            this.update_cache ();
          } catch ( SQLHeavy.Error e ) {
            GLib.warning ("Unable to %s cache: %s", this.enable_cache ? "enable" : "disable", e.message);
          }
        });
    }

    /**
     * Create or load a row from a table
     *
     * Note that you must call {@link save} in order for a new row
     * to be written to the queryable
     *
     * @param table the table to load the row from
     * @param id row ID, or 0 to create a new row
     */
    public Row (Table table, int64 id = 0) {
      Object (table: table, id: id);
    }

    ~ Row () {
      this.table.queryable.database.unregister_orm_row (this);
    }
  }
}
