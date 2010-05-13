namespace SQLHeavy {
  private int direct_compare (void * a, void * b) {
    return (int) (a - b);
  }

  /**
   * Automatically growing pool of {@link Database} objects
   *
   * This class creates a pool of one or more {@link Database} objects
   * to be used for simultaneous access from multiple threads and/or
   * multiple asynchronous queries.
   *
   * The database must be located on disk.
   */
  public class DatabasePool : GLib.Object, SQLHeavy.Queryable {
    private GLib.Sequence<SQLHeavy.Database> available_pool =
      new GLib.Sequence<SQLHeavy.Database> (GLib.g_object_unref);
    private GLib.Sequence<SQLHeavy.Database> active_pool =
      new GLib.Sequence<SQLHeavy.Database> (GLib.g_object_unref);

    /**
     * The maximum number of database connections to keep open
     *
     * Keep in mind that the database pool may open more connections
     * than this, it will just not keep them around when they are
     * idle.
     *
     * @see max_pool_size
     */
    public int soft_max_pool_size { get; construct set; }

    /**
     * The maximum number of database connections to open
     *
     * If this number is reached, future calls to
     * {@link begin_transaction} will block until a database becomes
     * available.
     *
     * Not yet implemented.
     *
     * @see soft_max_pool_size
     */
    public int max_pool_size { get; construct; }

    public int pool_size {
      get {
        lock ( this.available_pool ) {
          lock ( this.active_pool ) {
            return this.available_pool.get_length () + this.active_pool.get_length ();
          }
        }
      }
    }

    public SQLHeavy.Transaction begin_transaction () throws SQLHeavy.Error {
      SQLHeavy.Database? db = null;

      lock ( this.available_pool ) {
        if ( this.available_pool.get_length () > 0 ) {
          var iter = this.available_pool.get_begin_iter ();
          db = iter.get ();
          this.available_pool.remove (iter);
        } else {
          db = new SQLHeavy.Database (this.filename);
        }
      }

      lock ( this.active_pool ) {
        this.active_pool.insert_sorted (db, direct_compare);
      }

      return db.begin_transaction ();
    }

    /**
     * The location of the database
     *
     * Must be on-disk (not ":memory:")
     */
    public string filename { get; construct; }

    public void @lock () { }
    public void unlock () { }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Database database {
      owned get {
        SQLHeavy.Database? res = null;

        lock ( this.available_pool ) {
          if ( this.available_pool.get_length () > 0 ) {
            var iter = this.available_pool.get_begin_iter ();
            res = iter.get ();
            this.available_pool.remove (iter);
          } else {
            try {
              res = new SQLHeavy.Database (this.filename);
            } catch ( SQLHeavy.Error e ) {
              GLib.error ("Unable to open database: %s", e.message);
            }
          }
        }

        GLib.assert (res != null);
        return (!) res;
      }
    }

    /**
     * {@inheritDoc}
     */
    public void execute (string sql, ssize_t max_len = -1) throws Error {
      this.database.execute (sql, max_len);
    }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Statement prepare (string sql) throws SQLHeavy.Error {
      return this.database.prepare (sql);
    }

    public DatabasePool (string filename) {
      Object (filename: filename);
    }
  }
}
