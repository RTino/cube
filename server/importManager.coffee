# IMPORT MANAGER
# --------------------------------------------------------------------------
# Manages importers automatically.

class ImportManager

    expresser = require "expresser"
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

            # Only proceed if importers.json file exists.
            if fs.existsSync p
                entity = path.basename p
                importers = fs.readFileSync p
                importers = JSON.parse importers
                parseImporters entity, importers

    # Iterate and parse data from a importers.json file.
    parseImporters = (entity, importers) =>
        for i in importers
            importer = require "importers/#{data.type}Importer.coffee"

            # Get importer options and schedule.
            importer.options = i.options
            importer.entity = entity
            importer.schema = require "../entities/#{entity}{/schema.json"

            # Set schedule and interval.
            schedule = i.options.schedule

            if not schedule?
                expresser.logger.warn "ImportManager", "parseImports", "Skipping: schedule was not set for importer."
            else if schedule < 5
                expresser.logger.warn "ImportManager", "parseImports", "Skipping: schedule interval is too low (less than 5)."
            else
                # Add importer to the jobs list.
                job = {}
                job.importer = importer
                job.timer = setInterval importer.run, schedule
                @jobs.push job

    # Start all importers.
    start: =>
        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "start"

        # Clean current jobs before starting.
        clearInterval job.timer for job in @jobs
        @jobs = []

        p = path.resolve __dirname, "/entities"
        fs.readdir p, readImportSettings

    # Stop all importers.
    stop: =>
        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "stop"

        clearInterval job.timer for job in @jobs
        @jobs = []


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = ImportManager