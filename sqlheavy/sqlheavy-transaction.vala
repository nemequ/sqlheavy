namespace SQLHeavy {
  /**
   * Object representing an SQLite transaction
   *
   * Note that this is implemented using SQLite's
   * [[http://sqlite.org/lang_savepoint.html|SAVEPOINT]] feature,
   * meaning that by default it is like that of a
   * {@link TransactionType.DEFERRED} transaction. This behaviour may
   * be modified by first manually running a
   * [[http://sqlite.org/lang_transaction.html|transaction]] in SQL,
   * but remember that such transactions cannot be nested.
   */
  public class Transaction : GLib.Object, Queryable {
    /**
     * Status of the transaction.
     */
    public TransactionStatus status { get; private set; default = TransactionStatus.UNRESOLVED; }

    /**
     * Parent querayble
     */
    public SQLHeavy.Queryable? parent { get; construct; }

    /**
     * {@inheritDoc}
     */
    public SQLHeavy.Database database { owned get { return this.parent.database; } }

    private Sqlite.Mutex? _transaction_lock = new Sqlite.Mutex (Sqlite.MUTEX_FAST);

    /**
     * {@inheritDoc}
     */
    public void @lock () {
      this._transaction_lock.enter ();
    }

    /**
     * {@inheritDoc}
     */
    public void @unlock () {
      this._transaction_lock.leave ();
    }

    /**
     * The transaction has been resolved (committed or rolled back)
     *
     * @param committed whether the transaction was committed or rolled back
     */
    public signal void resolved (SQLHeavy.TransactionStatus status);

    /**
     * Resolve the transaction
     *
     * @param commit whether to commit the transaction or roll it back
     */
    private void resolve (bool commit) throws SQLHeavy.Error {
      if ( this.status != TransactionStatus.UNRESOLVED )
        throw new SQLHeavy.Error.TRANSACTION ("Refusing to resolve an already resolved transaction.");

      this.execute ("%s SAVEPOINT 'SQLHeavy-0x%x';".printf (commit ? "RELEASE" : "ROLLBACK TRANSACTION TO", (uint)this));

      this.status = commit ? TransactionStatus.COMMITTED : TransactionStatus.ROLLED_BACK;
      this.parent.@unlock ();
      this.resolved (this.status);
    }

    /**
     * Commit the transaction to the database
     */
    public void commit () throws SQLHeavy.Error {
      this.resolve (true);
    }

    /**
     * Rollback the transaction
     */
    public void rollback () throws SQLHeavy.Error {
      this.resolve (false);
    }

    ~ Transaction () {
      if ( this.status == TransactionStatus.UNRESOLVED )
        this.rollback ();
    }

    private SQLHeavy.Error? err = null;

    construct {
      this.parent.@lock ();

      try {
        this.execute ("SAVEPOINT 'SQLHeavy-0x%x';".printf ((uint)this));
      }
      catch ( SQLHeavy.Error e ) {
        this.err = e;
        GLib.critical ("Unable to create transaction: %s (%d)", e.message, e.code);
        this.parent.@unlock ();
      }
    }

    /**
     * Create a new transaction.
     *
     * @param parent The queryable to create the transaction on top of
     */
    public Transaction (SQLHeavy.Queryable parent) throws SQLHeavy.Error {
      Object (parent: parent);
      if ( this.err != null )
        throw this.err;
    }
  }
}
