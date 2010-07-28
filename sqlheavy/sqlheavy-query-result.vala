namespace SQLHeavy {
  public class QueryResult : GLib.Object, SQLHeavy.Record, SQLHeavy.RecordSet {
    public SQLHeavy.Query query { get; construct; }

    private int error_code = Sqlite.OK;

    public signal void received_row ();

    public int full_scan_steps {
      get {
        return this.query.get_statement ().status (Sqlite.StatementStatus.FULLSCAN_STEP, 0);
      }
    }

    public int sort_operations {
      get {
        return this.query.get_statement ().status (Sqlite.StatementStatus.SORT, 0);
      }
    }

    private GLib.Timer execution_timer;

    public double execution_time {
      get {
        return this.execution_timer.elapsed ();
      }
    }

    internal bool next_internal () throws SQLHeavy.Error {
      unowned Sqlite.Statement stmt = this.query.get_statement ();

      if ( this.finished )
        return false;

      this.execution_timer.start ();
      this.error_code = stmt.step ();
      this.execution_timer.stop ();

      switch ( this.error_code ) {
        case Sqlite.ROW:
          this.error_code = Sqlite.OK;
          this.received_row ();
          return true;
        case Sqlite.DONE:
          this.finished = true;
          this.error_code = Sqlite.OK;
          return false;
        default:
          error_if_not_ok (this.error_code, this.query.queryable);
          GLib.assert_not_reached ();
      }
    }

    private void acquire_locks (SQLHeavy.Queryable queryable, SQLHeavy.Database database) {
      queryable.@lock ();
      database.step_lock ();
    }

    private void release_locks (SQLHeavy.Queryable queryable, SQLHeavy.Database database) {
      database.step_unlock ();
      queryable.unlock ();
    }

    public bool next () throws SQLHeavy.Error {
      unowned SQLHeavy.Queryable queryable = this.query.queryable;
      SQLHeavy.Database db = queryable.database;

      this.acquire_locks (queryable, db);
      var res = this.next_internal ();
      this.release_locks (queryable, db);

      return res;
    }

    // public async bool next_async () throws SQLHeavy.Error;

    public void complete () throws SQLHeavy.Error {
      unowned SQLHeavy.Queryable queryable = this.query.queryable;
      SQLHeavy.Database db = queryable.database;

      queryable.@lock ();
      db.step_lock ();

      while ( !this.finished )
        this.next_internal ();

      db.step_unlock ();
      queryable.unlock ();
    }

    // public async void complete_async () throws SQLHeavy.Error;

    public bool finished { get; private set; }

    private int _field_count;
    public int field_count {
      get { return this._field_count; }
    }

    private int field_check_index (int field) throws SQLHeavy.Error {
      if (field < 0 || field > this.field_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));

      return field;
    }

    public string field_name (int field) throws SQLHeavy.Error {
      return this.query.get_statement ().column_name (this.field_check_index (field));
    }

    /**
     * Name of the table that is the origin of a field
     *
     * @param field index of the field
     * @return the table
     * @see field_origin_table
     */
    public string field_origin_table_name (int field) throws SQLHeavy.Error {
      return this.query.get_statement ().column_table_name (this.field_check_index (field));
    }

    /**
     * Table that is the origin of a field
     *
     * @param field index of the field
     * @return the table
     * @see field_origin_table_name
     */
    public SQLHeavy.Table field_origin_table (int field) throws SQLHeavy.Error {
      return new SQLHeavy.Table (this.query.queryable, this.field_origin_table_name (field));
    }

    /**
     * Name of the column that is the origin of a field
     *
     * @param field index of the field
     * @return the table name
     */
    public string field_origin_name (int field) throws SQLHeavy.Error {
      return this.query.get_statement ().column_origin_name (this.field_check_index (field));
    }

    private GLib.HashTable<string, int?>? _field_names = null;

    public int field_index (string field) throws SQLHeavy.Error {
      if ( this._field_names == null ) {
        this._field_names = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);

        var fields = this.field_count;
        for ( int i = 0 ; i < fields ; i++ )
          this._field_names.replace (this.field_name (i), i);
      }

      int? field_number = this._field_names.lookup (field);
      if ( field_number == null )
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));

      return (!) field_number;
    }

    public GLib.Type field_type (int field) throws SQLHeavy.Error {
      return sqlite_type_to_g_type (this.query.get_statement ().column_type (this.field_check_index (field)));
    }

    public GLib.Value fetch (int field) throws SQLHeavy.Error {
      return sqlite_value_to_g_value (this.query.get_statement ().column_value (this.field_check_index (field)));
    }

    /**
     * {@inheritDoc}
     */
    public string? fetch_string (int field = 0) throws SQLHeavy.Error {
      return this.query.get_statement ().column_text (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int fetch_int (int field = 0) throws SQLHeavy.Error {
      return this.query.get_statement ().column_int (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int64 fetch_int64 (int field = 0) throws SQLHeavy.Error {
      return this.query.get_statement ().column_int64 (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public double fetch_double (int field = 0) throws SQLHeavy.Error {
      return this.query.get_statement ().column_double (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public uint8[] fetch_blob (int field = 0) throws SQLHeavy.Error {
      var res = new uint8[this.query.get_statement ().column_bytes(this.field_check_index (field))];
      GLib.Memory.copy (res, this.query.get_statement ().column_blob (field), res.length);
      return res;
    }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Row fetch_foreign_row (int field) throws SQLHeavy.Error {
      var table = this.field_origin_table (field);
      var foreign_key_idx = table.foreign_key_index (this.field_origin_name (field));
      var foreign_table = table.foreign_key_table (foreign_key_idx);
      var foreign_column = table.foreign_key_to (foreign_key_idx);

      var q = new SQLHeavy.Query (this.query.queryable, @"SELECT `ROWID` FROM `$(foreign_table.name)` WHERE `$(foreign_column)` = :value;");
      q.bind_int64 (1, this.fetch_int64 (field));
      return new SQLHeavy.Row (foreign_table, q.execute ().fetch_int64 (0));
    }

    construct {
      this.execution_timer = new GLib.Timer ();
      this.execution_timer.stop ();
      this.execution_timer.reset ();

      unowned Sqlite.Statement stmt = this.query.get_statement ();
      this._field_count = stmt.column_count ();
    }

    internal QueryResult.no_lock (SQLHeavy.Query query) throws SQLHeavy.Error {
      GLib.Object (query: query);
      this.next_internal ();
    }

    internal QueryResult.insert (SQLHeavy.Query query, out int64 insert_id) throws SQLHeavy.Error {
      GLib.Object (query: query);

      unowned SQLHeavy.Queryable queryable = query.queryable;
      SQLHeavy.Database db = queryable.database;

      this.acquire_locks (queryable, db);
      try {
        this.next_internal ();
        insert_id = db.last_insert_id;
      } catch ( SQLHeavy.Error e ) {
        this.release_locks (queryable, db);
        throw e;
      }
      this.release_locks (queryable, db);
    }

    internal QueryResult (SQLHeavy.Query query) throws SQLHeavy.Error {
      GLib.Object (query: query);

      this.next ();
    }
  }
}
