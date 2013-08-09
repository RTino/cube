# IMPORT MANAGER
# --------------------------------------------------------------------------
# Manages importers automatically.

class ImportManager

    fs = require "fs"
    moment = require "moment"
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
    parseImporters = (data) =>
        importer = require "importers/#{data.type}Importer.coffee"
        importer.options = data

        # Set schedule and interval.
        schedule = data.schedule
        timer = setInterval importer.run, schedule

        # Add importer to the jobs list.
        @jobs.push timer

    # Start all importers.
    start: =>
        @stop()

        p = path.resolve __dirname, "/entities"
        fs.readdir p, readImportSettings

    # Stop all importers.
    stop: =>
        clearInterval timer for timer in @jobs
        @jobs = []


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = ImportManager