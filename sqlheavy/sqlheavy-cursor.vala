namespace SQLHeavy {
  /**
   * Cursor which can move bidirectionally through a set of records
   */
  public interface Cursor : SQLHeavy.RecordSet {
    /**
     * Move to the first entry
     */
    public void first () throws SQLHeavy.Error {
      move_to (0);
    }

    /**
     * Move to the last entry
     */
    public void last () throws SQLHeavy.Error {
      while ( next () ) { }
    }

    /**
     * Move to the previous entry
     *
     * @return whether the move was successful
     */
    public abstract bool previous () throws SQLHeavy.Error;

    /**
     * Retrieve the current record
     */
    public abstract SQLHeavy.Record get () throws SQLHeavy.Error;

    /**
     * Move to a specific entry
     *
     * @param offset the numeric offset to move to
     * @return whether the move was successful
     */
    public abstract bool move_to (int64 offset) throws SQLHeavy.Error;
  }
}
