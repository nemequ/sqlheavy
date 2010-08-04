namespace SQLHeavy {
  internal static bool error_if_not_ok (int ec, SQLHeavy.Queryable? queryable = null) throws SQLHeavy.Error {
    if ( ec == Sqlite.OK )
      return true;

    string msg = sqlite_errstr (ec);

    switch ( ec ) {
      case Sqlite.ERROR:      throw new Error.ERROR        (msg);
      case Sqlite.INTERNAL:   throw new Error.INTERNAL     (msg);
      case Sqlite.PERM:       throw new Error.ACCESS_DENIED(msg);
      case Sqlite.ABORT:      throw new Error.ABORTED      (msg);
      case Sqlite.BUSY:       throw new Error.BUSY         (msg);
      case Sqlite.LOCKED:     throw new Error.LOCKED       (msg);
      case Sqlite.NOMEM:      throw new Error.NO_MEMORY    (msg);
      case Sqlite.READONLY:   throw new Error.READ_ONLY    (msg);
      case Sqlite.INTERRUPT:  throw new Error.INTERRUPTED  (msg);
      case Sqlite.IOERR:      throw new Error.IO           (msg);
      case Sqlite.CORRUPT:    throw new Error.CORRUPT      (msg);
      case Sqlite.FULL:       throw new Error.FULL         (msg);
      case Sqlite.CANTOPEN:   throw new Error.CAN_NOT_OPEN (msg);
      case Sqlite.EMPTY:      throw new Error.EMPTY        (msg);
      case Sqlite.SCHEMA:     throw new Error.SCHEMA       (msg);
      case Sqlite.TOOBIG:     throw new Error.TOO_BIG      (msg);
      case Sqlite.CONSTRAINT: throw new Error.CONSTRAINT   (msg);
      case Sqlite.MISMATCH:   throw new Error.MISMATCH     (msg);
      case Sqlite.MISUSE:     throw new Error.MISUSE       (msg);
      case Sqlite.NOLFS:      throw new Error.NOLFS        (msg);
      case Sqlite.AUTH:       throw new Error.AUTH         (msg);
      case Sqlite.FORMAT:     throw new Error.FORMAT       (msg);
      case Sqlite.RANGE:      throw new Error.RANGE        (msg);
      case Sqlite.NOTADB:     throw new Error.NOTADB       (msg);
      default:                throw new Error.UNKNOWN      (msg);
    }
  }

  /**
   * SQLHeavy Errors
   *
   * Most of these are from SQLite--see [[http://sqlite.org/c3ref/c_abort.html]] for documentation.
   */
  public errordomain Error {
    /**
     * An unknown error occured
     */
    UNKNOWN,
    /**
     * SQL error or missing database
     *
     * This is most commonly the result of a bad SQL query.
     */
    ERROR,
    /**
     * Internal logic error
     */
    INTERNAL,
    /**
     * Permission denied
     *
     * The library attempted to perform an operation for which it did
     * not have permission.
     */
    ACCESS_DENIED,
    /**
     * Callback routine requested an abort
     *
     * The query was cancelled.
     *
     * @see Query.execute_async
     */
    ABORTED,
    /**
     * The database is locked
     *
     * Another process or thread is currently accessing the database.
     */
    BUSY,
    /**
     * A table in the database is locked
     *
     * Another process or thread is currently accessing a table in the
     * database.
     */
    LOCKED,
    /**
     * Unable to allocate memory
     *
     * A call to malloc failed.
     */
    NO_MEMORY,
    /**
     * Attempt to write to a read-only database
     *
     * The library attempted to write to a database which was opened
     * in read-only mode.
     *
     * @see FileMode
     */
    READ_ONLY,
    /**
     * Operation interrupted
     */
    INTERRUPTED,
    /**
     * An I/O error occurred
     */
    IO,
    /**
     * The database disk image is malformed
     *
     * This is generally quite bad, but you may be able to recover by
     * dumping the database and creating a new one.
     */
    CORRUPT,
    /**
     * Not found
     */
    NOT_FOUND,
    /**
     * Insertion failed because the database is full
     */
    FULL,
    /**
     * Unable to open the database file
     */
    CAN_NOT_OPEN,
    /**
     * Database lock protocol error
     */
    PROTOCOL,
    /**
     * Database is empty
     */
    EMPTY,
    /**
     * Database schema changed
     *
     * This generally happens when you have a prepared statement
     * saved, execute a command which modifies the database schema,
     * then try to use the old prepared statement.
     */
    SCHEMA,
    /**
     * String or BLOB exceeds size limit
     */
    TOO_BIG,
    /**
     * Abort due to constraint violation
     */
    CONSTRAINT,
    /**
     * Data type mismatch
     */
    MISMATCH,
    /**
     * Library used incorrectly
     */
    MISUSE,
    /**
     * Uses OS features not supported on the host
     */
    NOLFS,
    /**
     * Authorization denied
     */
    AUTH,
    /**
     * Auxiliary database format error
     */
    FORMAT,
    /**
     * Specified parameter does not exist
     */
    RANGE,
    /**
     * Requested file is not a database
     */
    NOTADB,

    /**
     * An unhandled data type was encountered.
     */
    DATA_TYPE,
    /**
     * A thread error was encountered
     */
    THREAD,
    /**
     * A transaction error was encountered
     */
    TRANSACTION,
    /**
     * Feature not supported
     *
     * This is triggered when trying to make use of a feature only
     * present in a later version of SQLite than is currently in
     * use. For example, WAL in SQLite < 3.7.0.
     */
    FEATURE_NOT_SUPPORTED
  }

  /**
   * Convert an SQLHeavy.Error to an SQLite error code. This function
   * is used to convert errors thrown by user defined functions.
   *
   * @param e SQLHeavy error
   */
  internal int sqlite_code_from_error (SQLHeavy.Error e) {
    if ( e is Error.INTERNAL )
      return Sqlite.INTERNAL;
    else if ( e is Error.ACCESS_DENIED )
      return Sqlite.PERM;
    else if ( e is Error.ERROR )
      return Sqlite.ERROR;
    else if ( e is Error.ABORTED )
      return Sqlite.ABORT;
    else if ( e is Error.BUSY )
      return Sqlite.BUSY;
    else if ( e is Error.LOCKED )
      return Sqlite.LOCKED;
    else if ( e is Error.NO_MEMORY )
      return Sqlite.NOMEM;
    else if ( e is Error.READ_ONLY )
      return Sqlite.READONLY;
    else if ( e is Error.INTERRUPTED )
      return Sqlite.INTERRUPT;
    else if ( e is Error.IO )
      return Sqlite.IOERR;
    else if ( e is Error.CORRUPT )
      return Sqlite.CORRUPT;
    else if ( e is Error.FULL )
      return Sqlite.FULL;
    else if ( e is Error.CAN_NOT_OPEN )
      return Sqlite.CANTOPEN;
    else if ( e is Error.EMPTY )
      return Sqlite.EMPTY;
    else if ( e is Error.SCHEMA )
      return Sqlite.SCHEMA;
    else if ( e is Error.TOO_BIG )
      return Sqlite.TOOBIG;
    else if ( e is Error.CONSTRAINT )
      return Sqlite.CONSTRAINT;
    else if ( e is Error.MISMATCH )
      return Sqlite.MISMATCH;
    else if ( e is Error.MISUSE )
      return Sqlite.MISUSE;
    else if ( e is Error.NOLFS )
      return Sqlite.NOLFS;
    else if ( e is Error.AUTH )
      return Sqlite.AUTH;
    else if ( e is Error.FORMAT )
      return Sqlite.FORMAT;
    else if ( e is Error.RANGE )
      return Sqlite.RANGE;
    else if ( e is Error.NOTADB )
      return Sqlite.NOTADB;
    else
      return Sqlite.ERROR;
  }

  /**
   * Convert an SQLite error code into a string representation.
   */
  internal unowned string sqlite_errstr (int ec) {
    switch ( ec ) {
      case Sqlite.ERROR:
        return "SQL error or missing database";
      case Sqlite.INTERNAL:
        return "Internal logic error in SQLite";
      case Sqlite.PERM:
        return "Access permission denied";
      case Sqlite.ABORT:
        return "Callback routine requested an abort";
      case Sqlite.BUSY:
        return "The database file is locked";
      case Sqlite.LOCKED:
        return "A table in the database is locked";
      case Sqlite.NOMEM:
        return "A malloc failed";
      case Sqlite.READONLY:
        return "Attempt to write to a read-only database";
      case Sqlite.INTERRUPT:
        return "Operation interrupted";
      case Sqlite.IOERR:
        return "Some kind of disk I/O error occurred";
      case Sqlite.CORRUPT:
        return "The database disk image is malformed";
      case Sqlite.FULL:
        return "Insertion failed because database is full";
      case Sqlite.CANTOPEN:
        return "Unable to open the database file";
      case Sqlite.EMPTY:
        return "Database is empty";
      case Sqlite.SCHEMA:
        return "The database schema changed";
      case Sqlite.TOOBIG:
        return "String or BLOB exceeds size limit";
      case Sqlite.CONSTRAINT:
        return "Abort due to constraint violation";
      case Sqlite.MISMATCH:
        return "Data type mismatch";
      case Sqlite.MISUSE:
        return "Library used incorrectly";
      case Sqlite.NOLFS:
        return "Uses OS features not supported on host";
      case Sqlite.AUTH:
        return "Authorization denied";
      case Sqlite.FORMAT:
        return "Auxiliary database format error";
      case Sqlite.RANGE:
        return "Parameter out of range";
      case Sqlite.NOTADB:
        return "File opened that is not a database file";
      case Sqlite.ROW:
        return "sqlite3_step() has another row ready";
      case Sqlite.DONE:
        return "sqlite3_step() has finished executing";
      default:
        return "An unknown error occured";
    }
  }
}
