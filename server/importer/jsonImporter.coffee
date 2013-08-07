# JSON IMPORTER
# --------------------------------------------------------------------------
# Imports JSON data to Cube.

BaseImporter = require "../baseImporter.coffee"

class JsonImporter extends BaseImporter


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Wipe the entity data from the Solr database.
    wipe: =>
        console.warn "Wipe data from Solr..."


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = JsonImporter