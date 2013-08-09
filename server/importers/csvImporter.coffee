# CSV IMPORTER
# --------------------------------------------------------------------------
# Imports CSV data to Cube.

BaseImporter = require "../baseImporter.coffee"

class CsvImporter extends BaseImporter


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Fetch the CSV file from the specified URL.
    fetch: (callback) =>
        if not @options.uri
            err = "CSV file or URL was not specified."
            return callback err, null

        if @options.uri


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = new CsvImporter()