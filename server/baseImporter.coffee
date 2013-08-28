# BASE IMPORTER
# --------------------------------------------------------------------------
# Base Importer class.

class BaseImporter

    # Required modules.
    expresser = require "expresser"
    fs = require "fs"
    lodash = require "lodash"
    moment = require "moment"
    request = require "request"
    solr = require "solr-client"
    solrManager = null
    solrClient = null


    # PROPERTIES
    # ----------------------------------------------------------------------

    # The entity and schema will be set automatically on `run`.
    entity: null
    schema: null

    # Options must be set manually before calling `run`.
    options: null

    # The raw and processed values will be set on each importer.
    rawData: null
    processedData: null

    # Runs before anything else.
    preRun: null
    # Fetch the remote data.
    fetch: null
    # Transform fetched data and set the `processedData` property.
    transform: null
    # Runs after import is done.
    postRun: null

    # These are session related properties to track job status.
    startTime: null
    endTime: null
    lastSync: null


    # MAIN METHODS
    # ----------------------------------------------------------------------

    # Start the importer. An `options` object can be passed (optional).
    run: (options) =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "run", options

        if options? and options isnt false and options isnt ""
            @options = options

        if not @options? or @options is ""
            return @error "Importer options must be set before running!"

        if not @entity? or not @schema?
            return @error "Importer entity and schema must be set before running!"

        if not @transform? or not lodash.isFunction @transform
            return @error "Importer 'transform' must be a function."

        # User might use URL instead of URI.
        @options.uri = @options.url if @options.url? and not @options.uri?

        # If no fetch is set on the importer, use `smartFetch`.
        if not @fetch? or @fetch is false
            @fetch = @smartFetch
            if expresser.settings.general.debug
                expresser.logger.info "BaseImporter", "run", "Using smartFetch (fetch is not defined)."

        # Set the SolrManager to use the passed entity.
        solrManager = new (require "./solrManager.coffee")(@entity)
        solrClient = solrManager.createClient()

        # Set start time.
        @startTime = moment()

        # Check if a `preRun` is set on the importer.
        if @preRun?
            @preRun @preRunCallback
        else
            @preRunCallback()

    # Helper to fetch a local or remote file. This will be called ONLY if the
    # importer doesn't implement a `fetch` method.
    smartFetch: (callback) =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "smartFetch"

        if not @options.uri?
            return @error "URI or URL was not specified."

        # If URI is a remote file, get data using the `request` module.
        # Otherwise assume a local file and read from the file system.
        if @options.uri.substring(0, 7) is "http://" or @options.uri.substring(0, 4) is "www."
            request @options.uri, @options.headers, (err, res, data) => callback err, data
        else
            fs.readFile @options.uri, (err, data) => callback err, data


    # CALLBACKS
    # ----------------------------------------------------------------------

    # Callback to the `preRun` method.
    preRunCallback: (err, data) =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "preRunCallback"

        return @error err if err?

        @fetch @fetchCallback

    # Callback for the `fetch` method.
    fetchCallback: (err, data) =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "fetchCallback"

        return @error err if err?

        # If data was passed, set it as the `rawData`.
        @rawData = data if data?

        if expresser.settings.general.debug
            rawLength = lodash.size @rawData
            expresser.logger.info "BaseImporter", "fetchCallback", "Raw data length: #{rawLength}"

        # Transform the data.
        @transform @transformCallback

    # Callback for the `transform` method.
    transformCallback: (err, data) =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "transformCallback"

        return @error err if err?

        # If import mode is full, wipe contents before proceeding.
        @wipe() if @options.mode is "full"

        # If data was passed, set it as the `processedData`.
        @processedData = data if data?

        # Make sure the `processedData` is an array.
        if lodash.isString @processedData
            @processedData = expresser.utils.minifyJson @processedData
            @processedData = JSON.parse @processedData

        # Make sure result is an array.
        if not lodash.isArray @processedData
            @processedData = [@processedData]

        # Process the transformed data.
        @process()

    # Process the transformed data collection.
    process: =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "process", @processedData

        # Process each item of `processedData`.
        @processItem item for item in @processedData

    # Process each transformed item. This will check for the field mapping (fields property)
    # and properly create a new item with the referenced keys and values.
    processItem: (item) =>
        if @options.fields?
            newItem = {}
            for sourceKey, targetKey of @options.fields
                newItem[sourceKey] = item[targetKey]
        else
            newItem = item

        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "processItem", newItem

        # Set search field and add item to Solr.
        newItem = solrManager.addObjSuffix @entity, newItem
        setSearchField newItem
        solrClient.add newItem


    # HELPERS
    # ----------------------------------------------------------------------

    # On error log to the console and check for custom error actions.
    error: (err) =>
        expresser.logger.error "Importer", @options.type, @entity, err
        @onError err if @onError?

    # Wipe the entity data from the Solr database.
    wipe: =>
        if expresser.settings.general.debug
            expresser.logger.info "BaseImporter", "wipe"

        query = solrClient.createQuery().q("*:*").start(0).rows 9999999

        solrClient.deleteByQuery "*:*", (err, result) ->
            if expresser.settings.general.debug
                if err?
                    expresser.logger.error "BaseImporter", "wipe", @entity, err
                else
                    expresser.logger.info "BaseImporter", "wipe", @entity, "OK"
            return @error err if err?


    # INTERNAL IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Set search field on Solr.
    setSearchField = (item) ->
        sf = []
        lodash.each item, (value, key) ->
            return unless value
            value = value.join(" ") if typeof value is typeof []
            value = value.split("-").join(" ") if key is "id"
            sf.push value if value
        item["search-s"] = sf.join " "


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = BaseImporter