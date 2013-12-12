# BASE IMPORTER
# --------------------------------------------------------------------------
# Base Importer class.

class BaseImporter

    # Required modules.
    async = require "async"
    expresser = require "expresser"
    fs = require "fs"
    lodash = require "lodash"
    moment = require "moment"
    request = require "request"


    # PROPERTIES
    # ----------------------------------------------------------------------

    # SolrManager will be created during `run`.
    solrManager: null

    # The entity and schema will be set automatically on `run`.
    entity: null
    schema: null

    # Options must be set manually before calling `run`.
    options: null

    # Runs before anything else.
    preRun: null
    # Fetch the remote data.
    fetch: null
    # Transform fetched data and set the `processedData` property.
    transform: null
    # Runs after import is done.
    postRun: null

    # The raw and processed data must set on each importer.
    # The items to add, update and to delete are set by the `process` method.
    rawData: null
    processedData: null
    itemsToUpdate: null
    itemsToDelete: null

    # These are session related properties to track job status.
    startTime: moment 0
    endTime: moment 0

    # Holds all result and error messages triggered during import.
    results: []
    errors: []

    # The `onFinish` is set automatically on the ImportManager.
    onFinish: null


    # MAIN METHODS
    # ----------------------------------------------------------------------

    # Helper to set default values.
    # Make sure mode is correctly set. Default is `full`.
    # Make sure uri is used instead of url.
    # If no fetch is set on the importer, use `smartFetch`.
    setDefaults: =>
        @options.mode = "full" if not @options.mode? or @options.mode is ""
        @options.mode = @options.mode.toLowerCase()
        @options.uri = @options.url if @options.url? and not @options.uri?
        @options.updateKey = "id" if @options.mode is "update" and (not @options.updateKey? or @options.updateKey is "")

        @fetch = @smartFetch if not @fetch? or @fetch is false

        @solrManager = new (require "./solrManager.coffee")(@entity) if not @solrManager? and @entity?

    # Start the importer. An `options` object can be passed (optional) to override the default options,
    # which is usually taken from the `import.json` file for the specified entity.
    run: (options) =>
        @rawData = null
        @processedData = null
        @itemsToUpdate = []
        @itemsToDelete = []

        # Reset errors and results on each run.
        @errors = []
        @results = []

        # If options was passed, override the default options.
        if options? and options isnt false and options isnt ""
            @options = options

        # Make sure options were set.
        if not @options? or @options is ""
            return @error "run", "Importer options must be set before running. Abort!"

        # Make sure an ID was specified.
        if not @options.id? or @options.id is ""
            return @error "run", "Importer ID was not set. Abort!"

        # Make sure `entity` and `schema` are set.
        if not @entity? or @entity is "" or not @schema? or @schema is ""
            return @error "run", "Importer entity and schema must be set before running. Abort!"

        if expresser.settings.general.debug
            if options?
                @log "run", "Overriding options"
            else
                @log "run"

        # Set start and end time.
        @startTime = moment()
        @endTime = moment()

        # Check if a `preRun` is set on the importer.
        if @preRun?
            @preRun @preRunCallback
        else
            @preRunCallback()

    # Helper to fetch a local or remote file, with optional child requests if a `uriChild` is specified.
    # This will be called ONLY if the running importer doesn't implement a `fetch` method.
    smartFetch: (callback) =>
        if expresser.settings.general.debug
            @log "smartFetch"

        if not @options.uri?
            return @error "URI or URL was not specified."

        # Request the main URI and check if child data should be requested as well.
        @smartRequest @options.uri, (err, data) =>
            if @options.childUri? and @options.childUri isnt ""
                data = JSON.parse data
                mergedData = []

                # Set the child callback to merge data.
                childCallback = (child, cb) =>
                    parentId = (if @options.parentKey then child[@options.parentKey] else child)
                    childUri = @options.childUri.replace("[[parent]]", parentId)

                    @smartRequest childUri, (errChild, childData) =>
                        if errChild?
                            if @options.continueOnError
                                cb()
                                @error "smartFetch", errChild, true
                            else
                                cb errChild
                        else
                            childData = JSON.parse childData
                            mergedData = mergedData.concat childData
                            cb()

                async.eachSeries data, childCallback, (errAsync) => callback errAsync, mergedData
            else
                callback err, data

    # Helper to fetch a local or remote file. This will be called ONLY if the running
    # importer doesn't implement a `fetch` method. Might get called multiple times to request
    # child data in case options have `childUri` and `childKey` set.
    smartRequest: (uri, callback) =>
        if expresser.settings.general.debug
            @log "smartRequest", uri

        headers = @options.headers

        try
            # If `header` is a path, load it.
            headers = require headers if headers? and lodash.isString headers
            auth = headers.auth if headers?.auth?

            # Make sure headers `auth` is properly set in case user misplaced user/password.
            if headers?.user? and headers?.password? and not headers?.auth?
                auth = {user: headers.user, password: headers.password, sendImmediately: false}
                delete headers["user"]
                delete headers["password"]

            # Remote location, use the `request` module if it has http:// or www.
            if uri.substring(0, 7) is "http://" or uri.substring(0, 4) is "www."
                request {uri: uri, headers: headers, auth: auth}, (err, res, data) ->
                    err = "Invalid status code #{res.statusCode} from #{uri}." if res.statusCode < 200 or res.statusCode > 399
                    callback err, data
            # Otherwise read from local path using the `fs` module.
            else
                fs.exists uri, (exists) ->
                    if exists
                        fs.readFile uri, {encoding: "utf8"},  (err, data) -> callback err, data
                    else
                        callback "File #{uri} does not exist!"

        # Catch errors.
        catch ex
            @error "smartRequest", ex
            if not @options.continueOnError
                @onFinish() if @onFinish?
                return false

    # Process the transformed data collection.
    process: =>
        if expresser.settings.general.debug
            @log "process", "Processing #{lodash.size(@processedData)} docs."

        # If import mode is full, wipe contents before proceeding.
        @wipe() if @options.mode is "full"

        # Get docs to update, based on the `itemsToUpdate` option or
        # if not present use everything from the `processedData`.
        if @options.itemsToUpdate? and @options.itemsToUpdate isnt ""
            @itemsToUpdate = @processedData[@options.itemsToUpdate]
        else
            @itemsToUpdate = @processedData

        # Get docs to delete, based on the `itemsToDelete` option.
        if @options.itemsToDelete? and @options.itemsToDelete isnt ""
            @itemsToDelete = @processedData[@options.itemsToDelete]

        # Process each item of `itemsToUpdate`.
        try
            lodash.each @itemsToUpdate, (item) => @updateItem item
            lodash.each @itemsToDelete, (item) => @deleteItem item
        catch ex
            @error "process", ex
            if not @options.continueOnError
                @processCallback ex, @processedData
                return false

        @processCallback null, @processedData

    # Process each transformed item to be updated. This will check for the field mapping (fields property)
    # and properly create a new item with the referenced keys and values.
    updateItem: (item) =>
        if expresser.settings.general.debug
            @log "updateItem", item

        # Check if item is array and no `fields` were set. In this case, call recursively
        # to update each of this array's elements.
        if item.length > 0 and not @options.fields?
            if expresser.settings.general.debug
                @log "updateItem", "Ttem is array(#{item.length})! Call recursively."
            lodash.each item, (subItem) => @updateItem subItem
            return

        # Create `processedItem` and iterate fields to build it.
        processedItem = {}

        if @options.fields?
            for sourceKey, targetKey of @options.fields
                processedItem[sourceKey] = @getItemProperty item, sourceKey, targetKey
        else
            for schemaField in @schema
                if item[schemaField.id]?
                    processedItem[schemaField.id] = @getItemProperty item, schemaField.id, schemaField.id

        # If `mode` is update, try finding an existing item first.
        if @options.mode is "update"
            @solrManager.getItemsByProp @options.updateKey, processedItem[@options.updateKey], (err, items) =>

                # Found multiple items, so throw error and end item processing here.
                if items.length > 1
                    @error "updateItem", "Multiple items found for #{@options.updateKey} = #{processedItem[@options.updateKey]}"
                    return false
                # Existing member, extend its properties.
                else if items.length is 1
                    lodash.defaults processedItem, items[0]



                # Update item on Solr.
                @solrManager.addItems processedItem, (err2, data) => @error("updateItem", err2) if err2?

        # Mode is `full` so add to Solr without searching first.
        else
            @solrManager.addItems processedItem, (err, data) => @error("updateItem", err) if err?

    # Delete the specified item.
    deleteItem: (item) =>
        if expresser.settings.general.debug
            @log "deleteItem", item

        # Check if item is array and no `fields` were set. In this case, call recursively
        # to delete each of this array's elements.
        if item.length > 0 and not @options.fields?
            if expresser.settings.general.debug
                @log "updateItem", "Ttem is array(#{item.length})! Call recursively."
            lodash.each item, (subItem) => @deleteItem subItem
            return

        # Delete item.
        @solrManager.client.deleteByID item.id, (err, data) => @error("deleteItem", err) if err?

    # Parse the original item data property to return the processed value. This is execute
    # for each schema field against items to be imported.
    getItemProperty: (item, sourceKey, targetKey) =>
        if isNaN targetKey
            t = targetKey
        else
            t = parseInt targetKey

        return item[t]


    # CALLBACKS
    # ----------------------------------------------------------------------

    # Callback to the `preRun` method.
    preRunCallback: (err, data) =>
        if err?
            @error "preRunCallback", err
            if not @options.continueOnError
                @onFinish() if @onFinish?
                return false
        else  if expresser.settings.general.debug
            @log "preRunCallback", "OK."

        @fetch @fetchCallback

    # Callback for the `fetch` method.
    fetchCallback: (err, data) =>
        if err?
            @error "fetchCallback", err
            if not @options.continueOnError
                @onFinish() if @onFinish?
                return false
        else if expresser.settings.general.debug
            @log "fetchCallback", "OK. Raw data length: #{lodash.size(data)}"

        # If data was passed, set it as the `rawData`.
        @rawData = data if data?

        # Transform the data.
        if @transform?
            @transform @transformCallback
        else
            @transformCallback null, @rawData

    # Callback for the `transform` method.
    transformCallback: (err, data) =>
        if err?
            @error "transformCallback", err
            if not @options.continueOnError
                @onFinish() if @onFinish?
                return false
        else if expresser.settings.general.debug
            @log "transformCallback", "OK. Processed data length: #{lodash.size(data)}"

        # If data was passed, set it as the `processedData`.
        @processedData = data if data?

        # If processed data is empty, stop straight away.
        if not @processedData? or @processedData is ""
            @processCallback "Property 'processedData' has no value. Abort!"

        # Make sure the `processedData` is JSON.
        if not lodash.isObject @processedData
            try
                @processedData = expresser.utils.minifyJson @processedData
                @processedData = JSON.parse @processedData
            catch ex
                @error "transformCallback", ex
                if not @options.continueOnError
                    @onFinish() if @onFinish?
                    return false

        # Make sure result is an array.
        if not lodash.isArray @processedData
            @processedData = [@processedData]

        # Process the transformed data.
        @process()

    # Callback for the `proccess` method.
    processCallback: (err, data) =>
        @endTime = moment()

        if err?
            @error "processCallback", err
            if not @options.continueOnError
                @onFinish() if @onFinish?
                return false
        else if expresser.settings.general.debug
            @log "processCallback", "OK. End time: #{@endTime.format("HH:mm:ss")}"

        # Push document count to results.
        documentCount = lodash.size @processedData
        @results.push documentCount

        # Finished: call `postRun` or proceed to `onFinish`.
        if @postRun?
            @postRun @onFinish
        else if @onFinish?
            @onFinish()


    # HELPERS
    # ----------------------------------------------------------------------

    # Main log helper.
    log: (method, arg) =>
        return

        if arg isnt undefined
            expresser.logger.info "Importer", method, @entity, @options.id, arg
        else
            expresser.logger.info "Importer", method, @entity, @options.id

    # On error log to the console and check for custom error actions.
    error: (method, err, doNotStop) =>
        if doNotStop
            expresser.logger.error "Importer", @entity, @options.id, "doNotStop", err
        else
            expresser.logger.error "Importer", @entity, @options.id, err

        @endTime = moment()

        @errors.push err
        @onError err if @onError?

    # Wipe the entity data from the Solr database.
    wipe: =>
        if expresser.settings.general.debug
            @log "wipe"
        @solrManager.purge()


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = BaseImporter