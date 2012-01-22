namespace SQLHeavy {
  /**
   * Version information
   */
  namespace Version {
    [CCode (cname = "SQLHEAVY_MAJOR_VERSION", cheader_filename = "config.h")]
    private extern const int MAJOR;
    [CCode (cname = "SQLHEAVY_MINOR_VERSION", cheader_filename = "config.h")]
    private extern const int MINOR;
    [CCode (cname = "SQLHEAVY_MICRO_VERSION", cheader_filename = "config.h")]
    private extern const int MICRO;
    [CCode (cname = "SQLHEAVY_API_VERSION", cheader_filename = "config.h")]
    private extern const string API;

    /**
     * Get the API version currently in use.
     *
     * @return the API version
     */
    public string api () {
      return API;
    }

    /**
     * Return an integer representation of the version currenly in
     * use.
     *
     * This result is major * 1000000 + minor * 1000 + micro.
     *
     * @return the version number of the library
     */
    public int library () {
      return (MAJOR * 1000000) + (MINOR * 1000) + MICRO;
    }

    /**
     * Return an integer representation of the SQLite version
     * currently in use.
     *
     * This function is just an alias for
     * Sqlite.libversion_number. The version is number is in the same
     * format as the result of the {@link library} function.
     *
     * @return the version number of the SQLite library
     * @see library
     */
    public int sqlite_library () {
      return Sqlite.libversion_number ();
    }
  }
}
