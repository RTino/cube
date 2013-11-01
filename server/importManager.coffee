# IMPORT MANAGER
# --------------------------------------------------------------------------
# Manages importers automatically.

class ImportManager

    expresser = require "expresser"
    fs = require "fs"
    moment = require "moment"
    path = require "path"

    # The timers are saved to the jobs array, and the running is set during start / stop.
    jobs: []
    running: false


    # START AND STOP
    # ----------------------------------------------------------------------

    # Start all importers.
    start: =>
        if @running
            if expresser.settings.general.debug
                expresser.logger.warn "ImportManager", "start", "Cancelled, already running."
            return

        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "start"

        # Clean current jobs before starting and set running to true.
        clearInterval job.timer for job in @jobs
        @jobs = []
        @running = true

        # Read import.json files.
        p = path.join __dirname, "../entities"
        fs.readdir p, @readImportSettings

    # Stop all importers.
    stop: =>
        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "stop"

        # Stop all jobs.
        clearInterval job.timer for job in @jobs

        # Reset jobs array and set running to false.
        @jobs = []
        @running = false


    # INTERNAL METHODS
    # ----------------------------------------------------------------------

    # Read each import settings.
    readImportSettings: (err, files) =>
        if err?
            return expresser.logger.error "ImportManager", "readImportSettings", err

        # Iterate all entities folder and search for import.json files.
        for f in files
            basePath = path.join __dirname, "../entities/", f
            p = path.join basePath, "/import.json"

            # Only proceed if importers.json file exists.
            if fs.existsSync p
                entity = path.basename basePath
                importers = fs.readFileSync p
                importers = JSON.parse importers
                @parseImporters entity, importers

    # Iterate and parse data from a importers.json file.
    parseImporters: (entity, importers) =>
        for i in importers
            if expresser.settings.general.debug
                expresser.logger.info "ImportManager", "parseImporters", i

            # Get importer type, or use jsonImporter as default.
            importerType = i.type
            importerType = "json" if not importerType? or importerType is ""

            # Require specified importer.
            importer = require "./importers/#{importerType.toLowerCase()}Importer.coffee"

            # Get importer options and schedule.
            importer.options = i
            importer.entity = entity
            importer.schema = require "../entities/#{entity}/schema.json"

            # Set schedule and interval.
            schedule = i.schedule

            if not schedule?
                expresser.logger.warn "ImportManager", "parseImports", "Skipping: schedule was not set for importer."
            else if schedule < 5
                expresser.logger.warn "ImportManager", "parseImports", "Skipping: schedule interval is too low (less than 5 seconds)."
            else
                # Add importer to the jobs list.
                job = {}
                job.importer = importer
                job.timer = setInterval importer.run, schedule * 1000

                @jobs.push job


# EXPORTS
# --------------------------------------------------------------------------
ImportManager.getInstance = ->
    @instance = new ImportManager() if not @instance?
    return @instance

module.exports = exports = ImportManager.getInstance()