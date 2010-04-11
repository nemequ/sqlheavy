namespace SQLHeavy {
  /**
   * Class representing a stack of transactions.
   */
  public class TransactionStack : GLib.Object, Queryable {
    /**
     * The original queryable of this stack
     */
    public SQLHeavy.Queryable patriarch { get; construct; }

    private GLib.SList<SQLHeavy.Transaction> stack = new GLib.SList<SQLHeavy.Transaction> ();
    private uint stack_length = 0;

    private SQLHeavy.Queryable active_queryable {
      get {
        return (this.stack_length > 0) ? this.stack.data : this.patriarch;
      }
    }

    public SQLHeavy.Database database { get { return this.patriarch.database; } }

    public void @lock () {
      this.active_queryable.@lock ();
    }

    public void @unlock () {
      this.active_queryable.unlock ();
    }

    /**
     * Add a transaction to the stack
     */
    public void push () {
      this.stack.prepend (this.active_queryable.begin_transaction ());
      this.stack_length++;
    }

    /**
     * Remove a transaction from the stack
     *
     * @param commit whether to commit or rollback the transaction
     * @return true on success, false on failure (e.g., stack is empty)
     */
    public bool pop (bool commit) {
      if ( this.stack_length > 0 ) {
        if ( commit )
          this.stack.data.commit ();
        else
          this.stack.data.rollback ();

        this.stack.remove_link (this.stack);
        this.stack_length--;
        return true;
      }
      else
        return false;
    }

    /**
     * Remove all transactions from the stack
     *
     * @param commit whether to commit or rollback the transactions
     */
    public void pop_all (bool commit) {
      while ( this.stack_length > 0 )
        this.pop (commit);
    }

    public void execute (string sql, ssize_t max_len = -1) throws Error {
      this.active_queryable.execute (sql, max_len);
    }

    public SQLHeavy.Statement prepare (string sql) throws SQLHeavy.Error {
      return this.active_queryable.prepare (sql);
    }

    public void run_script (string filename) throws Error {
      this.active_queryable.run_script (filename);
    }

    public TransactionStack (Queryable patriarch) {
      Object (patriarch: patriarch);
    }
  }
}
