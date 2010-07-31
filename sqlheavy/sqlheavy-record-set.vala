namespace SQLHeavy {
  /**
   * A group of {@link Record}s
   */
  public interface RecordSet : SQLHeavy.Record {
    /**
     * Move to the next record in the set
     *
     * @return true on success, false if there are no more records
     */
    public abstract bool next () throws SQLHeavy.Error;
  }
}
