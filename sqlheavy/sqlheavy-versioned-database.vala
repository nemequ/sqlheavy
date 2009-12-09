namespace SQLHeavy {
  public class VersionedDatabase : SQLHeavy.Database {
    public VersionedDatabase (string file, string directory) throws SQLHeavy.Error {
      this.open (file, SQLHeavy.FileMode.READ | SQLHeavy.FileMode.WRITE | SQLHeavy.FileMode.CREATE);

      var version = this.user_version;
      if ( version == 0 ) {
        this.run_script (GLib.Path.build_filename (directory, "Create.sql"));
        if ( (version = this.user_version) == 0 )
          this.user_version = version = 1;
      }

      while ( true ) {
        string script_name = GLib.Path.build_filename(directory, "Update-to-%d.sql".printf (version + 1));
        if ( !GLib.FileUtils.test (script_name, GLib.FileTest.EXISTS) )
          break;

        this.run_script (script_name);
        this.user_version = ++version;
      }
    }
  }
}
