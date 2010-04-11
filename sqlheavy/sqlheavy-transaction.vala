namespace SQLHeavy {
  /**
   * Object representing an SQLite transaction
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

    public SQLHeavy.Database database { get { return this.parent.database; } }

    private Sqlite.Mutex? _transaction_lock = new Sqlite.Mutex (Sqlite.MUTEX_FAST);

    public void @lock () {
      this._transaction_lock.enter ();
    }

    public void @unlock () {
      this._transaction_lock.leave ();
    }

    private void resolve (bool commit) {
      if ( this.status != TransactionStatus.UNRESOLVED ) {
        GLib.warning ("Refusing to resolve an already resolved transaction.");
        return;
      }

      try {
        this.execute ("%s SAVEPOINT 'SQLHeavy-0x%x';".printf (commit ? "RELEASE" : "ROLLBACK TRANSACTION TO", (uint)this));
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to resolve transaction: %s (%d)", e.message, e.code);
        return;
      }

      this.status = commit ? TransactionStatus.COMMITTED : TransactionStatus.ROLLED_BACK;
      this.parent.@unlock ();
    }

    /**
     * Commit the transaction to the database
     */
    public void commit () {
      this.resolve (true);
    }

    /**
     * Rollback the transaction
     */
    public void rollback () {
      this.resolve (false);
    }

    ~ Transaction () {
      if ( this.status == TransactionStatus.UNRESOLVED )
        GLib.warning ("Destroying an unresolved transaction.");
    }

    construct {
      this.parent.@lock ();

      try {
        this.execute ("SAVEPOINT 'SQLHeavy-0x%x';".printf ((uint)this));
      }
      catch ( SQLHeavy.Error e ) {
        GLib.critical ("Unable to create transaction: %s (%d)", e.message, e.code);
        this.parent.@unlock ();
      }
    }

    /**
     * Create a new transaction.
     *
     * @param parent, The queryable to create the transaction on top of
     */
    public Transaction (SQLHeavy.Queryable parent) {
      Object (parent: parent);
    }
  }
}
