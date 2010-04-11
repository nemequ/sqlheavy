namespace SQLHeavy {
  /**
   * Interface on which queries may be run
   */
  public interface Queryable : GLib.Object {
    /**
     * Database
     */
    public abstract SQLHeavy.Database database { get; }

    /**
     * Signal which is emitted when a query finished executing.
     *
     * @see Database.sql_executed
     */
    public signal void query_executed (SQLHeavy.Statement stmt);

    /**
     * Lock the queryable and refuse to run any queries against it.
     *
     * @see unlock
     */
    public abstract void @lock ();

    /**
     * Unlock the queryable and allow queries to be run against it.
     *
     * @see lock
     */
    public abstract void @unlock ();

    /**
     * Begin a transaction. Will lock the queryable until the transaction is resolved.
     *
     * @return a new transaction
     */
    public Transaction begin_transaction () {
      return new Transaction (this);
    }

    /**
     * Execute the supplied SQL, iterating through multiple statements if necessary.
     *
     * @param sql An SQL query.
     */
    public void execute (string sql, ssize_t max_len = -1) throws Error {
      unowned string? s = sql;

      // Could probably use a bit of work.
      for ( size_t current_max = (max_len < 0) ? s.size () : max_len ;
            (s != null) && (current_max > 0) ; ) {
        unowned char * os = (char *)s;
        {
          SQLHeavy.Statement stmt = new SQLHeavy.Statement.full (this, (!) s, (int)current_max, out s);
          stmt.execute ();
        }

        current_max -= (char *)s - os;
        // Skip white space.
        for ( unowned char * sp = (char *)s ; current_max > 0 ; current_max--, sp++, s = (string)sp )
          if ( !(*sp).isspace () )
            break;
      }
    }

    /**
     * Create a prepared statement.
     *
     * @param sql An SQL query.
     * @return a new statement
     */
    public SQLHeavy.Statement prepare (string sql) throws SQLHeavy.Error {
      return new SQLHeavy.Statement (this, sql);
    }

    /**
     * Runs an SQL script located in a file
     *
     * @param filename the location of the script
     */
    public void run_script (string filename) throws Error {
      try {
        var file = new GLib.MappedFile (filename, false);
        this.execute ((string)file.get_contents(), (ssize_t)file.get_length());
      }
      catch ( GLib.FileError e ) {
        throw new SQLHeavy.Error.IO ("Unable to open script: %s (%d).", e.message, e.code);
      }
    }
  }
}
