namespace SQLHeavy {
  [CCode (cname = "sqlite3_finalize", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_finalize (Sqlite.Statement stmt);
  [CCode (cname = "sqlite3_prepare_v2", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_prepare (Sqlite.Database db, string sql, int n_bytes, out unowned Sqlite.Statement stmt, out unowned string? tail = null);

  /**
   * A prepared statement.
   */
  public class Statement : GLib.Object, Record {
    /**
     * Error code from the last completed SQLite operation
     */
    private int error_code = Sqlite.OK;

    /**
     * Map of the names of fields to their index
     */
    private GLib.HashTable<string, int?>? result_fields = null;

    /**
     * The amount of time (wall-clock) the query has spend execution.
     */
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
    public weak SQLHeavy.Queryable queryable { get; construct; }

    /**
     * The SQLite statement for this SQLHeavy statement
     */
    private unowned Sqlite.Statement stmt;

    /**
     * The SQL query used to create this statement.
     */
    private string _sql;
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
     * {@inheritDoc}
     */
    public int field_count { get { return this.stmt.column_count (); } }

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
     * Clear bindings
     */
    public void clear_bindings () {
      this.stmt.clear_bindings ();
    }

    /**
     * Reset the statement, allowing for another execution.
     */
    public void reset () {
      if ( this.active )
        this.queryable.query_executed (this);

      if ( this.auto_clear )
        this.clear_bindings ();

      this.stmt.reset ();
      this.finished = false;
      this.result_fields = null;
      this.execution_timer.reset ();
    }

    /**
     * Internal function to step the transaction.
     *
     * This function assumes relevant locks have been acquired.
     *
     * @return true on success, false if the query is done executing
     * @see step
     * @see step_async
     * @see execute
     */
    internal bool step_internal () throws Error {
      if ( this.finished )
        return false;

      if ( !this.active ) {
        this.active = true;
        this.execution_timer.reset ();
      }

      this.execution_timer.start ();
      this.error_code = this.stmt.step ();
      this.execution_timer.stop ();

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
     * Handle asynchronous execution
     *
     * @param steps the maximum number of times to call {@link step}, or -1
     * @param cancellable a GCancellable, or null
     * @return true if there is more data, false if the query is done
     */
    private async bool step_internal_async (int steps = 0, GLib.Cancellable? cancellable = null, bool capture_last_insert_id = false, out int64 last_insert_id = null) throws SQLHeavy.Error {
      SQLHeavy.Error? err = null;
      bool step_res = false;
      int64 insert_id = 0;
      try {
        GLib.Thread.create (() => {
            bool executing = false;
            unowned GLib.Thread th = GLib.Thread.self ();
            ulong cancellable_sig = 0;
            bool thread_exited = false;

            if ( cancellable != null ) {
              cancellable_sig = cancellable.cancelled.connect (() => {
                  if ( executing )
                    this.queryable.database.interrupt ();
                  else {
                    thread_exited = true;
                    err = new SQLHeavy.Error.INTERRUPTED (sqlite_errstr (Sqlite.INTERRUPT));
                    execute_async.callback ();
                    th.exit (null);
                  }
                });
            }

            var db = this.queryable.database;

            this.queryable.@lock ();
            db.step_lock ();
            executing = true;
            try {
              while ( steps != 0 ) {
                if ( (cancellable != null && cancellable.is_cancelled ()) || !(step_res = this.step_internal ()) )
                  break;
                if ( steps > 0 )
                  steps--;
              }
            }
            catch ( SQLHeavy.Error e ) {
              err = e;
            }

            if ( !thread_exited ) {
              if ( capture_last_insert_id )
                insert_id = this.queryable.database.last_insert_id;

              db.step_unlock ();
              this.queryable.unlock ();
              executing = false;

              if ( cancellable_sig != 0 ) {
                cancellable.disconnect (cancellable_sig);
              }

              step_internal_async.callback ();
            }

            return null;
          }, false);
      }
      catch ( GLib.ThreadError e ) {
        throw new SQLHeavy.Error.THREAD ("Thread error: %s (%d)", e.message, e.code);
      }

      yield;

      if ( err != null )
        throw err;

      if ( capture_last_insert_id )
        last_insert_id = insert_id;

      this.reset ();

      return step_res;
    }

    /**
     * Evaluate the statement asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @return true on success, false if the query is finished executing
     * @see Statement.step
     * @see Statement.execute_async
     */
    public async bool step_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      int64 last_insert_id;
      return yield this.step_internal_async (1, cancellable, false, out last_insert_id);
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
      int64 last_insert_id;
      yield this.step_internal_async (-1, cancellable, false, out last_insert_id);
    }

    /**
     * Execute the statement, and return the last insert ID.
     *
     * This function should be used instead of {@link execute} and
     * {@link Database.last_insert_id} because it will execute fetch
     * the last insert id while the {@link queryable} is locked for
     * the execution.
     *
     * @return the last inserted row ID
     * @see execute_insert_async
     * @see Database.last_insert_id
     * @see execute
     * @see step
     */
    public int64 execute_insert () throws SQLHeavy.Error {
      var db = this.queryable.database;

      this.queryable.@lock ();
      db.step_lock ();
      this.active = true;
      while ( this.step_internal () ) { }
      var last_insert_id = this.queryable.database.last_insert_id;
      db.step_unlock ();
      this.queryable.@unlock ();

      this.reset ();

      return last_insert_id;
    }

    /**
     * Asynchronously execute the statement, and return the last insert ID.
     *
     * This function should be used instead of {@link execute_async}
     * and {@link Database.last_insert_id} because it will execute
     * fetch the last insert id while the {@link queryable} is locked
     * for the execution.
     *
     * @return the last inserted row ID
     * @see execute_insert
     * @see Database.last_insert_id
     * @see execute_async
     * @see step_async
     */
    public async int64 execute_insert_async (GLib.Cancellable? cancellable) throws SQLHeavy.Error {
      int64 last_insert_id = 0;
      yield this.step_internal_async (-1, cancellable, true, out last_insert_id);
      return last_insert_id;
    }

    /**
     * Check to see that the specified index is valid, throw an error if not.
     *
     * @param field index of the field to check
     * @return field
     */
    private int fetch_check_index (int field) throws SQLHeavy.Error {
      if (field < 0 || field > this.field_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));
      return field;
    }

    /**
     * {@inheritDoc}
     */
    public string field_name (int field) throws SQLHeavy.Error {
      return this.stmt.column_name (this.fetch_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int field_index (string field) throws SQLHeavy.Error {
      if ( this.result_fields == null ) {
        this.result_fields = new GLib.HashTable<string, int?>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_free);
        var nfields = this.field_count;
        for ( int c = 0 ; c < nfields ; c++ )
          this.result_fields.replace (this.field_name (c), c);
      }

      int? field_number = this.result_fields.lookup (field);
      if ( field_number == null )
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));
      return (!) field_number;
    }

    /**
     * {@inheritDoc}
     */
    public GLib.Type field_type (int field) throws SQLHeavy.Error {
      return sqlite_type_to_g_type (this.stmt.column_type (this.fetch_check_index (field)));
    }

    /**
     * Name of the table that is the origin of a field
     *
     * @param field index of the field
     * @return the table
     * @see field_origin_table
     */
    public string field_origin_table_name (int field) throws SQLHeavy.Error {
      return this.stmt.column_table_name (this.fetch_check_index (field));
    }

    /**
     * Table that is the origin of a field
     *
     * @param field index of the field
     * @return the table
     * @see field_origin_table_name
     */
    public SQLHeavy.Table field_origin_table (int field) throws SQLHeavy.Error {
      return new SQLHeavy.Table (this.queryable, this.field_origin_table_name (field));
    }

    /**
     * Name of the column that is the origin of a field
     *
     * @param field index of the field
     * @return the table name
     */
    public string field_origin_name (int field) throws SQLHeavy.Error {
      return this.stmt.column_origin_name (this.fetch_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public GLib.Value fetch (int field) throws SQLHeavy.Error {
      return sqlite_value_to_g_value (this.stmt.column_value (this.fetch_check_index (field)));
    }

    /**
     * {@inheritDoc}
     */
    public string? fetch_string (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_text (this.fetch_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int fetch_int (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_int (this.fetch_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public int64 fetch_int64 (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_int64 (this.fetch_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public double fetch_double (int field = 0) throws SQLHeavy.Error {
      return this.stmt.column_double (this.fetch_check_index (field));
    }

    /**
     * {@inheritDoc}
     */
    public uint8[] fetch_blob (int field = 0) throws SQLHeavy.Error {
      var res = new uint8[this.stmt.column_bytes(this.fetch_check_index (field))];
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
      var stmt = this.queryable.prepare (@"SELECT `ROWID` FROM `$(foreign_table.name)` WHERE `$(foreign_column)` = :value;");
      stmt.bind_index_int64 (1, this.fetch_int64 (field));
      return new SQLHeavy.Row (foreign_table, stmt.fetch_result_int64 ());
    }

    /**
     * Fetch result
     *
     * This function will call {@link step} once, then return the
     * result of a {@link fetch} on the specified field after calling
     * {@link reset}.
     *
     * @param field the index of the field to fetch
     * @return the value of the field
     * @see step
     * @see Record.fetch
     * @see reset
     */
    public GLib.Value? fetch_result (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as a string
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_string
     */
    public string? fetch_result_string (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_string (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as an int
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_int
     */
    public int fetch_result_int (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_int (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as an int64
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_int64
     */
    public int64 fetch_result_int64 (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_int64 (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as a time_t
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_time_t
     */
    public int64 fetch_result_time_t (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = (time_t) this.fetch_int64 (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as a double
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_double
     */
    public double fetch_result_double (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_double (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as an array of bytes
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_blob
     */
    public uint8[] fetch_result_blob (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_blob (field);
      this.reset ();
      return ret;
    }

    /**
     * Fetch result row
     *
     * @return fields in the row
     * @see fetch_result
     * @see Record.fetch_row
     */
    public GLib.ValueArray fetch_result_row () throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_row ();
      this.reset ();
      return ret;
    }

    /**
     * Fetch result as row in a foreign table
     *
     * @param field field index
     * @return value of the field
     * @see fetch_result
     * @see Record.fetch_foreign_row
     */
    public SQLHeavy.Row fetch_result_foreign_row (int field = 0) throws SQLHeavy.Error {
      this.step ();
      var ret = this.fetch_foreign_row (field);
      this.reset ();
      return ret;
    }

    /**
     * {@inheritDoc}
     *
     * This function will always throw an error when called on a
     * {@link Statement}
     */
    public void save () throws SQLHeavy.Error {
      throw new SQLHeavy.Error.READ_ONLY ("Cannot write to a read-only record.");
    }

    /**
     * {@inheritDoc}
     *
     * This function will always throw an error when called on a
     * {@link Statement}
     */
    public void delete () throws SQLHeavy.Error {
      throw new SQLHeavy.Error.READ_ONLY ("Cannot write to a read-only record.");
    }

    /**
     * {@inheritDoc}
     *
     * This function will always throw an error when called on a
     * {@link Statement}
     */
    public void put (int field, GLib.Value value) throws SQLHeavy.Error {
      throw new SQLHeavy.Error.READ_ONLY ("Cannot write to a read-only record.");
    }

    /**
     * Return the next row from the result
     *
     * @return the next row, or null if there is none
     * @see Record.fetch_row
     */
    public GLib.ValueArray? get_row () throws SQLHeavy.Error {
      if ( this.step () )
        return this.fetch_row ();
      else
        return null;
    }

    /**
     * Read the entire result set into an array
     *
     * @return a GValueArray of (boxed) GValueArrays representing rows and fields, respectively
     * @see get_row
     * @see print_table
     * @see Queryable.get_table
     */
    public GLib.ValueArray get_table () throws SQLHeavy.Error {
      var data = new GLib.ValueArray (0);
      GLib.ValueArray? row = null;

      while ( (row = this.get_row ()) != null )
        data.append ((!) row);

      return data;
    }

    /**
     * Print the result set to a file stream
     *
     * @param fd the stream to print to
     * @see get_table
     * @see Queryable.print_table
     */
    public void print_table (GLib.FileStream? fd = null) throws SQLHeavy.Error {
      var field_names = this.field_names ();
      var field_lengths = new long[field_names.length];
      var data = new GLib.GenericArray<GLib.GenericArray <string>> ();

      if ( fd == null )
        fd = GLib.stderr;
      int field = 0;

      for ( field = 0 ; field < field_lengths.length ; field++ )
        field_lengths[field] = field_names[field].len ();

      while ( this.step () ) {
        var row_data = new GLib.GenericArray<string> ();
        data.add (row_data);

        for ( field = 0 ; field < field_names.length ; field++ ) {
          var cell = this.fetch_string (field);
          var cell_l = cell.len ();
          if ( field_lengths[field] < cell_l )
            field_lengths[field] = cell_l;

          row_data.add (cell);
        }
      }

      GLib.StringBuilder sep = new GLib.StringBuilder ("+");
      for ( field = 0 ; field < field_names.length ; field++ ) {
        for ( var c = 0 ; c < field_lengths[field] + 2 ; c++ )
          sep.append_c ('-');
        sep.append_c ('+');
      }
      sep.append_c ('\n');

      var field_fmt = new string[field_names.length];
      fd.puts (sep.str);
      fd.putc ('|');
      for ( field = 0 ; field < field_names.length ; field++ ) {
        field_fmt[field] = " %%%lds |".printf (field_lengths[field]);
        fd.printf (field_fmt[field], field_names[field]);
      }
      fd.putc ('\n');
      fd.puts (sep.str);

      for ( var row_n = 0 ; row_n < data.length ; row_n++ ) {
        var row_data = data[row_n];

        fd.putc ('|');
        for ( var col_n = 0 ; col_n < row_data.length ; col_n++ )
          fd.printf (field_fmt[col_n], row_data[col_n]);
        fd.putc ('\n');
        fd.puts (sep.str);
      }
    }

    /**
     * Check to see that the specified field is valid, throw an error
     * if it is otherwise
     *
     * @param field index of the field to check
     * @return field that was checked
     * @see fetch_check_index
     */
    private int bind_check_index (int field) throws SQLHeavy.Error {
      if (field < 0 || field > this.parameter_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));
      return field;
    }

    /**
     * Get index of the named parameter
     *
     * @param field name of the parameter
     * @return index of the parameter
     */
    public int bind_get_index (string field) throws SQLHeavy.Error {
      var idx = this.stmt.bind_parameter_index (field);
      if ( idx == 0 )
        throw new SQLHeavy.Error.RANGE ("Could not find parameter '%s'.", field);
      return idx;
    }

    /**
     * Get the name of a parameter
     *
     * @param field index of the parameter
     * @return name of the parameter
     */
    public unowned string bind_get_name (int field) throws SQLHeavy.Error {
      return this.stmt.bind_parameter_name (this.bind_check_index (field));
    }

    /**
     * Bind a value to the specified parameter index
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind
     */
    public void bind_index (int field, GLib.Value? value) throws SQLHeavy.Error {
      this.bind_check_index (field);

      if ( value == null )
        this.stmt.bind_null (field);
      else if ( value.holds (typeof (int)) )
        this.stmt.bind_int (field, value.get_int ());
      else if ( value.holds (typeof (int64)) )
        this.stmt.bind_int64 (field, value.get_int64 ());
      else if ( value.holds (typeof (string)) )
        this.stmt.bind_text (field, value.get_string ());
      else if ( value.holds (typeof (double)) )
        this.stmt.bind_double (field, value.get_double ());
      else if ( value.holds (typeof (float)) )
        this.stmt.bind_double (field, value.get_float ());
      else if ( value.holds (typeof (GLib.ByteArray)) ) {
        unowned GLib.ByteArray ba = (GLib.ByteArray) value;
        this.stmt.bind_blob (field, GLib.Memory.dup (ba.data, ba.len), (int) ba.len, GLib.g_free);
      }
      else
        throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");
    }

    /**
     * Bind a value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_index
     */
    public void bind_value (string name, GLib.Value? value) throws SQLHeavy.Error {
      this.bind_index (this.bind_get_index (name), value);
    }

    /**
     * Bind an int value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see bind_int
     * @see bind_index
     */
    public void bind_index_int (int field, int value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int (this.bind_check_index (field), value), this.queryable);
    }

    /**
     * Bind an int value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_index_int
     * @see bind
     */
    public void bind_int (string field, int value) throws SQLHeavy.Error {
      this.bind_index_int (this.bind_get_index (field), value);
    }

    /**
     * Bind an int64 value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see bind_int64
     * @see bind_index
     */
    public void bind_index_int64 (int field, int64 value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int64 (this.bind_check_index (field), value), this.queryable);
    }

    /**
     * Bind an int64 value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_index_int64
     * @see bind
     */
    public void bind_int64 (string field, int64 value) throws SQLHeavy.Error {
      this.bind_index_int64 (this.bind_get_index (field), value);
    }

    /**
     * Bind a string value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see bind_string
     * @see bind_index
     */
    public void bind_index_string (int field, string? value) throws SQLHeavy.Error {
      if ( value == null )
        this.bind_index_null (field);
      else
        error_if_not_ok (this.stmt.bind_text (this.bind_check_index (field), (!) value), this.queryable);
    }

    /**
     * Bind a string value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_index_string
     * @see bind
     */
    public void bind_string (string field, string? value) throws SQLHeavy.Error {
      this.bind_index_string (this.bind_get_index (field), value);
    }

    /**
     * Bind null to the specified parameter index
     *
     * @param field index of the parameter
     * @see bind_null
     * @see bind_index
     */
    public void bind_index_null (int field) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_null (this.bind_check_index (field)), this.queryable);
    }

    /**
     * Bind null to the specified parameter
     *
     * @param field name of the parameter
     * @see bind_index_null
     * @see bind
     */
    public void bind_null (string field) throws SQLHeavy.Error {
      this.bind_index_null (this.bind_get_index (field));
    }

    /**
     * Bind a double value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see bind_double
     * @see bind_index
     */
    public void bind_index_double (int field, double value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_double (this.bind_check_index (field), value), this.queryable);
    }

    /**
     * Bind an double value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_index_double
     * @see bind
     */
    public void bind_double (string field, double value) throws SQLHeavy.Error {
      this.bind_index_double (this.bind_get_index (field), value);
    }

    /**
     * Bind a byte array value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see bind_blob
     * @see bind_index
     */
    public void bind_index_blob (int field, uint8[] value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_blob (field, GLib.Memory.dup (value, value.length), value.length, GLib.g_free), this.queryable);
    }

    /**
     * Bind a byte array value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_index_blob
     * @see bind
     */
    public void bind_blob (string field, uint8[] value) throws SQLHeavy.Error {
      this.bind_index_blob (this.bind_get_index (field), value);
    }

    ~ Statement () {
      // GObject *really* doesn't like this. Need to figure out a way
      // to emit the query_executed signal here...
      //if ( this.active )
      //  this.queryable.query_executed (this);
      sqlite3_finalize (this.stmt);
    }

    /**
     * Fetch a field from the result set
     *
     * This function will call {@link step} automatically, so you
     * probably don't want to call it from an already active
     * transaction.
     *
     * @param field field offset
     * @return fields
     */
    public GLib.ValueArray get_field (int field) throws SQLHeavy.Error {
      var valid = this.step ();
      var data = new GLib.ValueArray (0);

      while ( valid ) {
        data.append (this.fetch (field));
        valid = this.step ();
      }

      return data;
    }

    construct {
      this.execution_timer.stop ();
      this.execution_timer.reset ();

      unowned string? tail;
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
    public Statement.full (SQLHeavy.Queryable queryable, string sql, int max_len = -1, out unowned string? tail = null) throws Error {
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
