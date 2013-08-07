# CSV IMPORTER
# --------------------------------------------------------------------------
# Imports CSV data to Cube.

BaseImporter = require "../baseImporter.coffee"

class CsvImporter extends BaseImporter


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Wipe the entity data from the Solr database.
    wipe: =>
        console.warn "Wipe data from Solr..."


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = CsvImporter