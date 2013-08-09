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
    settings = null
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


    # CONSTRUCTOR
    # ----------------------------------------------------------------------

    # Constructor must receive options (settings).
    constructor: (options) ->
        if not options? or options is ""
            @error "Importer 'transform' must be a function."
            throw "You must pass the settings to the importer constructor!"

        @options = options

        solrManager = new (require "solrManager.coffee")(options.entity)
        solrClient = solrManager.createClient()


    # METHODS
    # ----------------------------------------------------------------------

    # Start the importer.
    run: =>
        if not @transform? or not lodash.isFunction @transform
            @error "Importer 'transform' must be a function."
            return

        if @preRun?
            @preRun @preRunCallback
        else
            @preRunCallback null, null

    # Callback to the `preRun` method.
    preRunCallback: (err, data) =>
        if err?
            @error err
            return

        @fetch @fetchCallback

    # Callback for the `fetch` method.
    fetchCallback: (err, data) =>
        if err?
            @error err
            return

        # If data was passed, set it as the `rawData`.
        @rawData = data if data?

        # Transform the data.
        @transform @transformCallback

    # Callback for the `transform` method.
    transformCallback: (err, data) =>
        if err?
            @error err
            return

        # If import type is full, wipe contents before proceeding.
        @wipe() if @settings.type is "full"

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