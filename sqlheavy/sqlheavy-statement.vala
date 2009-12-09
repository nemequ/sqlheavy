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

    private bool step_handle () throws Error {
      int ec = this.error_code;
      this.error_code = Sqlite.OK;

      if ( ec == Sqlite.ROW ) {
        this.received_row ();
        return true;
      }
      else if ( ec == Sqlite.DONE )
        return false;
      else
        error_if_not_ok (ec);

      GLib.assert_not_reached ();
    }

    public bool step () throws Error {
      this.error_code = this.stmt.step ();
      return this.step_handle ();
    }

    public void execute () throws SQLHeavy.Error {
      while ( this.step () ) { }
    }

    /**
     * Return a field from result.
     *
     * @param col, the offset of the column to return.
     */
    public T fetch <T> (int col) throws Error {
      if ( typeof(T) == typeof(string) )
        return this.stmt.column_text (col);
      // else if ( typeof(T) == typeof(int) )
      //   return this.stmt.column_int (col);
      // else if ( typeof(T) == typeof(int64) )
      //   return this.stmt.column_int64 (col);

      throw new SQLHeavy.Error.DATA_TYPE("SQLHeavy.Statement.fetch() not implemented for data type (%s)", typeof(T).name());
    }

    private void bind_int (int col, int value) throws SQLHeavy.Error {
      if (col < 0 || col > this.parameter_count)
        throw new SQLHeavy.Error.RANGE (SQLHeavy.ErrorMessage.RANGE);
      error_if_not_ok (this.stmt.bind_int (col, value));
    }

    ~ Statement () {
      sqlite3_finalize (this.stmt);
    }

    /**
     * Create a prepared statement.
     *
     * @param db, The database to use.
     * @param sql, An SQL query.
     * @param tail, Where to store the any unprocessed part of the query.
     * @see SQLHeavy.Database.prepare
     */
    public Statement (SQLHeavy.Database db, string sql, out unowned string? tail = null) throws SQLHeavy.Error {
      this.db = db;
      error_if_not_ok (sqlite3_prepare (db.db, sql, (int) sql.size (), out this.stmt, out tail));
    }
  }
}
