namespace SQLHeavy {
  [CCode (cname = "sqlite3_prepare_v2")]
  internal extern int sqlite3_prepare_v2 (Sqlite.Database db, string sql, int n_bytes, out unowned Sqlite.Statement stmt, out unowned string tail = null);
  [CCode (cname = "sqlite3_finalize")]
  internal extern int sqlite3_finalize (Sqlite.Statement stmt);

  /**
   * A prepared statement
   */
  public class Query : GLib.Object, GLib.Initable {
    /**
     * The queryable asscociated with this query
     */
    public unowned SQLHeavy.Queryable queryable { get; private set; }

    /**
     * The SQL used to create this query 
     */
    public string sql {
      get { return this._sql; }
      construct { this._sql = value; }
    }
    private string _sql;

    /**
     * The maximum length of the SQL used to create this query
     */
    public int sql_length { private get; construct; default = -1; }

    /**
     * The SQLite statement associated with this query
     */
    private unowned Sqlite.Statement? stmt = null;

    /**
     * Whether {@link stmt} is currently in use by a query result
     */
    private bool stmt_in_use = false;

    /**
     * Bindings
     */
    private SQLHeavy.ValueArray? bindings = null;

    /**
     * Retrive the bindings for the query
     */
    internal SQLHeavy.ValueArray? get_bindings () {
      return this.bindings;
    }

    /**
     * Attempt to steal the {@link stmt}
     *
     * We want to be able to create multiple {@link QueryResult}
     * instances from a single {@link Query}, but compiling a
     * statement is not cheap, so we want to be able to reuse the
     * statement we created for the query.
     *
     * This function will try to steal the statement, but if it is
     * already in use by another {@link QueryResult} it will return
     * null and let the {@link QueryResult} compile a new statement.
     *
     * @return the statement or null
     */
    internal unowned Sqlite.Statement? try_to_steal_stmt () {
      if ( !this.stmt_in_use ) {
        lock ( this.stmt ) {
          if ( !this.stmt_in_use ) {
            this.stmt_in_use = true;
            return this.stmt;
          }
        }
      }

      return null;
    }

    /**
     * Return ownership of a statement which was acquired from the
     * {@link try_to_steal_stmt} method
     */
    internal void return_stmt () {
      this.stmt_in_use = false;
    }

    /**
     * When set the bindings will automatically be cleared when an
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
      int idx = 0;
      var first_char = parameter[0];

      if ( first_char == ':' || first_char == '@' ) {
        if ( (idx = this.stmt.bind_parameter_index (parameter)) != 0 )
          return idx - 1;
      } else {
        if ( (idx = this.stmt.bind_parameter_index (":" + parameter)) != 0 )
          return idx - 1;
        else if ( (idx = this.stmt.bind_parameter_index ("@" + parameter)) != 0 )
          return idx - 1;
      }

      throw new SQLHeavy.Error.RANGE ("Could not find parameter '%s'.", parameter);
    }

    /**
     * Bind a list of parameters
     *
     * These are in groups of three, with the first argument being the
     * named parameter, the second being the type (GType), and the
     * third being the value.
     *
     * @param has_first_parameter whether the first_parameter argument should be used
     * @param first_parameter the name of the first parameter
     * @param args the remaining parameters
     */
    internal void set_list (bool has_first_parameter, string? first_parameter, va_list args) throws SQLHeavy.Error {
      unowned string? current_parameter = first_parameter;
      if ( !has_first_parameter )
        current_parameter = args.arg ();

      while ( current_parameter != null ) {
        GLib.Type current_parameter_type = args.arg ();
        if ( current_parameter_type == typeof (string) )
          this.set_string (current_parameter, args.arg ());
        else if ( current_parameter_type == typeof (int) )
          this.set_int (current_parameter, args.arg ());
        else if ( current_parameter_type == typeof (int64) )
          this.set_int64 (current_parameter, args.arg ());
        else if ( (current_parameter_type == typeof (double)) ||
                  (current_parameter_type == typeof (float)) )
          this.set_double (current_parameter, args.arg ());
        else if ( current_parameter_type == typeof (void*) )
          this.set_null (current_parameter);
        else if ( current_parameter_type == typeof (GLib.ByteArray) )
          this.set_byte_array (current_parameter, args.arg ());
        else
          throw new SQLHeavy.Error.DATA_TYPE ("Data type `%s' unsupported.", current_parameter_type.name ());

        current_parameter = args.arg ();
      }
    }

    /**
     * Execute the query
     *
     * This function accepts an arbitrary number of groups of
     * arguments for binding values. The first argument in the group
     * must be the name of the parameter to bind, the second a GType,
     * and the third the value.
     *
     * @param first_parameter the name of the first parameter to bind, or null
     * @return the result
     */
    public SQLHeavy.QueryResult execute (string? first_parameter = null, ...) throws SQLHeavy.Error {
      var args = va_list ();
      this.set_list (true, first_parameter, args);

      return new SQLHeavy.QueryResult (this);
    }

    /**
     * Execute the query asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @return the result
     */
    public async SQLHeavy.QueryResult execute_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      var res = new SQLHeavy.QueryResult.no_exec (this);
      yield res.next_async (cancellable);

      return res;
    }

    /**
     * Execute the INSERT query
     *
     * @return the inserted row ID
     */
    public int64 execute_insert () throws SQLHeavy.Error {
      int64 insert_id = 0;

      new SQLHeavy.QueryResult.insert (this, out insert_id);

      return insert_id;
    }

    /**
     * Execute the INSERT query asynchronously
     *
     * @param cancellable optional cancellable for aborting the operation
     * @return the inserted row ID
     */
    public async int64 execute_insert_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      var res = new SQLHeavy.QueryResult.no_exec (this);

      int64 insert_id = 0;
      yield res.next_internal_async (cancellable, 1, out insert_id);

      return insert_id;
    }

    /**
     * Bind a value to the specified parameter index
     *
     * @param parameter name of the parameter
     * @param value value to bind
     * @see set
     */
    public void bind (int parameter, GLib.Value? value) throws SQLHeavy.Error {
      this.parameter_check_index (parameter);

      if ( !SQLHeavy.check_type (value.type ()) )
        throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");

      this.bindings[parameter] = value;
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
      this.bindings.set_int (this.parameter_check_index (field), value);
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
      this.bindings.set_int64 (this.parameter_check_index (field), value);
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
        this.bindings.set_string (this.parameter_check_index (field), value);
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
      this.bindings.set_null (this.parameter_check_index (field));
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
      this.bindings.set_double (this.parameter_check_index (field), value);
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
      var ba = new GLib.ByteArray.sized (value.length);
      ba.append (value);
      this.bind_byte_array (this.parameter_check_index (field), ba);
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
     * Bind a byte array value to the specified parameter index
     *
     * @param field index of the parameter
     * @param value value to bind
     * @see set_blob
     * @see bind
     */
    public void bind_byte_array (int field, GLib.ByteArray value) throws SQLHeavy.Error {
      this.bindings.set_byte_array (this.parameter_check_index (field), value);
    }

    /**
     * Bind a byte array value to the specified parameter
     *
     * @param field name of the parameter
     * @param value value to bind
     * @see bind_blob
     * @see set
     */
    public void set_byte_array (string field, GLib.ByteArray value) throws SQLHeavy.Error {
      this.bind_byte_array (this.parameter_index (field), value);
    }

    /**
     * Clear the bindings
     */
    public void clear () {
      this.bindings.clear ();
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
          row[c] = results.fetch (c);

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
        field_lengths[field] = field_names[field].length;

      while ( !result.finished ) {
        var row_data = new GLib.GenericArray<string> ();
        data.add (row_data);

        for ( field = 0 ; field < field_names.length ; field++ ) {
          var cell = result.fetch_string (field);
          var cell_l = cell.length;
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

    public virtual bool init (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      unowned Sqlite.Database db = this.queryable.database.get_sqlite_db ();
      error_if_not_ok (sqlite3_prepare_v2 (db, this.sql, this.sql_length, out this.stmt));

      this._sql = this.stmt.sql ();
      this.parameter_count = this.stmt.bind_parameter_count ();
      this.bindings = new SQLHeavy.ValueArray (this.parameter_count);

      return true;
    }

    /**
     * Create a new Query
     *
     * @param queryable the queryable to create the query
     * @param sql the SQL to use to create the query
     */
    public Query (SQLHeavy.Queryable queryable, string sql) throws SQLHeavy.Error {
      GLib.Object (sql: sql);
      this.queryable = queryable;
      this.init ();
    }

    /**
     * Create a new Query
     *
     * @param queryable the queryable to create the query
     * @param sql the SQL to use to create the query
     * @param sql_max_len the maximum length of the SQL
     * @param tail unused portion of the SQL
     */
    public Query.full (SQLHeavy.Queryable queryable, string sql, int sql_max_len = -1, out unowned string? tail = null) throws SQLHeavy.Error {
      GLib.Object (sql: sql, sql_length: sql_max_len);
      this.queryable = queryable;
      this.init ();

      if ( &tail != null ) {
        if ( this._sql != null )
          tail = (string) ((size_t) sql + this._sql.length);
        else {
          tail = (string) ((size_t) sql + sql.length);
          throw new SQLHeavy.Error.NO_SQL ("No SQL was provided");
        }
      }
    }
  }
}
