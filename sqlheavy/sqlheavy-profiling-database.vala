namespace SQLHeavy {
  /**
   * Database used to hold profiling information.
   *
   * Note that this database will have {@link Database.synchronous}
   * property set to OFF. This provides a drastic performance increase
   * but means that sudden power loss could lead to a corrupt
   * profiling database.
   *
   * This database will also have {@link Database.journal_mode} set to
   * OFF. This will approximately halve the amount of time time spent
   * inserting profiling data, but the database will likely become
   * corrupt if the application crashes.
   *
   * @see Database.profiling_data
   */
  public class ProfilingDatabase : SQLHeavy.VersionedDatabase {
    private SQLHeavy.Query? query;

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
      this.synchronous = SQLHeavy.SynchronousMode.OFF;
      this.journal_mode = SQLHeavy.JournalMode.OFF;

      try {
        this.query = new SQLHeavy.Query (this, "INSERT INTO `queries` (`sql`, `clock`, `fullscan_step`, `sort`) VALUES (:sql, :clock, :fullscan_step, :sort);");
        this.query.auto_clear = true;
      }
      catch ( SQLHeavy.Error e ) {
        GLib.warning ("Unable to insert profiling information: %s (%d)", e.message, e.code);
      }
    }

    /**
     * Create a new ProfilingDatabase
     *
     * @param filename the location of the database
     */
    public ProfilingDatabase (string? filename = null) throws SQLHeavy.Error {
      var schema = GLib.Path.build_filename (SQLHeavy.Config.PATH_PACKAGE_DATA,
                                             SQLHeavy.Version.API,
                                             "schemas",
                                             "profiling");

      GLib.Object (filename: filename, schema: schema);
      this.init ();
    }
  }
}
