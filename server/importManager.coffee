# IMPORT MANAGER
# --------------------------------------------------------------------------
# Manages importers automatically.

class ImportManager

    expresser = require "expresser"
    fs = require "fs"
    lodash = require "lodash"
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
                return expresser.logger.warn "ImportManager", "start", "Cancelled, already running."

        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "start"

        # Clean current jobs before starting and set `running` to true.
        clearTimeout job.timer for job in @jobs
        @jobs = []
        @running = true

        # Read import.json files.
        p = path.join __dirname, "../entities"
        fs.readdir p, @readImportSettings

    # Stop all importers.
    stop: =>
        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "stop"

        # Stop all jobs and reset `jobs` array.
        clearTimeout job.timer for job in @jobs
        @jobs = []
        @running = false

    # Force run importers for the specified entity.
    run: (entity) =>
        expresser.logger.debug "ImportManager", "run", entity

        for job in @jobs
            job.run() if job.importer.entity is entity


    # INTERNAL METHODS
    # ----------------------------------------------------------------------

    # Read each import settings.
    readImportSettings: (err, files) =>
        if err?
            return expresser.logger.error "ImportManager", "readImportSettings", err

        # Iterate all entities folder and search for import.json files.
        for f in files
            try
                basePath = path.join __dirname, "../entities/", f
                p = path.join basePath, "/import.json"

                # Only proceed if importers.json file exists.
                if fs.existsSync p
                    entity = path.basename basePath
                    @parseImporters entity, p
            catch ex
                expresser.logger.error "ImportManager", "readImportSettings", p, ex

    # Iterate and parse data from a import.json file.
    parseImporters: (entity, importPath) =>
        importers = fs.readFileSync importPath
        importers = JSON.parse importers

        # Read last status, if .status file is available.
        statusPath = importPath + ".status"
        if fs.existsSync statusPath
            statusJson = fs.readFileSync statusPath
            statusJson = JSON.parse statusJson

        for i in importers
            if expresser.settings.general.debug
                expresser.logger.info "ImportManager", "parseImporters", entity, i.id, i.type, i.mode, i.schedule

            schedule = i.schedule

            # Get importer type, or use the jsonImporter as default.
            importerType = i.type
            importerType = "json" if not importerType? or importerType is ""

            # Require specified importer.
            try
                ImporterClass = require "./importers/#{importerType.toLowerCase()}Importer.coffee"
                importer = new ImporterClass()
            catch ex
                return expresser.logger.error "ImportManager", "parseImporters", "Could not instantiate #{importerType} importer.", ex

            # Get importer options and schedule.
            importer.options = i
            importer.entity = entity
            importer.schema = require "../entities/#{entity}/schema.json"
            importer.setDefaults()

            # Check if schedule is set and importer is enabled before adding to `jobs`.
            if not schedule?
                problem = "Skipping #{entity} - #{i.id}: schedule was not set for importer."
                expresser.logger.warn "ImportManager", "parseImports", problem
            else if schedule < 5
                problem = "Skipping #{entity} - #{i.id}: schedule interval is too low (less than 5 seconds)."
                expresser.logger.warn "ImportManager", "parseImports", problem
            else if i.disabled or i.disabled > 0
                problem = "Skipping #{entity} - #{i.id}: option 'disabled' is true."
                expresser.logger.warn "ImportManager", "parseImports", problem
            else
                problem = null

            # Check if there's a previous status for this importer.
            status = lodash.find(statusJson, {id: i.id})
            if status?
                status = status.status
                importer.startTime = moment status.startTime
                importer.endTime = moment status.endTime
                importer.results = status.results
                importer.errors = status.errors

            # Create the job object.
            job = {}
            job.importer = importer
            job.jsonPath = importPath
            job.timer = null

            # Proceed with run only if no problems were found.
            if not problem?
                @setNextRun job

                # Create helper function to run importer and save info on the `import.json` file.
                job.run = =>
                    try
                        importer.run()
                        importer.onFinish = => @jobOnFinish job
                        @setNextRun job
                    catch ex
                        importer.errors.push ex

                # Create job timer.
                @setTimer job

                # Run the importer straight away if `runOnStart` is true.
                job.run() if i.runOnStart

            # Otherwise set problem.
            else
                job.problem = problem

            @jobs.push job

    # Helper to get the job timer based on its `schedule`.
    # This will also save the job results to the `import.json` file.
    setTimer: (job) =>
        timeout = job.nextRun.valueOf() - moment().valueOf()
        clearTimeout job.timer if job.timer?
        job.timer = setTimeout job.run, timeout

    # Set the job's `nextRun` property.
    # If `schedule` is not an array then just parse its int value.
    # Otherwise get the next scheduled run from the `schedule` times array.
    setNextRun: (job) =>
        importer = job.importer
        options = importer.options

        if not lodash.isArray options.schedule
            if importer.startTime.year() > 1970
                job.nextRun = moment(importer.startTime).add("s", options.schedule)
            else
                job.nextRun = moment().add("s", options.schedule)
        else
            now = moment()
            minTime = "99:99:99"
            nextTime = "99:99:99"

            # Get the next and minimum times.
            for sc in options.schedule
                minTime = sc if sc < minTime
                nextTime = sc if sc < nextTime and sc > now.format("HH:mm:ss")

            # If no times were found for today then set for tomorrow, minimum time.
            if nextTime is "99:99:99"
                now = now.add "d", 1
                nextTime = minTime

            # Set the `nextRun` based on next time.
            arr = nextTime.split ":"
            dateValue = [now.year(), now.month(), now.date(), parseInt(arr[0]), parseInt(arr[1]), parseInt(arr[2])]
            job.nextRun = moment dateValue

        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "setNextRun", importer.entity, options.id, job.nextRun.format("llll")

    # Reset the job timer and save the results of a importer after its `run` method was called.
    jobOnFinish: (job) =>
        @setTimer job

        statusPath = job.jsonPath + ".status"
        importer = job.importer
        id = importer.options.id

        # Create `status` object with results to be written to the status file.
        status =
            startTime: importer.startTime
            endTime: importer.endTime
            results: importer.results
            errors: importer.errors

        # Read import.json.status file (if it exists) and then save the results.
        fs.exists statusPath, (exists) =>
            if exists
                fs.readFile statusPath, {encoding: "utf8"}, (err, data) =>
                    if err?
                        expresser.logger.error "ImportManager", "jobOnFinish", importer.entity, id, err
                        return

                    statusJson = JSON.parse data
                    lodash.find(statusJson, {id: id}).status = status
                    @saveStatusFile job, statusJson
            else
                statusJson = []
                statusJson.push {id: id, status: status}
                @saveStatusFile job, statusJson

        if expresser.settings.general.debug
            expresser.logger.info "ImportManager", "jobOnFinish", importer.entity, id, "#{importer.errors.length} errors."

    # Save results, times and errors to the `import.json.results` file.
    saveStatusFile: (job, statusJson) =>
        statusPath = job.jsonPath + ".status"
        importer = job.importer
        id = importer.options.id

        # Make sure the `statusJson` is properly set.
        if not statusJson?
            expresser.logger.error "ImportManager", "saveStatusFile", importer.entity, id, "statusJson is invalid!"
            return

        # Save import.json.status file.
        fs.writeFile statusPath, JSON.stringify(statusJson, null, 4), (err) ->
            if err?
                expresser.logger.error "ImportManager", "saveStatusFile", importer.entity, id, err
            else if expresser.settings.general.debug
                expresser.logger.info "ImportManager", "saveStatusFile", importer.entity, id


# EXPORTS
# --------------------------------------------------------------------------
ImportManager.getInstance = ->
    @instance = new ImportManager() if not @instance?
    return @instance

module.exports = exports = ImportManager.getInstance()