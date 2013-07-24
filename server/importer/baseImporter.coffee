# SERVER DATABASE
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

    # The data URI and its raw/processed values will be set on each importer.
    dataUri: null
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
            @onError "Importer 'transform' must be a function."
            throw "You must pass the settings to the importer constructor!"

        solrManager = new (require "../solrManager.coffee")(options.entity)
        solrClient = solrManager.createClient()


    # METHODS
    # ----------------------------------------------------------------------

    # Start the importer.
    start: =>
        if not @transform? or not lodash.isFunction @transform
            @onError "Importer 'transform' must be a function."
            return

        if @preRun?
            @preRun @preRunCallback
        else
            @preRunCallback null, null

    # Callback to the `preRun` method.
    preRunCallback: (err, data) =>
        if err?
            @onError err if @onError?
            return

        @fetch @fetchCallback

    # Callback for the `fetch` method.
    fetchCallback: (err, data) =>
        if err?
            @onError err if @onError?
            return

        # If data was passed, set it as the `rawData`.
        @rawData = data if data?

        # Transform the data.
        @transform @transformCallback

    # Callback for the `transform` method.
    transformCallback: (err, data) =>
        if err?
            @onError err if @onError?
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
        if @settings.


    # INTERNAL HELPERS
    # ----------------------------------------------------------------------

    # Wipe the entity data from the Solr database.
    wipe: =>
        console.warn "Wipe data from Solr..."


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = BaseImporter