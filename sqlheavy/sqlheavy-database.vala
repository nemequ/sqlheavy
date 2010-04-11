namespace SQLHeavy {
  [CCode (cname = "sqlite3_open_v2", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_open (string filename, out unowned Sqlite.Database db, int flags = Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE, string? zVfs = null);
  [CCode (cname = "sqlite3_close", cheader_filename = "sqlite3.h")]
  private extern static int sqlite3_close (Sqlite.Database db);

  /**
   * A database.
   */
  public class Database : GLib.Object, Queryable {
    private GLib.HashTable <string, UserFunction.UserFuncData> user_functions =
      new GLib.HashTable <string, UserFunction.UserFuncData>.full (GLib.str_hash, GLib.str_equal, GLib.g_free, GLib.g_object_unref);
    internal unowned Sqlite.Database db;

    public SQLHeavy.Database database { get { return this; } }

    private Sqlite.Mutex? _transaction_lock = new Sqlite.Mutex (Sqlite.MUTEX_FAST);

    public void @lock () {
      this._transaction_lock.enter ();
    }

    public void @unlock () {
      this._transaction_lock.leave ();
    }

    /**
     * SQL executed
     *
     * Will be emitted whenever a query is executed. This is useful
     * for debugging, but {@link Queryable.query_executed} provides a
     * more powerful interface.
     *
     * @see Queryable.query_executed
     */
    public signal void sql_executed (string sql);

    private SQLHeavy.Statement? profiling_insert_stmt = null;
    private void profiling_cb (SQLHeavy.Statement stmt) {
      try {
        if ( this.profiling_insert_stmt == null )
          this.profiling_insert_stmt = this.profiling_data.prepare ("INSERT INTO `queries` (`sql`, `clock`, `fullscan_step`, `sort`) VALUES (:sql, :clock, :fullscan_step, :sort);");

        unowned SQLHeavy.Statement pstmt = this.profiling_insert_stmt;
        pstmt.auto_clear = true;
        pstmt.bind_named_string (":sql", stmt.sql);
        pstmt.bind_named_double (":clock", stmt.execution_timer.elapsed ());
        pstmt.bind_named_int64 (":fullscan_step", stmt.full_scan_steps);
        pstmt.bind_named_int64 (":sort", stmt.sort_operations);
        pstmt.execute ();
        pstmt.reset ();
      }
      catch ( SQLHeavy.Error e ) {
        GLib.warning ("Unable to insert profiling information: %s (%d)", e.message, e.code);
      }
    }

    /**
     * Database to store profiling data in.
     *
     * Enabling profiling while this is null will cause the database
     * to be created in :memory:
     */
    public SQLHeavy.Database? profiling_data = null;

    /**
     * Whether profiling is enabled.
     *
     * Profiling in SQLHeavy bypasses the SQLite profiling mechanism,
     * and instead makes use of a timer in each Statement. This is
     * done so we can gather more information about the query than is
     * available from and SQLite profiling callback.
     *
     * @see Statement.execution_timer
     */
    public bool enable_profiling {
      get { return this.profiling_data != null; }
      set {
        this.profiling_insert_stmt = null;

        if ( value == false ) {
          this.profiling_data = null;
          this.query_executed.disconnect (this.profiling_cb);
        }
        else {
          try {
            if ( this.profiling_data == null )
              this.profiling_data = new SQLHeavy.Database ();

            this.profiling_data.execute ("""
CREATE TABLE IF NOT EXISTS `queries` (
  `sql` TEXT UNIQUE NOT NULL,
  `executions` INTEGER UNSIGNED DEFAULT 1,
  `clock` FLOAT UNSIGNED NOT NULL,
  `fullscan_step` INTEGER UNSIGNED,
  `sort` INTEGER UNSIGNED
);

CREATE TRIGGER IF NOT EXISTS `queries_insert`
  BEFORE INSERT ON `queries`
  WHEN (SELECT COUNT(*) FROM `queries` WHERE `sql` = NEW.`sql`) > 0
  BEGIN
    UPDATE `queries`
      SET
        `executions` = `executions` + 1,
        `clock` = `clock` + NEW.`clock`,
        `fullscan_step` = `fullscan_step` + NEW.`fullscan_step`,
        `sort` = `sort` + NEW.`sort`
      WHERE `sql` = NEW.`sql`;
    SELECT RAISE(IGNORE);
  END;""");
          }
          catch ( SQLHeavy.Error e ) {
            GLib.warning ("Unable to enable profiling: %s (%d)", e.message, e.code);
            return;
          }

          this.query_executed.connect (this.profiling_cb);
        }
      }
    }

    /**
     * The location of the database
     */
    public string filename { get; construct; default = ":memory:"; }

    /**
     * The mode used when opening the database.
     */
    public SQLHeavy.FileMode mode {
      get;
      construct;
      default = SQLHeavy.FileMode.READ | SQLHeavy.FileMode.WRITE | SQLHeavy.FileMode.CREATE;
    }

    /**
     * The last inserted row ID
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/last_insert_rowid.html]]
     */
    public int64 last_insert_id { get { return this.db.last_insert_rowid (); } }

    private string? pragma_get_string (string pragma) {
      try {
        var stmt = new SQLHeavy.Statement (this, "PRAGMA %s;".printf (pragma));
        stmt.step ();
        return stmt.fetch_string (0);
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to retrieve pragma value: %s", e.message);
        return null;
      }
    }

    private int pragma_get_int (string pragma) {
      return this.pragma_get_string (pragma).to_int ();
    }

    private bool pragma_get_bool (string pragma) {
      return this.pragma_get_int (pragma) != 0;
    }

    private void pragma_set_string (string pragma, string value) {
      try {
        var stmt = new SQLHeavy.Statement (this, "PRAGMA %s = %s;".printf (pragma, value));
        stmt.execute ();
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to retrieve pragma value: %s", e.message);
      }
    }

    private void pragma_set_int (string pragma, int value) {
      this.pragma_set_string (pragma, "%d".printf(value));
    }

    private void pragma_set_bool (string pragma, bool value) {
      this.pragma_set_int (pragma, value ? 1 : 0);
    }

    /**
     * Auto-Vacuum mode
     *
     * Auto-vacuum status in the database.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_auto_vacuum]]
     */
    public SQLHeavy.AutoVacuum auto_vacuum {
      get { return (SQLHeavy.AutoVacuum) this.pragma_get_int("auto_vacuum"); }
      set { this.pragma_set_int ("auto_vacuum", value); }
    }

    /**
     * Cache size
     *
     * Suggested maximum number of database disk pages that SQLite
     * will hold in memory at once per open database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_cache_size]]
     */
    public int cache_size {
      get { return this.pragma_get_int ("cache_size"); }
      set { this.pragma_set_int ("cache_size", value); }
    }

    /**
     * Case-sensitive like
     *
     * Whether the LIKE operator is to take case into account for
     * ASCII characters.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_case_sensitive_like]]
     */
    public bool case_sensitive_like {
      get { return this.pragma_get_bool ("case_sensitive_like"); }
      set { this.pragma_set_bool ("case_sensitive_like", value); }
    }

    /**
     * Count changes
     *
     * Whether INSERT, UPDATE, and DELETE queries should return the
     * number of rows changed.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_count_changes]]
     */
    public bool count_changes {
      get { return this.pragma_get_bool ("count_changes"); }
      set { this.pragma_set_bool ("count_changes", value); }
    }

    /**
     * Default cache size
     *
     * Suggested maximum number of pages of disk cache that will be
     * allocated per open database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_default_cache_size]]
     */
    public int default_cache_size {
      get { return this.pragma_get_int ("default_cache_size"); }
      set { this.pragma_set_int ("default_cache_size", value); }
    }

    /**
     * Empty result callbacks
     *
     * This pragma does not affect SQLHeavy
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_empty_result_callbacks]]
     */
    public bool empty_result_callbacks {
      get { return this.pragma_get_bool ("empty_result_callbacks"); }
      set { this.pragma_set_bool ("empty_result_callbacks", value); }
    }

    /**
     * Encoding
     *
     * Encoding of the database
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_encoding]]
     */
    public SQLHeavy.Encoding encoding {
      get { return SQLHeavy.Encoding.from_string (this.pragma_get_string ("encoding")); }
      set { this.pragma_set_string ("encoding", value.to_string ()); }
    }

    /**
     * Foreign keys
     *
     * Enforcement of [[http://sqlite.org/foreignkeys.html|foreign key constraints]]
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_foreign_keys]]
     */
    public bool foreign_keys {
      get { return this.pragma_get_bool ("foreign_keys"); }
      set { this.pragma_set_bool ("foreign_keys", value); }
    }

    /**
     * Full column names
     *
     * Determine the way SQLite assigns names to result columns of
     * SELECT statements. 
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_full_column_names]]
     */
    public bool full_column_names {
      get { return this.pragma_get_bool ("full_column_names"); }
      set { this.pragma_set_bool ("full_column_names", value); }
    }

    /**
     * Full fsync
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_fullfsync]]
     */
    public bool full_fsync {
      get { return this.pragma_get_bool ("fullfsync"); }
      set { this.pragma_set_bool ("fullfsync", value); }
    }

    /**
     * Incremental vacuum
     *
     * Causes up to N pages to be removed from the freelist.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_incremental_vacuum]]
     *
     * @param pages, the number of pages to remove
     */
    public void incremental_vacuum (int pages) {
      try {
        this.execute ("PRAGMA incremental_vacuum(%d);".printf(pages));
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to run incremental vacuum: %s", e.message);
      }
    }

    /**
     * Journal mode
     *
     * Set the journal mode
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_journal_mode]]
     */
    public SQLHeavy.JournalMode journal_mode {
      get { return SQLHeavy.JournalMode.from_string (this.pragma_get_string ("journal_mode")); }
      set { this.pragma_set_string ("journal_mode", value.to_string ()); }
    }

    /**
     * Journal size limit
     *
     * Limit the size of journal files left in the file-system after
     * transactions are committed on a per database basis.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_journal_size_limit]]
     */
    public int journal_size_limit {
      get { return this.pragma_get_int ("journal_size_limit"); }
      set { this.pragma_set_int ("journal_size_limit", value); }
    }

    /**
     * Legacy file format
     *
     * When this flag is on, new SQLite databases are created in a
     * file format that is readable and writable by all versions of
     * SQLite going back to 3.0.0.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_legacy_file_format]]
     */
    public bool legacy_file_format {
      get { return this.pragma_get_bool ("legacy_file_format"); }
      set { this.pragma_set_bool ("legacy_file_format", value); }
    }

    /**
     * Locking mode
     *
     * Database connection locking-mode
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_locking_mode]]
     */
    public SQLHeavy.LockingMode locking_mode {
      get { return SQLHeavy.LockingMode.from_string (this.pragma_get_string ("locking_mode")); }
      set { this.pragma_set_string ("locking_mode", value.to_string ()); }
    }

    /**
     * Page size
     *
     * Page size of the database
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_page_size]]
     */
    public int page_size {
      get { return this.pragma_get_int ("page_size"); }
      set {
        if ( (value & (value - 1)) != 0 )
          GLib.critical ("Page size must be a power of two.");
        this.pragma_set_int ("page_size", value);
      }
    }

    /**
     * Max page count
     *
     * Maximum number of pages in the database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_max_page_count]]
     */
    public int max_page_count {
      get { return this.pragma_get_int ("max_page_count"); }
      set { this.pragma_set_int ("max_page_count", value); }
    }

    /**
     * Read uncommitted
     *
     * Read uncommitted isolation
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_read_uncommitted]]
     */
    public bool read_uncommitted {
      get { return this.pragma_get_bool ("read_uncommitted"); }
      set { this.pragma_set_bool ("read_uncommitted", value); }
    }

    /**
     * Recursive triggers
     *
     * Recursive trigger capability
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_recursive_triggers]]
     */
    public bool recursive_triggers {
      get { return this.pragma_get_bool ("recursive_triggers"); }
      set { this.pragma_set_bool ("recursive_triggers", value); }
    }

    /**
     * Reverse unordered selects
     *
     * When enabled, this PRAGMA causes SELECT statements without a an
     * ORDER BY clause to emit their results in the reverse order of
     * what they normally would. This can help debug applications that
     * are making invalid assumptions about the result order.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_reverse_unordered_selects]]
     */
    public bool reverse_unordered_selects {
      get { return this.pragma_get_bool ("reverse_unordered_selects"); }
      set { this.pragma_set_bool ("reverse_unordered_selects", value); }
    }

    /**
     * Short column names
     *
     * Short column names flag
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_short_column_names]]
     * 
     * @see full_column_names
     */
    public bool short_column_names {
      get { return this.pragma_get_bool ("short_column_names"); }
      set { this.pragma_set_bool ("short_column_names", value); }
    }

    /**
     * Synchronous mode
     *
     * Synchronous flag
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_synchronous]]
     */
    public SQLHeavy.SynchronousMode synchronous {
      get { return SQLHeavy.SynchronousMode.from_string (this.pragma_get_string ("synchronous")); }
      set { this.pragma_set_string ("synchronous", value.to_string ()); }
    }

    /**
     * Temporary store mode
     *
     * Temporary store mode
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_temp_store]]
     */
    public SQLHeavy.TempStoreMode temp_store {
      get { return SQLHeavy.TempStoreMode.from_string (this.pragma_get_string ("temp_store")); }
      set { this.pragma_set_string ("temp_store", value.to_string ()); }
    }

    /**
     * Temporary store directory
     *
     * The directory where files used for storing temporary tables and
     * indices are kept.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_temp_store_directory]]
     */
    public string temp_store_directory {
      owned get { return this.pragma_get_string ("temp_store_directory"); }
      set { this.pragma_set_string ("temp_store_directory", value); }
    }

    //public GLib.SList<string> collation_list { get; }
    //public ?? database_list { get; }
    //public ?? get_foreign_key_list (string table_name);

    /**
     * Free list count
     *
     * Number of unused pages in the database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_freelist_count]]
     */
    public int free_list_count {
      get { return this.pragma_get_int ("freelist_count"); }
    }

    //public ?? get_index_info (string index_name);
    //public ?? get_index_list (string table_name);

    /**
     * Page count
     *
     * Total number of pages in the database file.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_page_count]]
     */
    public int page_count {
      get { return this.pragma_get_int ("page_count"); }
      set { this.pragma_set_int ("page_count", value); }
    }

    //public ?? get_table_info (string table_name);

    /**
     * Schema version
     *
     * The schema-version is usually only manipulated internally by SQLite.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_schema_version]]
     *
     * @see user_version
     */
    public int schema_version {
      get { return this.pragma_get_int ("schema_version"); }
      set { this.pragma_set_int ("schema_version", value); }
    }

    /**
     * User version
     *
     * User-defined schema version
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_user_version]]
     */
    public int user_version {
      get { return this.pragma_get_int ("user_version"); }
      set { this.pragma_set_int ("user_version", value); }
    }

    //public GLib.SList<string> integrity_check (int max_errors = 100);
    //public GLib.SList<string> quick_check (int max_errors = 100);

    /**
     * Parser trace
     *
     * Turn tracing of the SQL parser inside of the SQLite library on and off.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_parser_trace]]
     */
    public bool parser_trace {
      get { return this.pragma_get_bool ("parser_trace"); }
      set { this.pragma_set_bool ("parser_trace", value); }
    }

    /**
     * VDBE trace
     *
     * Turn tracing of the virtual database engine inside of the SQLite library on and off.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_vdbe_trace]]
     */
    public bool vdbe_trace {
      get { return this.pragma_get_bool ("vdbe_trace"); }
      set { this.pragma_set_bool ("vdbe_trace", value); }
    }

    /**
     * VDBE listing
     *
     * Turn listings of virtual machine programs on and off.
     *
     * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_vdbe_listing]]
     */
    public bool vdbe_listing {
      get { return this.pragma_get_bool ("vdbe_listing"); }
      set { this.pragma_set_bool ("vdbe_listing", value); }
    }

    construct {
      if ( this.filename != ":memory:" ) {
        string dirname = GLib.Path.get_dirname (filename);
        if ( !GLib.FileUtils.test (dirname, GLib.FileTest.EXISTS) )
          GLib.DirUtils.create_with_parents (dirname, 0700);
      }

      int flags = 0;
      if ( (this.mode & SQLHeavy.FileMode.READ) == SQLHeavy.FileMode.READ )
        flags = Sqlite.OPEN_READONLY;
      if ( (this.mode & SQLHeavy.FileMode.WRITE) == SQLHeavy.FileMode.WRITE )
        flags = Sqlite.OPEN_READWRITE;
      if ( (this.mode & SQLHeavy.FileMode.CREATE) == SQLHeavy.FileMode.CREATE )
        flags |= Sqlite.OPEN_CREATE;

      if ( sqlite3_open ((!) filename, out this.db, flags, null) != Sqlite.OK ) {
        this.db = null;
        GLib.critical ("Unable to open database.");
      }

      this.db.trace ((sql) => { this.sql_executed (sql); });
    }

    /**
     * Register aggregate function for use within SQLite
     *
     * See SQLite documentation at [[http://sqlite.org/c3ref/create_function.html]]
     *
     * @param name name of the function
     * @param argc number of arguments the function accepts, or -1 for any
     * @param func callback for the user defined function
     * @param final callback to finalize the user defined function
     */
    public void register_aggregate_function (string name,
                                             int argc,
                                             owned UserFunction.UserFunc func,
                                             owned UserFunction.FinalizeFunc final) {
      this.unregister_function (name);
      var ufc = new UserFunction.UserFuncData.scalar (this, name, argc, func);
      this.user_functions.insert (name, ufc);
      this.db.create_function<UserFunction.UserFuncData> (name, argc, Sqlite.UTF8, ufc, null,
                                                          UserFunction.on_user_function_called,
                                                          UserFunction.on_user_finalize_called);
    }

    /**
     * Register a scalar function for use within SQLite
     *
     * @param name name of the function to use
     * @param argc number of arguments the function accepts, or -1 for any
     * @param func callback for the user defined function
     */
    public void register_scalar_function (string name,
                                          int argc,
                                          owned UserFunction.UserFunc func) {
      this.unregister_function (name);
      var ufc = new UserFunction.UserFuncData.scalar (this, name, argc, func);
      this.user_functions.insert (name, ufc);
      this.db.create_function (name, argc, Sqlite.UTF8, ufc, UserFunction.on_user_function_called, null, null);
    }

    private void unregister_function_context (UserFunction.UserFuncData ufc) {
      this.db.create_function (ufc.name, ufc.argc, Sqlite.UTF8, ufc, null, null, null);
    }

    /**
     * Unregister a function
     *
     * Unregister a user defined function
     *
     * @param name name of the function
     */
    public void unregister_function (string name) {
      var ufc = this.user_functions.lookup (name);
      if ( ufc != null )
        this.unregister_function_context (ufc);
    }

    /**
     * Registers common functions
     *
     * More functions may be added later, but currently this function
     * will register:
     *
     * * REGEXP: see [[http://www.sqlite.org/lang_expr.html#regexp]]
     */
    public void register_common_functions () {
      this.register_scalar_function ("REGEXP", 2, UserFunction.regex);
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
      if ( filename == null ) filename = ":memory:";
      Object (filename: filename, mode: mode);
    }

    ~ Database () {
      foreach ( unowned UserFunction.UserFuncData udf in this.user_functions.get_values () )
        this.unregister_function_context (udf);

      if ( this.db != null )
        sqlite3_close (this.db);
    }
  }
}
