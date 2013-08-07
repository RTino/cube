# IMPORT MANAGER
# --------------------------------------------------------------------------
# Manages importers automatically.

class ImportManager

    fs = require "fs"
    path = require "path"

    # The timers are saved to the jobs array.
    jobs: []


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Read each import settings.
    readImportSettings = (err, files) =>
        for f in files
            p = path.combine f, "importers.json"
            if fs.existsSync p
                importers = fs.readFileSync p
                importers = JSON.parse importers
                parseImporters importers

    # Parse data from a importers.json file.
    parseImporters = ()


    # Start all importers.
    start: =>
        p = path.resolve __dirname, "/entities"
        fs.readdir p, readImportSettings

    # Stop all importers.
    stop: =>



# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = ImportManager