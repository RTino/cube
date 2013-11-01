# JSON IMPORTER (Default)
# --------------------------------------------------------------------------
# Imports JSON data to Cube.

BaseImporter = require "../baseImporter.coffee"

class JsonImporter extends BaseImporter

    title: "JSON Importer"


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Transform default JSON.
    transform: (callback) =>
        callback null, @rawData


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = new JsonImporter()