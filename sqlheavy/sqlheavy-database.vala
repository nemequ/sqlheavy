namespace SQLHeavy {
  [CCode (cname = "sqlite3_open_v2", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_open (string filename, out unowned Sqlite.Database db, int flags = Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE, string? zVfs = null);
  [CCode (cname = "sqlite3_close", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_close (Sqlite.Database db);

  /**
   * A database.
   */
  public class Database : GLib.Object {
    internal unowned Sqlite.Database db;
    //internal GLib.Mutex insert_lock = new GLib.Mutex ();

    private void thread_cb (void * stmt) {
      (stmt as SQLHeavy.Statement).step_threaded ();
    }
    public GLib.ThreadPool thread_pool;

    /**
     * Create a prepared statement.
     *
     * @param sql, An SQL query.
     */
    public SQLHeavy.Statement prepare (string sql) throws SQLHeavy.Error {
      return new SQLHeavy.Statement (this, sql);
    }

    /**
     * Execute a query.
     *
     * @param sql, An SQL query.
     */
    public void execute (string sql) throws Error {
      SQLHeavy.Statement stmt;
      unowned string? s = sql;

      while ( s != null ) {
        stmt = new SQLHeavy.Statement (this, (!) s, out s);
        stmt.execute ();
      }
    }

    

    /**
     * Open a database.
     *
     * @param filename, Where to store the database, or null for memory only.
     * @param mode, Bitmask of mode to use when opening the database.
     */
    public Database (string? filename = null,
                     SQLHeavy.FileMode mode =
                       SQLHeavy.FileMode.READ |
                       SQLHeavy.FileMode.WRITE |
                       SQLHeavy.FileMode.CREATE) throws SQLHeavy.Error {
      //error_if_not_ok (Sqlite.Config.config (Sqlite.Config.SERIALIZED));

      if ( filename == null )
        filename = ":memory:";

      int flags = 0;
      if ( (mode & SQLHeavy.FileMode.READ) == SQLHeavy.FileMode.READ )
        flags = Sqlite.OPEN_READONLY;
      if ( (mode & SQLHeavy.FileMode.WRITE) == SQLHeavy.FileMode.WRITE )
        flags = Sqlite.OPEN_READWRITE;
      if ( (mode & SQLHeavy.FileMode.CREATE) == SQLHeavy.FileMode.CREATE )
        flags |= Sqlite.OPEN_CREATE;

      error_if_not_ok (sqlite3_open ((!) filename, out this.db, flags, null));

      try {
        this.thread_pool = new GLib.ThreadPool (thread_cb, 4, false);
      }
      catch ( GLib.ThreadError e ) {
        throw new SQLHeavy.Error.THREAD ("%s (%d)", e.message, e.code);
      }
    }

    ~ Database () {
      sqlite3_close (this.db);
    }
  }
}
