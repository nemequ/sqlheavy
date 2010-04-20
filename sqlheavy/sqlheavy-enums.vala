namespace SQLHeavy {
  /**
   * Transaction type.
   *
   * See SQLite documentation at [[http://sqlite.org/lang_transaction.html]]
   *
   * @see SQLHeavy.Transaction
   */
  public enum TransactionType {
    /**
     * No locks are acquired on the database until the database is
     * first accessed.
     */
    DEFERRED,
    /**
     * Lock database as immediately, without waiting for the database
     * to actually be used.
     */
    IMMEDIATE,
    /**
     * Lock database, including from other threads and processes.
     */
    EXCLUSIVE;

    public unowned string? to_string () {
      switch ( this ) {
        case DEFERRED:
          return "DEFERRED";
        case IMMEDIATE:
          return "IMMEDIATE";
        case EXCLUSIVE:
          return "EXCLUSIVE";
        default:
          return null;
      }
    }
  }

  /**
   * Mode to use when opening the database.
   */
  [Flags]
  public enum FileMode {
    /**
     * Open database for reading.
     */
    READ = 0x01,
    /**
     * Open database for writing.
     */
    WRITE = 0x02,
    /**
     * Create database if it doesn't yet exist.
     */
    CREATE = 0x04
  }

  /**
   * Auto-vacuum mode
   *
   * See SQLite documentation at [[http://sqlite.org/pragma.html#pragma_auto_vacuum]]
   *
   * @see Database.auto_vacuum
   * @see Database.free_list_count
   * @see Database.incremental_vacuum
   */
  public enum AutoVacuum {
    /**
     * Auto-vacuum is disabled.
     */
    NONE = 0,
    /**
     * Auto-vacuum every time a transaction is committed.
     */
    FULL = 1,
    /**
     * Store information for vacuuming, but do not perform
     * auto-vacuuming.
     *
     * @see Database.incremental_vacuum
     */
    INCREMENTAL = 2
  }

  /**
   * Data encoding
   *
   * SQLHeavy applications should generally use UTF-8, since strings
   * are assumed to be UTF-8 encoded.
   *
   * See SQLite documentation at [[http://sqlite.org/pragma.html#pragma_encoding]]
   *
   * @see Database.encoding
   */
  public enum Encoding {
    /**
     * UTF-8
     */
    UTF_8,
    /**
     * UTF-16 with native encoding
     */
    UTF_16,
    /**
     * UTF-16 with little-endian encoding
     */
    UTF_16LE,
    /**
     * UTF-16 wiht big-endian encoding
     */
    UTF_16BE;

    /**
     * Convert a string value to an Encoding
     *
     * @param encoding encoding
     */
    public static Encoding from_string (string encoding) {
      var enc = encoding.up ();

      if ( enc == UTF_8.to_string().up() )
        return UTF_8;
      else if ( enc == UTF_16.to_string().up() )
        return UTF_16;
      else if ( enc == UTF_16LE.to_string().up() )
        return UTF_16LE;
      else if ( enc == UTF_16BE.to_string().up() )
        return UTF_16BE;

      GLib.critical ("Invalid encoding (%s).", encoding);
      return UTF_8;
    }

    public unowned string? to_string () {
      switch ( this ) {
        case UTF_8:
          return "UTF-8";
        case UTF_16:
          return "UTF-16";
        case UTF_16LE:
          return "UTF-16le";
        case UTF_16BE:
          return "UTF-16be";
        default:
          return null;
      }
    }
  }

  /**
   * Journal mode
   *
   * See SQLite documentation at [[http://sqlite.org/pragma.html#pragma_journal_mode]]
   *
   * @see Database.journal_mode
   */
  public enum JournalMode {
    /**
     * Journal is deleted after each transaction
     */
    DELETE,
    /**
     * Truncate the journal instead of deleting it
     */
    TRUNCATE,
    /**
     * Overwrite the journal with zeros instead of deleting it
     */
    PERSIST,
    /**
     * Stores the journal in RAM instead of on disk
     */
    MEMORY,
    /**
     * Disable the journal completely
     */
    OFF;

    public static JournalMode from_string (string journal_mode) {
      string mode = journal_mode.up ();

      if ( mode == DELETE.to_string () )
        return DELETE;
      else if ( mode == TRUNCATE.to_string () )
        return TRUNCATE;
      else if ( mode == PERSIST.to_string () )
        return PERSIST;
      else if ( mode == MEMORY.to_string () )
        return MEMORY;
      else if ( mode == OFF.to_string () )
        return OFF;
      else
        return DELETE;
    }

    public unowned string? to_string () {
      switch ( this ) {
        case DELETE:
          return "DELETE";
        case TRUNCATE:
          return "TRUNCATE";
        case PERSIST:
          return "PERSIST";
        case MEMORY:
          return "MEMORY";
        case OFF:
          return "OFF";
        default:
          return null;
      }
    }
  }

  /**
   * Database locking mode
   *
   * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_locking_mode]]
   *
   * @see Database.locking_mode
   */
  public enum LockingMode {
    /**
     * Database connection unlocks the database file at the conclusion
     * of each read or write transaction.
     */
    NORMAL,
    /**
     * Database connection never releases file-locks.
     */
    EXCLUSIVE;

    public static LockingMode from_string (string locking_mode) {
      var mode = locking_mode.up ();

      if ( mode == NORMAL.to_string () )
        return NORMAL;
      else if ( mode == EXCLUSIVE.to_string () )
        return EXCLUSIVE;
      else
        return NORMAL;
    }

    public unowned string? to_string () {
      switch ( this ) {
        case NORMAL:
          return "NORMAL";
        case EXCLUSIVE:
          return "EXCLUSIVE";
        default:
          return null;
      }
    }
  }

  /**
   * Synchronous Mode
   *
   * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_synchronous]]
   *
   * @see Database.synchronous
   */
  public enum SynchronousMode {
    /**
     * SQLite continues without pausing as soon as it has handed data
     * off to the operating system
     */
    OFF,
    /**
     * Database engine will still pause at the most critical moments,
     * but less often than in FULL mode
     */
    NORMAL,
    /**
     *  SQLite will block until data is safely written to disk
     */
    FULL;

    public static SynchronousMode from_string (string synchronous_mode) {
      var mode = synchronous_mode.up ();

      if ( mode == OFF.to_string () )
        return OFF;
      else if ( mode == NORMAL.to_string () )
        return NORMAL;
      else if ( mode == FULL.to_string () )
        return FULL;
      else
        return FULL;
    }

    public unowned string? to_string () {
      switch ( this ) {
        case OFF:
          return "OFF";
        case NORMAL:
          return "NORMAL";
        case FULL:
          return "FULL";
        default:
          return null;
      }
    }
  }

  /**
   * Temporary store mode
   *
   * See SQLite documentation at: [[http://sqlite.org/pragma.html#pragma_temp_store]]
   *
   * @see Database.temp_store
   */
  public enum TempStoreMode {
    /**
     * The compile-time C preprocessor macro SQLITE_TEMP_STORE is used
     * to determine where temporary tables and indices are stored
     */
    DEFAULT,
    /**
     * Temporary tables and indices are stored in a file
     */
    FILE,
    /**
     * Temporary tables and indices are stored in memory
     */
    MEMORY;

    public static TempStoreMode from_string (string temp_store_mode) {
      var mode = temp_store_mode.up ();

      if ( (mode == DEFAULT.to_string()) || (mode == "0") )
        return DEFAULT;
      else if ( (mode == FILE.to_string()) || (mode == "1") )
        return FILE;
      else if ( (mode == MEMORY.to_string()) || (mode == "2") )
        return MEMORY;
      else
        return DEFAULT;
    }

    public unowned string? to_string () {
      switch ( this ) {
        case DEFAULT:
          return "DEFAULT";
        case FILE:
          return "FILE";
        case MEMORY:
          return "MEMORY";
        default:
          return null;
      }
    }
  }

  /**
   * Transaction Status
   *
   * @see Transaction.status
   */
  public enum TransactionStatus {
    /**
     * Transaction has not yet been committed or rolled back
     */
    UNRESOLVED = 0,
    /**
     * Transaction has been committed
     */
    COMMITTED,
    /**
     * Transaction has been rolled back
     */
    ROLLED_BACK
  }
}
