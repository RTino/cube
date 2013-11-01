# CSV IMPORTER
# --------------------------------------------------------------------------
# Imports CSV data to Cube.

BaseImporter = require "../baseImporter.coffee"

class CsvImporter extends BaseImporter

    title: "CSV Importer"

    # Required modules.
    csv2json = require("csvtojson").core.Converter


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Transform CSV to JSON.
    transform: (callback) =>
        csv2json.on "end_parsed", (jsonData) => callback null, jsonData
        csv2json.from @rawData


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = new CsvImporter()