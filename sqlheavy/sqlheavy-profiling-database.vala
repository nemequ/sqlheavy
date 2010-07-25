namespace SQLHeavy {
  public class ProfilingDatabase : SQLHeavy.VersionedDatabase {
    private SQLHeavy.Statement stmt;

    public void insert (SQLHeavy.Statement stmt) throws SQLHeavy.Error {
      lock ( this.stmt ) {
        this.stmt.bind_string (":sql", stmt.sql);
        this.stmt.bind_double (":clock", stmt.execution_time_elapsed ());
        this.stmt.bind_int64 (":fullscan_step", stmt.full_scan_steps);
        this.stmt.bind_int64 (":sort", stmt.sort_operations);
        this.stmt.execute ();
        this.stmt.reset ();
      }
    }

    construct {
      try {
        this.stmt = this.prepare ("INSERT INTO `queries` (`sql`, `clock`, `fullscan_step`, `sort`) VALUES (:sql, :clock, :fullscan_step, :sort);");
        this.stmt.auto_clear = true;
      }
      catch ( SQLHeavy.Error e ) {
        GLib.warning ("Unable to insert profiling information: %s (%d)", e.message, e.code);
      }
    }

    public ProfilingDatabase (string? filename = null) {
      var schema = GLib.Path.build_filename (SQLHeavy.Config.PATH_PACKAGE_DATA,
                                             SQLHeavy.Version.API,
                                             "schemas",
                                             "profiling");

      GLib.Object (filename: filename, schema: schema);
    }
  }
}
