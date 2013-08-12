# BASE IMPORTER
# --------------------------------------------------------------------------
# Base Importer class.

class BaseImporter

    # Required modules.
    fs = require "fs"
    lodash = require "lodash"
    solr = require "solr-client"
    solrManager = null

    # These will be set in the constructor.
    entity = null
    solrClient = null

    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Options are passed on the constructor.
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


    # METHODS
    # ----------------------------------------------------------------------

    # Start the importer. An `options` object must be passed, and the
    # method `transform` must be set on the importer class.
    run: =>
        if not @options? or @options is ""
            return @error "Importer options must be set before running!"

        if not @transform? or not lodash.isFunction @transform
            return @error "Importer 'transform' must be a function."

        @options = options

        # Set the SolrManager to use the passed entity.
        solrManager = new (require "solrManager.coffee")(@entity)
        solrClient = solrManager.createClient()

        # Check if a `preRun` is set on the importer.
        if @preRun?
            @preRun @preRunCallback
        else
            @preRunCallback null, null

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

        # If import type is full, wipe contents before proceeding.
        @wipe() if @options.type is "full"

        # If data was passed, set it as the `processedData`.
        @processedData = data if data?

        # Process the transformed data.
        @process()

    # Process the transformed data.
    process: =>
        @processItem item for item in @processedData

    # Process each transformed item.
    processItem: =>

        
    # On error log to the console and check for custom error actions.
    error: (err) =>
        @onError err if @onError?


    # INTERNAL HELPERS
    # ----------------------------------------------------------------------

    # Wipe the entity data from the Solr database.
    wipe: =>
        console.warn "Wipe data from Solr..."


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = BaseImporter