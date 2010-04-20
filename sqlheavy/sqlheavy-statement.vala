namespace SQLHeavy {
  [CCode (cname = "sqlite3_finalize", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_finalize (Sqlite.Statement stmt);
  [CCode (cname = "sqlite3_prepare_v2", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_prepare (Sqlite.Database db, string sql, int n_bytes, out unowned Sqlite.Statement stmt, out unowned string? tail = null);

  /**
   * A prepared statement.
   */
  public class Statement : GLib.Object {
    private int error_code = Sqlite.OK;
    private GLib.HashTable<string, int?> result_columns = null;

    private GLib.Timer execution_timer = new GLib.Timer ();

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
    public double execution_time_elapsed () {
      return this.execution_timer.elapsed ();
    }

    /**
     * When set, reset() will automatically clear the bindings.
     */
    public bool auto_clear { get; set; default = false; }

    /**
     * Emitted when the step method receives a row.
     */
    public signal void received_row ();

    /**
     * The queryable this statement operates on.
     */
    public weak SQLHeavy.Queryable queryable { get; construct set; }
    private unowned Sqlite.Statement stmt;

    /**
     * The SQL query used to create this statement.
     */
    private string? _sql = null;
    public string sql {
      get {
        return this._sql;
      }

      construct {
        this._sql = value;
      }
    }

    /**
     * The number of parameters in the statement.
     */
    public int parameter_count { get { return this.stmt.bind_parameter_count (); } }

    /**
     * The number of columns in the result set.
     */
    public int column_count { get { return this.stmt.column_count (); } }

    /**
     * Whether we have finished iterating through the result set.
     */
    public bool finished { get; private set; default = false; }

    /**
     * Whether the query is currently iterating through a result set
     * (i.e., step() has been called but not yet returned false).
     */
    public bool active { get; private set; default = false; }

    /**
     * Number of times that SQLite has stepped forward in a table as
     * part of a full table scan.
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/c_stmtstatus_fullscan_step.html]]
     */
    public int full_scan_steps { get { return this.stmt.status (Sqlite.StatementStatus.FULLSCAN_STEP, 0); } }

    /**
     * This is the number of sort operations that have occurred.
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/c_stmtstatus_fullscan_step.html]]
     */
    public int sort_operations { get { return this.stmt.status (Sqlite.StatementStatus.SORT, 0); } }

    /**
     * Reset the statement, allowing for another execution.
     */
    public void reset () {
      if ( this.active )
        this.queryable.query_executed (this);

      if ( this.auto_clear )
        this.stmt.clear_bindings ();
      this.stmt.reset ();
      this.finished = false;
      this.result_columns = null;
      this.execution_timer.reset ();
    }

    private bool step_handle () throws Error {
      int ec = this.error_code;
      this.error_code = Sqlite.OK;

      if ( ec == Sqlite.ROW ) {
        this.received_row ();
        return true;
      }
      else if ( ec == Sqlite.DONE ) {
        this.finished = true;
        this.active = false;
        this.queryable.query_executed (this);
        return false;
      }
      else {
        error_if_not_ok (ec, this.queryable);
      }

      GLib.assert_not_reached ();
    }

    /**
     * Internal function to step the transaction, assumes relevant
     * locks have been acquired.
     */
    public bool step_internal () throws Error {
      if ( this.finished )
        return false;

      if ( !this.active ) {
        this.active = true;
        this.execution_timer.reset ();
        this.execution_timer.start ();
        this.error_code = this.stmt.step ();
        this.execution_timer.stop ();
      }
      else {
        this.execution_timer.start ();
        this.error_code = this.stmt.step ();
        this.execution_timer.stop ();
      }

      return this.step_handle ();
    }

    /**
     * Evaluate the statement.
     *
     * @return true on success, false if the query is finished executing
     * @see Statement.step_async
     * @see Statement.execute
     */
    public bool step () throws Error {
      var db = this.queryable.database;

      this.queryable.@lock ();
      db.step_lock ();
      var res = this.step_internal ();
      db.step_unlock ();
      this.queryable.unlock ();
      return res;
    }

    /**
     * Evaluate the statement asynchronously
     *
     * @return true on success, false if the query is finished executing
     * @see Statement.step
     * @see Statement.execute_async
     */
    public async bool step_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      return true;
    }

    /**
     * Completely evaluate the statement, calling step () until it returns false.
     *
     * @see Statement.step
     * @see Statement.execute_async
     */
    public void execute () throws SQLHeavy.Error {
      var db = this.queryable.database;

      this.queryable.@lock ();
      db.step_lock ();
      while ( this.step_internal () ) { }
      db.step_unlock ();
      this.queryable.unlock ();

      this.reset ();
    }

    /**
     * Completely evaluate the statement asynchronously, calling step
     * until it returns false.
     *
     * @param cancellable a cancellable used to abort the operation
     *
     * @see Statement.step
     * @see Statement.execute
     */
    public async void execute_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      SQLHeavy.Error? err = null;
      try {
        GLib.Thread.create (() => {
            bool executing = false;
            GLib.Mutex lck = new GLib.Mutex ();
            unowned GLib.Thread th = GLib.Thread.self ();
            ulong cancellable_sig = 0;

            if ( cancellable != null ) {
              cancellable_sig = cancellable.cancelled.connect (() => {
                  lck.@lock ();
                  if ( executing )
                    this.queryable.database.interrupt ();
                  else {
                    err = new SQLHeavy.Error.INTERRUPTED (sqlite_errstr (Sqlite.INTERRUPT));
                    th.exit (null);
                  }
                  lck.unlock ();
                });
            }

            var db = this.queryable.database;
            db.step_lock ();
            executing = true;
            try {
              while ( (cancellable == null ||
                       !cancellable.is_cancelled ()) &&
                      this.step_internal () ) { }
            }
            catch ( SQLHeavy.Error e ) {
              err = e;
            }
            lck.@lock ();
            executing = false;
            db.step_unlock ();
            lck.unlock ();

            if ( cancellable_sig != 0 ) {
              cancellable.disconnect (cancellable_sig);
            }

            execute_async.callback ();

            return null;
          }, false);
      }
      catch ( GLib.ThreadError e ) {
        throw new SQLHeavy.Error.THREAD ("Thread error: %s (%d)", e.message, e.code);
      }

      yield;

      if ( err != null )
        throw err;

      this.reset ();
    }

    /**
     * Execute the statement, and return the last insert ID.
     *
     * @return the last inserted row ID
     */
    public int64 execute_insert () throws SQLHeavy.Error {
      this.queryable.@lock ();
      this.active = true;
      this.execute ();
      var last_insert_id = this.queryable.database.last_insert_id;
      this.queryable.@unlock ();

      this.reset ();

      return last_insert_id;
    }

    private int fetch_check_index (int col) throws SQLHeavy.Error {
      if (col < 0 || col > this.column_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));
      return col;
    }

    /**
     * Fetch the column name for the specified index
     *
     * @param col index of column to fetch
     * @return the name of the column
     * @see column_index
     */
    public unowned string column_name (int col) throws SQLHeavy.Error {
      return this.stmt.column_name (this.fetch_check_index (col));
    }

    /**
     * Fetch the index for the specified column name
     *
     * @param col column name
     * @return the index of the column
     * @see column_name
     */
    public int column_index (string col) throws SQLHeavy.Error {
      if ( this.result_columns == null ) {
        this.result_columns = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);
        var ncols = this.column_count;
        for ( int c = 0 ; c < ncols ; c++ )
          this.result_columns.replace (this.column_name (c), c);
      }

      int? col_number = this.result_columns.lookup (col);
      if ( col_number == null )
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));
      return col_number;
    }

    /**
     * Get column type
     *
     * @param col the column index
     * @return the GType of the column
     * @see column_name
     */
    public GLib.Type column_type (int col) throws SQLHeavy.Error {
      return sqlite_type_to_g_type (this.stmt.column_type (this.fetch_check_index (col)));
    }

    /**
     * Return a field from result.
     *
     * @param col the index of the column to return.
     * @return the value of the field
     * @see fetch_named
     * @see fetch_result
     */
    public GLib.Value? fetch (int col) throws SQLHeavy.Error {
      return sqlite_value_to_g_value (this.stmt.column_value (this.fetch_check_index (col)));
    }

    /**
     * Fetch a field from the result by name
     *
     * @param col column name
     * @return the field value
     * @see fetch
     * @see fetch_result
     */
    public GLib.Value? fetch_named (string col) throws SQLHeavy.Error {
      return this.fetch (this.column_index (col));
    }

    /**
     * Fetch a field from the result as a string
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_string
     * @see fetch_result_string
     * @see fetch
     */
    public string? fetch_string (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_text (this.fetch_check_index (col));
    }

    /**
     * Fetch a field from the result as a string by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_string
     * @see fetch_result_string
     * @see fetch
     */
    public string? fetch_named_string (string col) throws SQLHeavy.Error {
      return this.fetch_string (this.column_index (col));
    }

    /**
     * Fetch a field from the result as an integer
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_int
     * @see fetch_result_int
     * @see fetch
     */
    public int fetch_int (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_int (this.fetch_check_index (col));
    }

    /**
     * Fetch a field from the result as an integer by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_int
     * @see fetch_result_int
     * @see fetch
     */
    public int fetch_named_int (string col) throws SQLHeavy.Error {
      return this.fetch_int (this.column_index (col));
    }

    /**
     * Fetch a field from the result as a signed 64-bit integer
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_int64
     * @see fetch_result_int64
     * @see fetch
     */
    public int64 fetch_int64 (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_int64 (this.fetch_check_index (col));
    }

    /**
     * Fetch a field from the result as a signed 64-bit integer by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_int64
     * @see fetch_result_int64
     * @see fetch
     */
    public int64 fetch_named_int64 (string col) throws SQLHeavy.Error {
      return this.fetch_int64 (this.column_index (col));
    }

    /**
     * Fetch a field from the result as a double
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_double
     * @see fetch_result_double
     * @see fetch
     */
    public double fetch_double (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_double (this.fetch_check_index (col));
    }

    /**
     * Fetch a field from the result as a double by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_double
     * @see fetch_result_double
     * @see fetch
     */
    public double fetch_named_double (string col) throws SQLHeavy.Error {
      return this.fetch_double (this.column_index (col));
    }

    /**
     * Fetch a field from the result as an array of bytes
     *
     * @param col column index
     * @return the field value
     * @see fetch_named_blob
     * @see fetch_result_blob
     * @see fetch
     */
    public uint8[] fetch_blob (int col = 0) throws SQLHeavy.Error {
      var res = new uint8[this.stmt.column_bytes(this.fetch_check_index (col))];
      GLib.Memory.copy (res, this.stmt.column_blob (col), res.length);
      return res;
    }

    /**
     * Fetch a field from the result as an array of bytes by name
     *
     * @param col column name
     * @return the field value
     * @see fetch_blob
     * @see fetch_result_blob
     * @see fetch
     */
    public uint8[] fetch_named_blob (string col) throws SQLHeavy.Error {
      return this.fetch_blob (this.column_index (col));
    }

    /**
     * Fetch result
     *
     * This function will call {@link step} once, then return the
     * result of a {@link fetch} on the specified column after calling
     * {@link reset}.
     *
     * @param col the index of the column to fetch
     * @return the value of the field
     * @see step
     * @see fetch
     * @see reset
     */
    public GLib.Value? fetch_result (int col = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch (col);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as a string
     *
     * @param col column index
     * @return value of the field
     * @see fetch_result
     * @see fetch_string
     */
    public string? fetch_result_string (int col = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_string (col);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as an int
     *
     * @param col column index
     * @return value of the field
     * @see fetch_result
     * @see fetch_int
     */
    public int fetch_result_int (int col = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_int (col);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as an int64
     *
     * @param col column index
     * @return value of the field
     * @see fetch_result
     * @see fetch_int64
     */
    public int64 fetch_result_int64 (int col = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_int64 (col);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as a double
     *
     * @param col column index
     * @return value of the field
     * @see fetch_result
     * @see fetch_double
     */
    public double fetch_result_double (int col = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_double (col);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as an array of bytes
     *
     * @param col column index
     * @return value of the field
     * @see fetch_result
     * @see fetch_blob
     */
    public uint8[] fetch_result_blob (int col = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_blob (col);
      this.reset ();
      return ret;
    }

    private int bind_check_index (int col) throws SQLHeavy.Error {
      if (col < 0 || col > this.parameter_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));
      return col;
    }

    /**
     * Get index of the named parameter
     *
     * @param col name of the parameter
     * @return index of the parameter
     */
    public int bind_get_index (string col) throws SQLHeavy.Error {
      var idx = this.stmt.bind_parameter_index (col);
      if ( idx == 0 )
        throw new SQLHeavy.Error.RANGE ("Could not find parameter '%s'.", col);
      return idx;
    }

    /**
     * Get the name of a parameter
     *
     * @param col index of the parameter
     * @return name of the parameter
     */
    public unowned string bind_get_name (int col) throws SQLHeavy.Error {
      return this.stmt.bind_parameter_name (this.bind_check_index (col));
    }

    /**
     * Bind a value to the specified parameter
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind_named
     */
    public void bind (int col, GLib.Value? value) throws SQLHeavy.Error {
      this.bind_check_index (col);

      if ( value == null )
        this.stmt.bind_null (col);
      else if ( value.holds (typeof (int)) )
        this.stmt.bind_int (col, value.get_int ());
      else if ( value.holds (typeof (int64)) )
        this.stmt.bind_int64 (col, value.get_int64 ());
      else if ( value.holds (typeof (string)) )
        this.stmt.bind_text (col, value.get_string ());
      else if ( value.holds (typeof (double)) )
        this.stmt.bind_double (col, value.get_double ());
      else if ( value.holds (typeof (float)) )
        this.stmt.bind_double (col, value.get_float ());
      else if ( value.holds (typeof (GLib.ByteArray)) ) {
        unowned GLib.ByteArray ba = value as GLib.ByteArray;
        this.stmt.bind_blob (col, GLib.Memory.dup (ba.data, ba.len), (int) ba.len, GLib.g_free);
      }
      else
        throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");
    }

    /**
     * Bind a value to the specified parameter by name
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind
     */
    public void bind_named (string name, GLib.Value? value) throws SQLHeavy.Error {
      this.bind (this.bind_get_index (name), value);
    }

    /**
     * Bind an int value to the specified parameter
     *
     * @param col index of the parameter
     * @param value value to bind
     * @see bind_named_int
     * @see bind
     */
    public void bind_int (int col, int value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int (this.bind_check_index (col), value), this.queryable);
    }

    /**
     * Bind an int value to the specified named parameter
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind_int
     * @see bind
     */
    public void bind_named_int (string col, int value) throws SQLHeavy.Error {
      this.bind_int (this.bind_get_index (col), value);
    }

    /**
     * Bind an int64 value to the specified parameter
     *
     * @param col index of the parameter
     * @param value value to bind
     * @see bind_named_int64
     * @see bind
     */
    public void bind_int64 (int col, int64 value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int64 (this.bind_check_index (col), value), this.queryable);
    }

    /**
     * Bind an int64 value to the specified named parameter
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind_int64
     * @see bind
     */
    public void bind_named_int64 (string col, int64 value) throws SQLHeavy.Error {
      this.bind_int64 (this.bind_get_index (col), value);
    }

    /**
     * Bind a string value to the specified parameter
     *
     * @param col index of the parameter
     * @param value value to bind
     * @see bind_named_string
     * @see bind
     */
    public void bind_string (int col, string? value) throws SQLHeavy.Error {
      if ( value == null )
        this.bind_null (col);
      else
        error_if_not_ok (this.stmt.bind_text (this.bind_check_index (col), value), this.queryable);
    }

    /**
     * Bind a string value to the specified named parameter
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind_string
     * @see bind
     */
    public void bind_named_string (string col, string? value) throws SQLHeavy.Error {
      this.bind_string (this.bind_get_index (col), value);
    }

    /**
     * Bind null to the specified parameter
     *
     * @param col index of the parameter
     * @see bind_named_null
     * @see bind
     */
    public void bind_null (int col) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_null (this.bind_check_index (col)), this.queryable);
    }

    /**
     * Bind null to the specified named parameter
     *
     * @param col name of the parameter
     * @see bind_null
     * @see bind
     */
    public void bind_named_null (string col) throws SQLHeavy.Error {
      this.bind_null (this.bind_get_index (col));
    }

    /**
     * Bind an double value to the specified parameter
     *
     * @param col index of the parameter
     * @param value value to bind
     * @see bind_named_double
     * @see bind
     */
    public void bind_double (int col, double value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_double (this.bind_check_index (col), value), this.queryable);
    }

    /**
     * Bind an double value to the specified named parameter
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind_double
     * @see bind
     */
    public void bind_named_double (string col, double value) throws SQLHeavy.Error {
      this.bind_double (this.bind_get_index (col), value);
    }

    /**
     * Bind a byte array value to the specified parameter
     *
     * @param col index of the parameter
     * @param value value to bind
     * @see bind_named_blob
     * @see bind
     */
    public void bind_blob (int col, uint8[] value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_blob (col, GLib.Memory.dup (value, value.length), value.length, GLib.g_free), this.queryable);
    }

    /**
     * Bind a byte array value to the specified named parameter
     *
     * @param col name of the parameter
     * @param value value to bind
     * @see bind_blob
     * @see bind
     */
    public void bind_named_blob (string col, uint8[] value) throws SQLHeavy.Error {
      this.bind_blob (this.bind_get_index (col), value);
    }

    ~ Statement () {
      // GObject *really* doesn't like this. Need to figure out a way
      // to emit the query_executed signal here...
      //if ( this.active )
      //  this.queryable.query_executed (this);
      sqlite3_finalize (this.stmt);
    }

    /**
     * Fetch a column from the result set
     *
     * This function will call {@link step} automatically, so you
     * probably don't want to call it from an already active
     * transaction.
     *
     * @param col column offset
     * @return a {@link GLib.ValueArray} of fields
     */
    public GLib.ValueArray get_column (int col) throws SQLHeavy.Error {
      var valid = this.step ();
      var data = new GLib.ValueArray (this.column_count);

      while ( valid ) {
        data.append (this.fetch (col));
        valid = this.step ();
      }

      return data;
    }

    construct {
      this.execution_timer.stop ();
      this.execution_timer.reset ();

      unowned string tail;
      this.error_code = sqlite3_prepare (queryable.database.get_sqlite_db (), this._sql, -1, out this.stmt, out tail);
      if ( this.error_code == Sqlite.OK )
        this._sql = this.stmt.sql ();
      else
        GLib.critical ("Unable to create statement: %s", sqlite_errstr (this.error_code));
    }

    /**
     * Create a prepared statement.
     *
     * @param queryable The database to use.
     * @param sql An SQL query.
     * @param max_len the maximum length of the SQL query
     * @param tail Where to store the any unprocessed part of the query.
     * @see Queryable.prepare
     */
    public Statement.full (SQLHeavy.Queryable queryable, string sql, int max_len = -1, out unowned string tail = null) throws Error {
      Object (queryable: queryable, sql: sql);
      error_if_not_ok (sqlite3_prepare (queryable.database.get_sqlite_db (), sql, max_len, out this.stmt, out tail), queryable);
    }

    /**
     * Create a prepared statement.
     *
     * @param queryable The database to use.
     * @param sql An SQL query.
     * @see SQLHeavy.Queryable.prepare
     */
    public Statement (SQLHeavy.Queryable queryable, string sql) throws SQLHeavy.Error {
      Object (queryable: queryable, sql: sql);
      error_if_not_ok (this.error_code);
    }
  }
}
