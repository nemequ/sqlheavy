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

    public bool auto_clear { get; set; default = false; }

    /**
     * Emitted when the step method receives a row.
     */
    public signal void received_row ();

    /**
     * The database this statement operates on.
     */
    public weak SQLHeavy.Database db { get; construct set; }
    private unowned Sqlite.Statement stmt;

    private SourceFunc? step_async_cb = null;

    public string sql { get { return this.stmt.sql(); } }
    public int parameter_count { get { return this.stmt.bind_parameter_count (); } }
    public int column_count { get { return this.stmt.column_count (); } }
    public int data_count { get { return this.stmt.data_count (); } }
    public bool finished { get; private set; default = false; }

    /**
     * Step (asynchronous variant)
     */
    public async bool step_async () throws Error {
      // TODO this should probably lock something...
      GLib.debug ("Starting (%s)...", this.sql);
      this.step_async_cb = step_async.callback;
      try {
        this.db.thread_pool.push (this);
      }
      catch ( GLib.ThreadError e ) {
        throw new SQLHeavy.Error.THREAD ("%s (%d)", e.message, e.code);
      }
      yield;

      GLib.debug ("Finishing (%s)...", this.sql);
      this.step_async_cb = null;
      return this.step_handle ();
    }

    internal void step_threaded ()
      requires (this.step_async_cb != null)
    {
      this.error_code = this.stmt.step ();
      GLib.Idle.add (() => { (!) this.step_async_cb (); return false; });
    }

    public void reset () {
      if ( this.auto_clear )
        this.stmt.clear_bindings ();
      this.stmt.reset ();
      this.finished = false;
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
        return false;
      }
      else
        error_if_not_ok (ec);

      GLib.assert_not_reached ();
    }

    public bool step () throws Error {
      if ( this.finished )
        return false;
      this.error_code = this.stmt.step ();
      return this.step_handle ();
    }

    public void execute () throws SQLHeavy.Error {
      while ( this.step () ) { }
    }

    public int64 execute_insert () throws SQLHeavy.Error {
      /* Might want to call the sqlite functions directly here, to
       * limit the race condition. */
      this.execute ();
      return this.db.last_insert_id;
    }

    private int fetch_check_index (int col) throws SQLHeavy.Error {
      if (col < 0 || col > this.column_count)
        throw new SQLHeavy.Error.RANGE (SQLHeavy.ErrorMessage.RANGE);
      return col;
    }

    public GLib.Type get_column_type (int col) throws SQLHeavy.Error {
      switch ( this.stmt.column_type (col) ) {
        case Sqlite.INTEGER:
          return typeof (int64);
        case Sqlite.TEXT:
          return typeof (string);
        case Sqlite.FLOAT:
          return typeof (double);
        case Sqlite.NULL:
          return typeof (void);
        case Sqlite.BLOB:
          return typeof (GLib.Array);
        default:
          throw new SQLHeavy.Error.DATA_TYPE ("Data type unsupported.");
      }
    }

    /**
     * Return a field from result.
     *
     * @param col, the offset of the column to return.
     */
    public GLib.Value? fetch (int col) throws SQLHeavy.Error {
      GLib.Value? res = null;

      this.fetch_check_index (col);

      var col_type = this.get_column_type (col);
      if ( col_type == typeof (int64) ) {
        var i64v = this.fetch_int64 (col);
        if ( i64v > int.MAX ) {
          res = GLib.Value (typeof (int64));
          res.set_int64 (i64v);
        }
        else {
          res = GLib.Value (typeof (int));
          res.set_int ((int)i64v);
        }
      }
      else if ( col_type == typeof (string) ) {
        res = GLib.Value (typeof (string));
        res.take_string (this.fetch_string (col));
      }
      else if ( col_type == typeof (void) ) {
        res = GLib.Value (typeof (void));
      }
      else if ( col_type == typeof (GLib.Array) ) {
        res = GLib.Value (typeof (GLib.Array));
        var blob_size = this.stmt.column_bytes(col);
        //var arr = new GLib.Array.sized<uint8> (false, false, sizeof (uint8), blob_size);
        var arr = new GLib.Array <uint8> (false, false, 1);
        arr.append_vals (this.stmt.column_blob (col), blob_size);
        res.set_boxed (arr);
      }
      else if ( col_type == typeof (double) ) {
        res = GLib.Value (typeof (double));
        res.set_double (this.fetch_double (col));
      }
      else
        GLib.assert_not_reached ();

      return res;
    }

    public string? fetch_string (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_text (this.fetch_check_index (col));
    }

    public int fetch_int (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_int (this.fetch_check_index (col));
    }

    public int64 fetch_int64 (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_int64 (this.fetch_check_index (col));
    }

    public double fetch_double (int col = 0) throws SQLHeavy.Error {
      return this.stmt.column_double (this.fetch_check_index (col));
    }

    public uint8[] fetch_blob (int col = 0) throws SQLHeavy.Error {
      var res = new uint8[this.stmt.column_bytes(this.fetch_check_index (col))];
      GLib.Memory.copy (res, this.stmt.column_blob (col), res.length);
      return res;
    }

    public GLib.Value fetch_result (int col = 0) throws SQLHeavy.Error {
      this.step ();
      return this.fetch (col);
    }

    public string? fetch_result_string (int col = 0) throws SQLHeavy.Error {
      this.step ();
      return this.fetch_string (col);
    }

    public int fetch_result_int (int col = 0) throws SQLHeavy.Error {
      this.step ();
      return this.fetch_int (col);
    }

    public int64 fetch_result_int64 (int col = 0) throws SQLHeavy.Error {
      this.step ();
      return this.fetch_int64 (col);
    }

    public double fetch_result_double (int col = 0) throws SQLHeavy.Error {
      this.step ();
      return this.fetch_double (col);
    }

    public uint8[] fetch_result_blob (int col = 0) throws SQLHeavy.Error {
      this.step ();
      return this.fetch_blob (col);
    }

    private int bind_check_index (int col) throws SQLHeavy.Error {
      if (col < 0 || col > this.parameter_count)
        throw new SQLHeavy.Error.RANGE (SQLHeavy.ErrorMessage.RANGE);
      return col;
    }

    public int bind_get_index (string col) throws SQLHeavy.Error {
      var idx = this.stmt.bind_parameter_index (col);
      if ( idx == 0 )
        throw new SQLHeavy.Error.RANGE ("Could not find parameter '%s'.", col);
      return idx;
    }

    public unowned string bind_get_name (int col) throws SQLHeavy.Error {
      return this.stmt.bind_parameter_name (this.bind_check_index (col));
    }

    public void bind_int (int col, int value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int (this.bind_check_index (col), value));
    }

    public void bind_named_int (string col, int value) throws SQLHeavy.Error {
      this.bind_int (this.bind_get_index (col), value);
    }

    public void bind_int64 (int col, int64 value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_int64 (this.bind_check_index (col), value));
    }

    public void bind_named_int64 (string col, int64 value) throws SQLHeavy.Error {
      this.bind_int64 (this.bind_get_index (col), value);
    }

    public void bind_string (int col, string? value) throws SQLHeavy.Error {
      if ( value == null )
        this.bind_null (col);
      else
        error_if_not_ok (this.stmt.bind_text (this.bind_check_index (col), value));
    }

    public void bind_named_string (string col, string? value) throws SQLHeavy.Error {
      this.bind_string (this.bind_get_index (col), value);
    }

    public void bind_null (int col) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_null (this.bind_check_index (col)));
    }

    public void bind_named_null (string col) throws SQLHeavy.Error {
      this.bind_null (this.bind_get_index (col));
    }

    public void bind_double (int col, double value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_double (this.bind_check_index (col), value));
    }

    public void bind_named_double (string col, double value) throws SQLHeavy.Error {
      this.bind_double (this.bind_get_index (col), value);
    }

    public void bind_blob (int col, uint8[] value) throws SQLHeavy.Error {
      error_if_not_ok (this.stmt.bind_blob (col, GLib.Memory.dup (value, value.length), value.length, GLib.g_free));
    }

    public void bind_named_blob (string col, uint8[] value) throws SQLHeavy.Error {
      this.bind_blob (this.bind_get_index (col), value);
    }

    ~ Statement () {
      sqlite3_finalize (this.stmt);
    }

    public GLib.ValueArray get_column (int col) throws SQLHeavy.Error {
      var valid = this.step ();
      var data = new GLib.ValueArray (this.data_count);

      while ( valid ) {
        data.append (this.fetch (col));
        valid = this.step ();
      }

      return data;
    }

    public Statement.full (SQLHeavy.Database db, string sql, int max_len = -1, out unowned string? tail = null) throws Error {
      this.db = db;
      error_if_not_ok (sqlite3_prepare (db.db, sql, max_len, out this.stmt, out tail));
    }

    /**
     * Create a prepared statement.
     *
     * @param db, The database to use.
     * @param sql, An SQL query.
     * @param tail, Where to store the any unprocessed part of the query.
     * @see SQLHeavy.Database.prepare
     */
    public Statement (SQLHeavy.Database db, string sql) throws SQLHeavy.Error {
      this.db = db;
      error_if_not_ok (sqlite3_prepare (db.db, sql, -1, out this.stmt, null));
    }
  }
}
