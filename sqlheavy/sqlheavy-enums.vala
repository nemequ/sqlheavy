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
    EXCLUSIVE
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
}
