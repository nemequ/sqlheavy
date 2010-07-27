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

    public SQLHeavy.Row fetch_foreign_row (int field) throws SQLHeavy.Error {
      GLib.assert_not_reached ();
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
