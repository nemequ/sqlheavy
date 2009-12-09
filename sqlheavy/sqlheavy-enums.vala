namespace SQLHeavy {
  /**
   * Transaction type.
   */
  public enum TransactionType {
    /**
     * No locks are acquired on the database until the database is
     * first accessed. Thus with a deferred transaction, the BEGIN
     * statement itself does nothing. Locks are not acquired until the
     * first read or write operation. The first read operation against
     * a database creates a SHARED lock and the first write operation
     * creates a RESERVED lock. Because the acquisition of locks is
     * deferred until they are needed, it is possible that another
     * thread or process could create a separate transaction and write
     * to the database after the BEGIN on the current thread has
     * executed.
     */
    DEFERRED,
    /**
     * RESERVED locks are acquired on all databases as soon as the
     * BEGIN command is executed, without waiting for the database to
     * be used. After a BEGIN IMMEDIATE, you are guaranteed that no
     * other thread or process will be able to write to the database
     * or do a BEGIN IMMEDIATE or BEGIN EXCLUSIVE. Other processes can
     * continue to read from the database, however.
     */
    IMMEDIATE,
    /**
     * An exclusive transaction causes EXCLUSIVE locks to be acquired
     * on all databases. After a BEGIN EXCLUSIVE, you are guaranteed
     * that no other thread or process will be able to read or write
     * the database until the transaction is complete.
     */
    EXCLUSIVE;

    public weak string? to_string () {
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

  public enum AutoVacuum {
    NONE = 0,
    FULL = 1,
    INCREMENTAL = 2
  }

  public enum Encoding {
    UTF_8,
    UTF_16,
    UTF_16LE,
    UTF_16BE;

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

    public weak string? to_string () {
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

  public enum JournalMode {
    DELETE,
    TRUNCATE,
    PERSIST,
    MEMORY,
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

    public weak string? to_string () {
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

  public enum LockingMode {
    NORMAL,
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

    public weak string? to_string () {
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

  public enum SynchronousMode {
    OFF,
    NORMAL,
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

    public weak string? to_string () {
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

  public enum TempStoreMode {
    DEFAULT,
    FILE,
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

    public weak string? to_string () {
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
}
