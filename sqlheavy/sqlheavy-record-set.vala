namespace SQLHeavy {
  public interface RecordSet : SQLHeavy.Record {
    public abstract bool next () throws SQLHeavy.Error;
  }
}
