namespace SQLHeavy {
  /**
   * Backup manager
   */
  public class Backup : GLib.Object {
    /**
     * The database to backup
     *
     * @see source_db_name
     */
    public SQLHeavy.Database source_db { get; construct; }

    /**
     * The database to backup to
     *
     * @see destination_db_name
     */
    public SQLHeavy.Database destination_db { get; construct; }

    /**
     * Name of the database to backup
     *
     * @see source_db
     */
    public string? source_db_name { get; construct; default = null; }

    /**
     * Name of the database to backup to
     *
     * @see destination_db
     */
    public string? destination_db_name { get; construct; default = null; }

    private Sqlite.Backup backup;

    /**
     * Signal which is emitted each time {@link step} is called
     */
    public signal void stepped ();

    /**
     * Backup 1 page of data
     *
     * See [[http://sqlite.org/c3ref/backup_finish.html|sqlite3_backup_step]]
     * for more details.
     *
     * @return true if there is more data, false if backup is complete
     * @see execute
     */
    public bool step () throws SQLHeavy.Error {
      int ec = this.backup.step (1);
      switch ( ec ) {
        case Sqlite.OK:
          this.stepped ();
          return true;
        case Sqlite.DONE:
          this.stepped ();
          return false;
        default:
          error_if_not_ok (ec);
          GLib.assert_not_reached ();
      }
    }

    /**
     * Complete backup
     *
     * @see execute_async
     * @see step
     */
    public void execute () throws SQLHeavy.Error {
      while ( this.step () ) { }
    }

    /**
     * Complete backup asynchronously
     *
     * @param cancellable a GCancellable, or null
     */
    public async void execute_async (GLib.Cancellable? cancellable = null) throws SQLHeavy.Error {
      SQLHeavy.Error? err = null;

      GLib.Idle.add (() => {
          if ( cancellable != null && cancellable.is_cancelled () ) {
            err = new SQLHeavy.Error.INTERRUPTED (sqlite_errstr (Sqlite.INTERRUPT));
            execute_async.callback ();
            return false;
          }
          else {
            try {
              if ( this.step () )
                return true;
              else {
                execute_async.callback ();
                return false;
              }
            } catch ( SQLHeavy.Error e ) {
              err = e;
              return false;
            }
          }
        });

      yield;

      if ( err != null )
        throw err;
    }

    construct {
      this.backup = new Sqlite.Backup (this.destination_db.get_sqlite_db (), this.destination_db_name ?? "main",
                                       this.source_db.get_sqlite_db (), this.source_db_name ?? "main");
    }

    /**
     * Create a backup object, with named source and destination databases
     *
     * @param source source database
     * @param source_name source database name
     * @param destination destination database
     * @param destination_name destination database name
     */
    public Backup.with_db_names (SQLHeavy.Database source, string? source_name, SQLHeavy.Database destination, string? destination_name) throws SQLHeavy.Error {
      Object (source_db: source, destination_db: destination, source_db_name: source_name, destination_db_name: destination_name);

      if ( this.backup == null )
        error_if_not_ok (this.destination_db.get_sqlite_db ().errcode (), this.destination_db);
    }

    /**
     * Create a backup object
     *
     * @param source source database
     * @param destination destination database
     */
    public Backup (SQLHeavy.Database source, SQLHeavy.Database destination) throws SQLHeavy.Error {
      Object (source_db: source, destination_db: destination);

      if ( this.backup == null )
        error_if_not_ok (this.destination_db.get_sqlite_db ().errcode (), this.destination_db);
    }
  }
}
