namespace SQLHeavy {
  /**
   * A prepared statement
   */
  public class Query : GLib.Object {
    /**
     * The queryable asscociated with this query
     */
    public SQLHeavy.Queryable queryable { get; construct; }

    /**
     * The SQL used to create this query 
     */
    public string sql { get; construct; }

    /**
     * The maximum length of the SQL used to create this query
     */
    public int sql_len { private get; construct; default = -1; }

    /**
     * The last error code
     */
    private int error_code = Sqlite.OK;

    /**
     * The SQLite statement associated with this query
     */
    private Sqlite.Statement? stmt = null;

    /**
     * Return the SQLite statement associated with this query
     */
    internal unowned Sqlite.Statement? get_statement () {
      return this.stmt;
    }

    /**
     * The currently active {@link QueryResult}, if any
     */
    public weak SQLHeavy.QueryResult? result { get; private set; }

    /**
     * When set the bindings will automatically be cleared when the
     * associated {@link QueryResult} is destroyed.
     */
    public bool auto_clear { get; set; default = false; }

    /**
     * The number of parameters in the query.
     */
    public int parameter_count { get; private set; default = 0; }

    /**
     * Check to make sure that specified parameter is valid
     *
     * @param parameter the parameter to check
     * @return the parameter
     */
    private int parameter_check_index (int parameter) throws SQLHeavy.Error {
      if (parameter < 0 || parameter > this.parameter_count)
        throw new SQLHeavy.Error.RANGE (sqlite_errstr (Sqlite.RANGE));

      return parameter;
    }

    /**
     * Return the name of the specified parameter
     *
     * @param parameter the parameter to look up
     * @return string representation of the parameter
     */
    public unowned string parameter_name (int parameter) throws SQLHeavy.Error {
      return this.stmt.bind_parameter_name (this.parameter_check_index (parameter));
    }

    /**
     * Return the numeric offset of the specified parameter
     *
     * @param parameter the parameter to look up
     * @return offset of the parameter
     */
    public int parameter_index (string parameter) throws SQLHeavy.Error {
      var idx = this.stmt.bind_parameter_index (parameter);
      if ( idx == 0 )
        throw new SQLHeavy.Error.RANGE ("Could not find parameter '%s'.", parameter);
      return idx;
    }

    /**
     * Callback to be invoked when the QueryResult is destroyed
     *
     * @param the {@link QueryResult}
     */
    private void query_result_destroyed_cb (GLib.Object query_result) {
      GLib.assert (query_result == this.result);

      this.queryable.query_executed (this);

      var prof_db = this.queryable.database.profiling_data;
      if ( prof_db != null )
        prof_db.insert ((SQLHeavy.QueryResult) query_result);

      if ( this.auto_clear )
        this.stmt.clear_bindings ();

      this.stmt.reset ();
      this.result = null;
    }

    /**
     * Execute the query
     *
     * @return the result
     */
    public SQLHeavy.QueryResult execute () throws SQLHeavy.Error {
      if ( this.result != null )
        throw new SQLHeavy.Error.MISUSE ("Cannot execute query again until existing SQLHeavyQueryResult is destroyed.");

      var res = new SQLHeavy.QueryResult (this);
      this.result = res;
      res.weak_ref (query_result_destroyed_cb);

      return res;
    }

    /**
     * Execute the query asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @return the result
     */
    public async SQLHeavy.QueryResult execute_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      if ( this.result != null )
        throw new SQLHeavy.Error.MISUSE ("Cannot execute query again until existing SQLHeavyQueryResult is destroyed.");

      var res = new SQLHeavy.QueryResult.no_exec (this);
      this.result = res;
      res.weak_ref (query_result_destroyed_cb);

      yield res.next_async (cancellable);

      return res;
    }

    /**
     * Execute the INSERT query
     *
     * @return the inserted row ID
     */
    public int64 execute_insert () throws SQLHeavy.Error {
      if ( this.result != null )
        throw new SQLHeavy.Error.MISUSE ("Cannot execute query again until existing SQLHeavyQueryResult is destroyed.");

      int64 insert_id = 0;

      {
        var res = new SQLHeavy.QueryResult.insert (this, out insert_id);
        this.result = res;
        res.weak_ref (query_result_destroyed_cb);
      }

      return insert_id;
    }

    /**
     * Execute the INSERT query asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @return the inserted row ID
     */
    public async int64 execute_insert_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      if ( this.result != null )
        throw new SQLHeavy.Error.MISUSE ("Cannot execute query again until existing SQLHeavyQueryResult is destroyed.");

      var res = new SQLHeavy.QueryResult.no_exec (this);
      this.result = res;
      res.weak_ref (query_result_destroyed_cb);

      int64 insert_id = 0;
      yield res.next_internal_async (cancellable, 1, out insert_id);

      return insert_id;
    }

    /**
     * Bind a value to the specified parameter index
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see set
     */
    public void bind (int parameter, GLib.Value? value) throws SQLHeavy.Error {
      this.parameter_check_index (parameter);

      if ( value == null )
        this.stmt.bind_null (parameter);
      else if ( value.holds (typeof (int)) )
        this.stmt.bind_int (parameter, value.get_int ());
      else if ( value.holds (typeof (int64)) )
        this.stmt.bind_int64 (parameter, value.get_int64 ());
      else if ( value.holds (typeof (string)) )
        this.stmt.bind_text (parameter, value.get_string ());
      else if ( value.holds (typeof (double)) )
        this.stmt.bind_double (parameter, value.get_double ());
      else if ( value.holds (typeof (float)) )
        this.stmt.bind_double (parameter, value.get_float ());
      else if ( value.holds (typeof (GLib.ByteArray)) ) {
        unowned GLib.ByteArray ba = (GLib.ByteArray) value;
        this.stmt.bind_blob (parameter, GLib.Memory.dup (ba.data, ba.len), (int) ba.len, GLib.g_free);
      }
      else
        throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");
    }

    /**
     * Bind a value to the specified parameter
     *
     * @param name name of the parameter
     * @param value value to bind
     * @see bind
     */
    public new void set (string name, GLib.Value? value) throws SQLHeavy.Error {
      this.bind (this.parameter_index (name), value);
    }

    /**
     * Bind an int value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see set_int
     * @see set
     */
    public void bind_int (int field, int value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int (this.parameter_check_index (field), value), this.queryable);
    }

    /**
     * Bind an int value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_int
     * @see set
     */
    public void set_int (string field, int value) throws SQLHeavy.Error {
      this.bind_int (this.parameter_index (field), value);
    }

    /**
     * Bind an int64 value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see set_int64
     * @see bind
     */
    public void bind_int64 (int field, int64 value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int64 (this.parameter_check_index (field), value), this.queryable);
    }

    /**
     * Bind an int64 value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_int64
     * @see set
     */
    public void set_int64 (string field, int64 value) throws SQLHeavy.Error {
      this.bind_int64 (this.parameter_index (field), value);
    }

    /**
     * Bind a string value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see set_string
     * @see bind
     */
    public void bind_string (int field, string? value) throws SQLHeavy.Error {
      if ( value == null )
        this.bind_null (field);
      else
        error_if_not_ok (this.stmt.bind_text (this.parameter_check_index (field), (!) value), this.queryable);
    }

    /**
     * Bind a string value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_string
     * @see set
     */
    public void set_string (string field, string? value) throws SQLHeavy.Error {
      this.bind_string (this.parameter_index (field), value);
    }

    /**
     * Bind null to the specified parameter index
     *
     * @param field index of the parameter
     * @see set_null
     * @see bind
     */
    public void bind_null (int field) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_null (this.parameter_check_index (field)), this.queryable);
    }

    /**
     * Bind null to the specified parameter
     *
     * @param field name of the parameter
     * @see bind_null
     * @see set
     */
    public void set_null (string field) throws SQLHeavy.Error {
      this.bind_null (this.parameter_index (field));
    }

    /**
     * Bind a double value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see set_double
     * @see bind
     */
    public void bind_double (int field, double value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_double (this.parameter_check_index (field), value), this.queryable);
    }

    /**
     * Bind an double value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_double
     * @see set
     */
    public void set_double (string field, double value) throws SQLHeavy.Error {
      this.bind_double (this.parameter_index (field), value);
    }

    /**
     * Bind a byte array value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see set_blob
     * @see bind
     */
    public void bind_blob (int field, uint8[] value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_blob (field, GLib.Memory.dup (value, value.length), value.length, GLib.g_free), this.queryable);
    }

    /**
     * Bind a byte array value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_blob
     * @see set
     */
    public void set_blob (string field, uint8[] value) throws SQLHeavy.Error {
      this.bind_blob (this.parameter_index (field), value);
    }

    /**
     * Clear the bindings
     */
    public void clear () {
      this.stmt.clear_bindings ();
    }

    /**
     * Retrieve the entire result set
     *
     * @return the result set
     * @see print_table
     */
    public GLib.GenericArray<GLib.GenericArray<GLib.Value?>> get_table () throws SQLHeavy.Error {
      var values = new GLib.GenericArray<GLib.GenericArray<GLib.Value?>> ();

      for ( var results = this.execute () ; !results.finished ; results.next () ) {
        var column_l = results.field_count;

        var row = new GLib.GenericArray<GLib.Value?> ();
        row.length = column_l;

        for ( int c = 0 ; c < column_l ; c++ )
          row[c] = result.fetch (c);

        values.add (row);
      }

      return values;
    }

    /**
     * Print the result set to a file stream
     *
     * @param fd the stream to print to
     * @see Queryable.print_table
     */
    public void print_table (GLib.FileStream? fd = null) throws SQLHeavy.Error {
      var result = this.execute ();

      var field_names = result.field_names ();
      var field_lengths = new long[field_names.length];
      var data = new GLib.GenericArray<GLib.GenericArray <string>> ();

      if ( fd == null )
        fd = GLib.stderr;
      int field = 0;

      for ( field = 0 ; field < field_lengths.length ; field++ )
        field_lengths[field] = field_names[field].len ();

      while ( !result.finished ) {
        var row_data = new GLib.GenericArray<string> ();
        data.add (row_data);

        for ( field = 0 ; field < field_names.length ; field++ ) {
          var cell = result.fetch_string (field);
          var cell_l = cell.len ();
          if ( field_lengths[field] < cell_l )
            field_lengths[field] = cell_l;

          row_data.add (cell);
        }

        result.next ();
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

    construct {
      this.error_code = queryable.database.get_sqlite_db ().prepare_v2 (this.sql, this.sql_len, out this.stmt);

      if ( this.error_code == Sqlite.OK )
        this.sql = this.stmt.sql ();

      this.parameter_count = this.stmt.bind_parameter_count ();
    }

    /**
     * Create a new Query
     */
    public Query (SQLHeavy.Queryable queryable, string sql) throws SQLHeavy.Error {
      GLib.Object (queryable: queryable, sql: sql);
      error_if_not_ok (this.error_code);
    }

    public Query.full (SQLHeavy.Queryable queryable, string sql, int sql_max_len = -1, out unowned string? tail = null) throws SQLHeavy.Error {
      GLib.Object (queryable: queryable, sql: sql, sql_len: sql_max_len);
      error_if_not_ok (this.error_code);

      if ( &tail != null )
        tail = (string) ((size_t) sql + this.sql.size ());
    }
  }
}
