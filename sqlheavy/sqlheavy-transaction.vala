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
      lock ( this._queue ) {
        if ( this._queue != null && (this._queue.get_length () > 0) ) {
          try {
            for ( GLib.SequenceIter<SQLHeavy.Query> iter = this._queue.get_begin_iter () ;
                  !iter.is_end () ;
                  iter = iter.next () ) {
              SQLHeavy.QueryResult result = new SQLHeavy.QueryResult.no_exec (iter.get ());
              result.next_internal ();
              iter.remove ();
            }
          } catch ( SQLHeavy.Error e ) {
            GLib.critical ("Unable to execute queued query: %s", e.message);
          }
        }
      }

      this._transaction_lock.leave ();
    }

    private GLib.Sequence<SQLHeavy.Query>? _queue = null;

    /**
     * {@inheritDoc}
     */
    public void queue (SQLHeavy.Query query) throws SQLHeavy.Error {
      lock ( this._queue ) {
        if ( this._queue == null )
          this._queue = new GLib.Sequence<SQLHeavy.Query> ();

        this._queue.append (query);
      }
    }

    /**
     * The transaction has been resolved (committed or rolled back)
     *
     * @param status whether the transaction was committed or rolled back
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

      SQLHeavy.Query query = this.parent.prepare ("%s SAVEPOINT 'SQLHeavy-0x%x';".printf (commit ? "RELEASE" : "ROLLBACK TRANSACTION TO", (uint)this));
      this.parent.queue (query);

      this.status = commit ? TransactionStatus.COMMITTED : TransactionStatus.ROLLED_BACK;
      this.parent.@unlock ();
      this.resolved (this.status);
    }


    /**
     * Resolve the transaction asychronously
     *
     * @param commit whether to commit the transaction or roll it back
     */
    private async void resolve_async (bool commit) throws SQLHeavy.Error {
      if ( this.status != TransactionStatus.UNRESOLVED )
        throw new SQLHeavy.Error.TRANSACTION ("Refusing to resolve an already resolved transaction.");

      SQLHeavy.Query query = this.prepare ("%s SAVEPOINT 'SQLHeavy-0x%x';".printf (commit ? "RELEASE" : "ROLLBACK TRANSACTION TO", (uint)this));
      yield query.execute_async ();

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
     * Commit the transaction to the database asynchronously
     */
    public async void commit_async () throws SQLHeavy.Error {
      yield this.resolve_async (true);
    }

    /**
     * Rollback the transaction
     */
    public void rollback () throws SQLHeavy.Error {
      this.resolve (false);
    }

    /**
     * Rollback the transaction asynchronously
     */
    public async void rollback_async () throws SQLHeavy.Error {
      yield this.resolve_async (false);
    }

    ~ Transaction () {
      if ( this.status == TransactionStatus.UNRESOLVED )
        this.rollback ();
    }

    private SQLHeavy.Error? err = null;

    construct {
      this.parent.@lock ();

      try {
        this.prepare ("SAVEPOINT 'SQLHeavy-0x%x';".printf ((uint)this)).execute (null);
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
