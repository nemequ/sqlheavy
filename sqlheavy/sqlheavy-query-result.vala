namespace SQLHeavy {
  /**
   * The result of executing a {@link Query}
   */
  public class QueryResult : GLib.Object, SQLHeavy.Record, SQLHeavy.RecordSet {
    /**
     * The Query associated with this result.
     */
    public SQLHeavy.Query query { get; construct; }

    /**
     * The bindings for this query result
     */
    public SQLHeavy.ValueArray bindings { get; construct; }

    /**
     * The SQLite statement associated with this result
     */
    private unowned Sqlite.Statement stmt;

    /**
     * Whether the statement is owned by this result
     */
    private bool stmt_is_owned;

    /**
     * The last error code.
     */
    private int error_code = Sqlite.OK;

    /**
     * Signal which is emitted each time a row is recieved.
     */
    public signal void received_row ();

    /**
     * Number of times that SQLite has stepped forward in a table as
     * part of a full table scan.
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/c_stmtstatus_fullscan_step.html]]
     */
    public int full_scan_steps {
      get {
        return this.stmt.status (Sqlite.StatementStatus.FULLSCAN_STEP, 0);
      }
    }

    /**
     * The number of sort operations that have occurred.
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/c_stmtstatus_fullscan_step.html]]
     */
    public int sort_operations {
      get {
        return this.stmt.status (Sqlite.StatementStatus.SORT, 0);
      }
    }

    /**
     * Timer used for profiling.
     *
     * @see execution_time
     * @see ProfilingDatabase
     */
    private GLib.Timer execution_timer;

    /**
     * A timer for determining how much time (wall-clock) has been
     * spent executing the statement.
     *
     * This clock is started and stopped each time step () is called,
     * and reset when reset () is called.
     *
     * @return seconds elapsed
     * @see Database.enable_profiling
     */
    public double execution_time {
      get {
        return this.execution_timer.elapsed ();
      }
    }

    /**
     * Move to the next row in the result set.
     *
     * This internal function is called by {@link next} (among
     * others), and will not acquire any locks.
     *
     * @return true on success, false if the query is finished executing
     * @see next
     */
    internal bool next_internal () throws SQLHeavy.Error {
      unowned Sqlite.Statement stmt = this.stmt;

      if ( this.finished )
        return false;

      this.execution_timer.continue ();
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

    /**
     * Acquire locks
     *
     * @param queryable the relevant {@link Queryable}
     * @param database the relevant {@link Database}
     */
    private void acquire_locks (SQLHeavy.Queryable queryable, SQLHeavy.Database database) {
      queryable.@lock ();
      database.step_lock ();
    }

    /**
     * Release locks
     *
     * @param queryable the relevant {@link Queryable}
     * @param database the relevant {@link Database}
     */
    private void release_locks (SQLHeavy.Queryable queryable, SQLHeavy.Database database) {
      database.step_unlock ();
      queryable.unlock ();
    }

    /**
     * Move to the next row in the result set.
     *
     * @return true on success, false if the query is finished executing
     * @see next_async
     * @see complete
     */
    public bool next () throws SQLHeavy.Error {
      unowned SQLHeavy.Queryable queryable = this.query.queryable;
      SQLHeavy.Database db = queryable.database;

      this.acquire_locks (queryable, db);
      try {
        return this.next_internal ();
      } finally {
        this.release_locks (queryable, db);
      }
    }

    /**
     * Move to the next result in the result set asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @return true on success, false if the query is finished executing
     * @see next
     */
    public async bool next_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      int64 insert_id = 0;
      return yield this.next_internal_async (cancellable, 1, out insert_id);
    }

    /**
     * Move to the next result in the result set asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @param steps number of steps to take through the result set, or 0 for unlimited
     * @return true on success, false if the query is finished executing
     * @see next
     */
    internal async bool next_internal_async (GLib.Cancellable? cancellable = null, int steps = 0, out int64 last_insert_id) throws SQLHeavy.Error {
      bool executing = false;
      GLib.Mutex executing_lock = GLib.Mutex ();
      SQLHeavy.Queryable queryable = this.query.queryable;
      SQLHeavy.Database database = queryable.database;
      unowned GLib.Thread<void*>? thread = null;
      SQLHeavy.Error? error = null;
      int64 insert_id = 0;
      ulong cancellable_sig = 0;
      bool step_res = false;

      // prepare the async callback for the thread's default event dispatcher
      unowned GLib.MainContext? thread_context = MainContext.get_thread_default ();
      GLib.IdleSource idle_source = new GLib.IdleSource ();
      idle_source.set_callback (next_internal_async.callback);

      if ( cancellable != null ) {
        cancellable_sig = cancellable.cancelled.connect (() => {
            executing_lock.lock ();
            if ( executing ) {
              database.interrupt ();
            } else {
              error = new SQLHeavy.Error.INTERRUPTED (sqlite_errstr (Sqlite.INTERRUPT));
              idle_source.attach (thread_context);
              if ( thread != null )
                GLib.Thread.exit (null);
              this.release_locks (queryable, database);
            }
            executing_lock.unlock ();
          });
      }

      new GLib.Thread<void*> ("query-result-next", () => {
          this.acquire_locks (queryable, database);

          executing_lock.lock ();
          executing = true;
          executing_lock.unlock ();

          try {
            while ( steps != 0 ) {
              if ( (cancellable != null && cancellable.is_cancelled ()) || !(step_res = this.next_internal ()) )
                break;

              if ( steps > 0 )
                steps--;
            }
          }
          catch ( SQLHeavy.Error e ) {
            error = e;
          }

          insert_id = database.last_insert_id;

          this.release_locks (queryable, database);

          if ( cancellable_sig != 0 ) {
            cancellable.disconnect (cancellable_sig);
          }

          idle_source.attach (thread_context);

          return null;
        });

      yield;

      if ( error != null )
        throw error;

      last_insert_id = insert_id;

      return step_res;
    }

    /**
     * Finish iterating through the result set.
     */
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

    /**
     * Finish iterating through the result set asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     */
    public async void complete_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      int64 insert_id = 0;
      yield this.next_internal_async (cancellable, 0, out insert_id);
    }

    /**
     * Whether the result set has been iterated through in its
     * entirety
     */
    public bool finished { get; private set; }

    private int _field_count;

    /**
     * {@inheritDoc}
     */
    public int field_count {
      get { return this._field_count; }
    }

    /**
     * {@inheritDoc}
     */
    private int field_check_index (int field) throws SQLHeavy.Error {
      if (field < 0 || field > this.field_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));

      return field;
    }

    /**
     * {@inheritDoc}
     */
    public string field_name (int field) throws SQLHeavy.Error {
      return this.stmt.column_name (this.field_check_index (field));
    }

    /**
     * Name of the table that is the origin of a field
     *
     * @param field index of the field
     * @return the table
     * @see field_origin_table
     */
    public string field_origin_table_name (int field) throws SQLHeavy.Error {
      return this.stmt.column_table_name (this.field_check_index (field));
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
      return this.stmt.column_origin_name (this.field_check_index (field));
    }

    /**
     * Hash table of field names and their indices
     */
    private GLib.HashTable<string, int?>? _field_names = null;

    /**
     * {@inheritDoc}
     */
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

    /**
     * {@inheritDoc}
     */
    public GLib.Type field_type (int field) throws SQLHeavy.Error {
      return sqlite_type_to_g_type (this.stmt.column_type (this.field_check_index (field)));
    }

    /**
     * {@inheritDoc}
     */
    public GLib.Value fetch (int field) throws SQLHeavy.Error {
      return sqlite_value_to_g_value (this.stmt.column_value (this.field_check_index (field)));
    }

    /**
     * {@inheritDoc}
     */
    public string? fetch_string (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_text (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int fetch_int (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_int (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int64 fetch_int64 (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_int64 (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public double fetch_double (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_double (this.field_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public uint8[] fetch_blob (int field = 0) throws SQLHeavy.Error {
      var res = new uint8[this.stmt.column_bytes(this.field_check_index (field))];
      GLib.Memory.copy (res, this.stmt.column_blob (field), res.length);
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
      return new SQLHeavy.Row (foreign_table, q.execute (null).fetch_int64 (0));
    }

    construct {
      this.execution_timer = new GLib.Timer ();
      this.execution_timer.stop ();
      this.execution_timer.reset ();

      if ( (this.stmt = this.query.try_to_steal_stmt ()) == null ) {
        this.stmt_is_owned = true;
        unowned Sqlite.Database db = this.query.queryable.database.get_sqlite_db ();
        GLib.assert (sqlite3_prepare_v2 (db, this.query.sql, -1, out this.stmt) == Sqlite.OK);
      } else {
        this.stmt_is_owned = false;
      }

      this._field_count = this.stmt.column_count ();

      if ( this.bindings == null ) {
        this.bindings = this.query.get_bindings ();
      }

      var bindings_length = this.bindings.length;
      for ( int i = 0 ; i < bindings_length ; i++ ) {
        unowned GLib.Value? val = this.bindings[i];
        if ( val == null ) {
          GLib.critical ("Incomplete bindings");
        } else {
          GLib.Type val_t = val.type ();
          var index = i + 1;

          if ( val_t == typeof (string) ) {
            this.stmt._bind_text (index, val.get_string (), -1, null);
          } else if ( val_t == typeof (int) ) {
            this.stmt.bind_int (index, val.get_int ());
          } else if ( val_t == typeof (int64) ) {
            this.stmt.bind_int64 (index, val.get_int64 ());
          } else if ( val_t == typeof (float) ) {
            this.stmt.bind_double (index, val.get_float ());
          } else if ( val_t == typeof (double) ) {
            this.stmt.bind_double (index, val.get_double ());
          } else if ( val_t == typeof (void*) ) {
            this.stmt.bind_null (index);
          } else if ( val_t == typeof (GLib.ByteArray) ) {
            GLib.ByteArray ba = (GLib.ByteArray) val;
            this.stmt.bind_blob (index, ba.data, (int) ba.len, null);
          }
        }
      }
    }

    ~ QueryResult () {
      unowned SQLHeavy.Query query = this.query;
      unowned SQLHeavy.Queryable queryable = query.queryable;
      unowned SQLHeavy.ProfilingDatabase? prof_db = queryable.database.profiling_data;

      queryable.query_executed (query);

      if ( prof_db != null )
        prof_db.insert (this);

      this.stmt.reset ();

      if ( query.auto_clear )
        query.clear ();

      if ( this.stmt_is_owned ) {
        sqlite3_finalize (this.stmt);
      } else {
        query.return_stmt ();
      }
    }

    /**
     * Create a new QueryResult without acquiring locks
     *
     * @param query the relevant query
     */
    internal QueryResult.no_lock (SQLHeavy.Query query) throws SQLHeavy.Error {
      GLib.Object (query: query);
      this.next_internal ();
    }

    /**
     * Create a new QueryResult and return the {@link Database.last_insert_id}
     *
     * @param query the relevant query
     * @param insert_id location to put the ID of the inserted row
     * @see Query.execute_insert
     */
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

    /**
     * Create a new QueryResult but do not run it.
     *
     * @param query the relevant query
     */
    internal QueryResult.no_exec (SQLHeavy.Query query) throws SQLHeavy.Error {
      GLib.Object (query: query);
    }

    /**
     * Create a new QueryResult
     *
     * @param query the relevant query
     */
    public QueryResult (SQLHeavy.Query query) throws SQLHeavy.Error {
      GLib.Object (query: query);

      this.next ();
    }
  }
}
