# BASE IMPORTER
# --------------------------------------------------------------------------
# Base Importer class.

class BaseImporter

    # Required modules.
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

    # Start the importer. An `options` object must be passed, and the
    # method `transform` must be set on the importer class.
    run: =>
        if not @entity? or not @schema?
            return @error "Importer entity and schema must be set before running!"

        if not @options? or @options is ""
            return @error "Importer options must be set before running!"

        if not @transform? or not lodash.isFunction @transform
            return @error "Importer 'transform' must be a function."

        @options = options

        # User might use URL instead of URI.
        @options.uri = @options.url if @options.url? and not @options.uri?

        # Set the SolrManager to use the passed entity.
        solrManager = new (require "solrManager.coffee")(@entity)
        solrClient = solrManager.createClient()

        # Set start time.
        @startTime = moment()

        # Check if a `preRun` is set on the importer.
        if @preRun?
            @preRun @preRunCallback
        else
            @preRunCallback null, null

    # Helper to fetch a local or remote file. This will be called ONLY if the
    # importer doesn't implement a `fetch` method.
    smartFetch: (uri) =>
        if not @options.uri?
            return @error "URI or URL was not specified."

        # If URI is a remote file, get data using the `request` module.
        # Otherwise assume a local file and read from the file system.
        if @options.uri.substring(0, 7) is "http://" or @options.uri.substring(0, 4) is "wwww."
            request @options.uri, @options.headers, (err, res, result) =>
        else



    # CALLBACKS
    # ----------------------------------------------------------------------

    # Callback to the `preRun` method.
    preRunCallback: (err, data) =>
        if err?
            return @error err

        @fetch @fetchCallback

    # Callback for the `fetch` method.
    fetchCallback: (err, data) =>
        if err?
            return @error err

        # If data was passed, set it as the `rawData`.
        @rawData = data if data?

        # Transform the data.
        @transform @transformCallback

    # Callback for the `transform` method.
    transformCallback: (err, data) =>
        if err?
            return @error err

        # If import mode is full, wipe contents before proceeding.
        @wipe() if @options.mode is "full"

        # If data was passed, set it as the `processedData`.
        @processedData = data if data?

        # Process the transformed data.
        @process()

    # Process the transformed data collection.
    process: =>
        @processItem item for item in @processedData

    # Process each transformed item.
    processItem: (item) =>
        @setSearchField item

    # HELPERS
    # ----------------------------------------------------------------------

    # On error log to the console and check for custom error actions.
    error: (err) =>
        @onError err if @onError?

    # Set search field on Solr.
    setSearchField: (item) =>
        sf = []
        lodash.each data, (value, key) ->
            return unless value
            value = value.join(" ") if typeof value is typeof []
            value = value.split("-").join(" ") if key is "id"
            sf.push value if value
        item["search-s"] = sf.join " "


    # INTERNAL HELPERS
    # ----------------------------------------------------------------------

    # Wipe the entity data from the Solr database.
    wipe: =>
        console.warn "Wipe data from Solr..."


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = BaseImporter