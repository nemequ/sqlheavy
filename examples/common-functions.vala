/**
 * Demonstrates a few of the user-defined functions SQLHeavy can
 * register.
 */
private static int main (string[] args) {
  try {
    var db = new SQLHeavy.Database ();
    // Register the common user-defined functions
    db.register_common_functions ();

    var test_string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur egestas, risus eu consectetur malesuada, lacus dolor lobortis arcu, id vulputate justo quam ut quam. Aenean nulla arcu, placerat eu pellentesque et, scelerisque non nunc. Praesent id mi metus. Aenean dignissim vestibulum dolor, ac blandit massa sodales a. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer sem nunc, faucibus vel vestibulum nec, luctus eu leo. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Pellentesque ultricies odio a turpis pharetra rhoncus. Curabitur ut lectus eu nisl elementum imperdiet sed at lectus. Cras vehicula urna sit amet arcu accumsan tristique. Proin ultrices, leo auctor tempor commodo, metus justo luctus lorem, a egestas urna purus sit amet dolor. Praesent ullamcorper elit et leo interdum porta.";

    GLib.stdout.puts ("Testing cryptographic hashes...\n");
    var query = db.prepare ("SELECT MD5(:data), SHA1(:data), SHA256(:data);");
    query.set_string (":data", test_string);
    var res = query.execute ();
    GLib.stdout.printf ("   MD5: %s\n", res.fetch_string (0));
    GLib.stdout.printf ("  SHA1: %s\n", res.fetch_string (1));
    GLib.stdout.printf ("SHA256: %s\n", res.fetch_string (2));
    GLib.stdout.putc ('\n');

    GLib.stdout.puts ("Testing compression...\n");
    var data = (uint8[]) test_string.to_utf8 ();
    GLib.stdout.printf ("Original size: %d bytes\n", (int) test_string.size ());
    query = db.prepare ("SELECT COMPRESS(:data);");
    query.set_blob (":data", data);
    var compressed = query.execute ().fetch_blob (0);
    GLib.stdout.printf ("Compressed size: %d bytes\n", compressed.length);
    query = db.prepare ("SELECT DECOMPRESS(:data);");
    query.set_blob (":data", compressed);
    GLib.stdout.puts ("Decompression " + (query.execute ().fetch_string () == test_string ? "successful" : "failed") + ".\n");
  }
  catch ( SQLHeavy.Error e ) {
    GLib.error ("%s", e.message);
  }

  return 0;
}