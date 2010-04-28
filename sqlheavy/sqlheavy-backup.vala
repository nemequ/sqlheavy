namespace SQLHeavy {
  /**
   * Backup manager
   */
  public class Backup : GLib.Object {
    public SQLHeavy.Database source_db { get; construct; }
    public SQLHeavy.Database destination_db { get; construct; }
    public string? source_db_name { get; construct; default = null; }
    public string? destination_db_name { get; construct; default = null; }

    private Sqlite.Backup backup;

    public signal void stepped ();

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

    public void execute () throws SQLHeavy.Error {
      while ( this.step () ) { }
    }

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

    public Backup.with_db_names (SQLHeavy.Database source, string? source_name, SQLHeavy.Database destination, string? destination_name) throws SQLHeavy.Error {
      Object (source_db: source, destination_db: destination, source_db_name: source_name, destination_db_name: destination_name);

      if ( this.backup == null )
        error_if_not_ok (this.destination_db.get_sqlite_db ().errcode (), this.destination_db);
    }

    public Backup (SQLHeavy.Database source, SQLHeavy.Database destination) throws SQLHeavy.Error {
      Object (source_db: source, destination_db: destination);

      if ( this.backup == null )
        error_if_not_ok (this.destination_db.get_sqlite_db ().errcode (), this.destination_db);
    }
  }
}
