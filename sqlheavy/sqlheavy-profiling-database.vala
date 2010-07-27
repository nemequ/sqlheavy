namespace SQLHeavy {
  public class ProfilingDatabase : SQLHeavy.VersionedDatabase {
    private SQLHeavy.Query query;

    internal void insert (SQLHeavy.QueryResult query_result) {
      lock ( this.query ) {
        try {
          this.query.set_string (":sql", query_result.query.sql);
          this.query.set_double (":clock", query_result.execution_time);
          this.query.set_int64 (":fullscan_step", query_result.full_scan_steps);
          this.query.set_int64 (":sort", query_result.sort_operations);
          this.query.execute ();
        } catch ( SQLHeavy.Error e ) {
          GLib.warning ("Unable to insert entry into profiling database: %s", e.message);
        }
      }
    }

    construct {
      try {
        this.query = new SQLHeavy.Query (this, "INSERT INTO `queries` (`sql`, `clock`, `fullscan_step`, `sort`) VALUES (:sql, :clock, :fullscan_step, :sort);");
        this.query.auto_clear = true;
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
