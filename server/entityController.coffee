###
# EntityController.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

_       = require 'lodash'
im      = require "imagemagick"
os      = require "os"
fs      = require 'fs'
async   = require 'async'
easyxml = require 'easyxml'

# Facet Manager. distincts() gets a list of unique facet values.
FacetManager = require './facetManager.coffee'
facetManager = new FacetManager

# Solr Manager handles property suffixes (i.e. adding -s for string fields).
SolrManager = require './solrManager.coffee'
solrManager = new SolrManager

# Schema class provides methos to handle schemas easily.
Schema = require './schema'

# Server and default entity settings
settings = require "#{__dirname}/../server.settings.coffee"

# List of available entities
entities = require "#{__dirname}/../entities.json"


class EntityController

    module.exports = EntityController

    # Entity routes
    constructor: (app, auth, entities) ->
        app.get   '/:entity/schema',          auth, (a...) => @schema     a...
        app.get   '/:entity/settings',        auth, (a...) => @settings   a...
        app.get   '/:entity/collection',      auth, (a...) => @collection a...
        app.get   '/:entity/pane.json',             (a...) => @pane       a...
        app.get   '/:entity/ufacets',         auth, (a...) => @ufacets    a...
        app.post  '/:entity/picture',         auth, (a...) => @picture    a...
        app.get   '/:entity/template',        auth, (a...) => @template   a...

    # Return appropriate schema for each entity
    schema: (req, res) ->
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1
        schema = require "#{__direname}/../entities/#{entity}/schema.json"
        res.send schema

    # Return appropriate settings for each entity
    settings: (req, res) =>
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1
        settings = require "#{__dirname}/../entities/#{entity}/settings.json"
        @getEntities () ->
            settings.entities = entities
            res.send settings

    # Return a collection based on the filter parameters.
    collection: (req, res) =>
        entity = req.params.entity
        return res.send 404 unless @isEntity(entity)
        @createQuery req, (query, db) =>
            @setFacets req, query if req.query["facet.field"]
            @setFilters req, query if req.query?.fs
            @getCollection db, query, (result) =>
                @setClinkItems entity, result, (result) =>
                    @setCollectionResponse req, res, result, (result) =>
                        res.send result

    # Returns pane.json, containing extra data for custom panes.
    pane: (req, res) ->
        file = "#{__dirname}/../entities/#{req.params.entity}/pane.json"
        res.setHeader 'Content-Type', 'application/json'
        fs.readFile file, "utf8", (err, data) =>
            return res.send {} if err
            res.send data

    # Get unique values from all the facet fields. Useful for autocomplete.
    ufacets: (req, res) =>
        facetManager.distincts req.params.entity, (d) =>
            res.send d

    # Picture uploader. Save picture on tmp location, convert, manipulate and
    # move to storage location. Respond with an array of properties from the
    # uploaded image. Useful for backbone.
    picture: (req, res) =>
        entity = req.params.entity
        upload_id = req.files.picture.path
        target_filename = upload_id + '.jpg'
        target_path= "public/images/#{entity}/archive/"
        target_file = target_path + target_filename
        tmp_file = 'public/images/tmp/' + target_filename
        url_file = "/images/tmp/" + target_filename
        response = [ name: target_filename, url: url_file, type: "image/jpeg" ]
        im_params =  [
            "#{target_file}", '-thumbnail', '300x300^', '-gravity', 'center',
            '-extent', '300x300', 'public/images/tmp/' + target_filename
        ]

        fs.rename upload_id, target_file, (err) ->
            throw err if err
            im.convert im_params, (err, stdout, stderr) ->
                throw err if err
                fs.stat tmp_file, (err, stats) ->
                    throw err if err
                    response.push size: stats.size
                    res.send response

    # Return templates from an entity
    template: (req, res) ->
        res.render "../entities/#{req.params.entity}/templates"

    # Run query and return either CSV, JSON or XML
    getCollection: (db, query, cb) =>
        db.search query, (err, result) =>
            docs = []
            return cb(docs) unless result and result.response
            _.each result.response?.docs, (doc) ->
                docs.push solrManager.removeSuffix doc
            result.response?.docs = docs
            cb result

    # Return all available entities with its settings
    getEntities: (cb) =>
        es = {}
        _.each entities, (e) =>
            settings = require "#{__dirname}/../entities/#{e}/settings.json"
            es[entity] = settings
        cb es


    # Get the sort parameter. If its not specified on QS, the default value
    # is specified in the settings file.
    getSort: (req, cb) =>
        entity = req.params.entity
        solrManager = new SolrManager entity
        settings = require "#{__dirname}/../entities/#{entity}/settings.json"
        sorts = {}

        sort = if req.query.sort then req.query.sort else settings.sort
        _.each sort.split(','), (sort) =>
            [ id, order ] = sort.split ':'
            if sort.split(':').length is 3
                [id1, id2, order] = sort.split ':'
                id = "#{id1}:#{id2}"
            field = solrManager.schema.getFieldById id

            # Solr can't sort multivalue fields. There is a stringified copy
            # of each mv field with the suffix -sort appended to its id.
            if @isMultivalue field then id = "#{id}-sort"
            else id = solrManager.addSuffix id

            sorts[id] = order
        cb sorts

    # Returns a new a solr query object ready to perfom searches on the
    # requested entity's collection.
    createQuery: (req, cb) =>
        entity = req.params.entity
        settings = require "#{__dirname}/../entities/#{entity}/settings.json"
        q = if req.query.q then "#{req.query.q}*" else "*:*"
        rows =  req.query.rows or settings.rows
        start = rows*req.query.page || 0
        @getSort req, (sort) =>
            solrManager = new SolrManager entity
            db = solrManager.createClient()
            query = db.createQuery()
                .q(q)
                .sort(sort)
                .defType("edismax")
                .pf(@getSearchableFields(entity))
                .qf(@getSearchableFields(entity))
                .start(start)
                .rows(rows)
                .facet on: yes, missing: yes, mincount: 1

            # Temporarily replacing solr-client's matchFilter method since
            # its not meeting our requirements.
            query.matchFilter = solrManager.customMatchFilter

            cb query, db

    # Set response of a collection request, depending on the format asked.
    setCollectionResponse: (req, res, result, cb) =>
        return @responseJson res, result, cb if req.query.json
        return @responseXml res, result, cb if req.query.xml
        return @responseCSV req.params.entity, res, result, cb if req.query.csv
        cb result


    responseJson: (res, result, cb) =>
        res.setHeader 'Content-Type', 'application/json'
        result = result.response?.docs
        cb result


    responseCSV: (entity, res, result, cb) =>
        res.setHeader 'Content-Type', 'text/plain; charset=utf8'
        @toCSV entity, result, (csv) =>
            cb csv


    responseXml: (res, result, cb) =>

        easyxml.configure
            singularizeChildren: yes
            underscoreAttributes: yes
            rootElement: 'response'
            dateFormat: 'ISO'
            indent: 2
            manifest: yes

        res.setHeader 'Content-Type', 'text/xml'

        # Replace tuple field character for xml compatibility
        docs = []
        _.each result.response.docs, (doc) ->
            d = {}
            _.each doc, (value, property) ->
                d[property.replace(':', '-')] = value
            docs.push d
        result = easyxml.render item: docs
        cb result


    # Adds fields that are of facet type to the query so that the faceted
    # response includes them.
    setFacets: (req, query) =>
        entity = req.params.entity
        solrManager = new SolrManager entity
        facetFilter = req.query["facet.field"]
        facetFilter = [ facetFilter ] if typeof facetFilter is "string"
        _.each facetFilter, (f) ->
            fieldParam = solrManager.addSuffix f
            query.facet field: "{!ex=_#{fieldParam}}#{fieldParam}"

    # Adds filter parameters to a query. i.e. facet filters or search terms.
    setFilters: (req, query) =>

        entity = req.params.entity
        solrManager = new SolrManager entity
        fqFields = {}
        fq = req.query.fs

        # Handle an array of facet filters
        if typeof fq is typeof []
            _.each fq, (fq) ->
                [ filter, value ] = fq.split ':'
                filter = solrManager.addSuffix filter

                fqFields[filter] = [] unless fqFields[filter]
                fqFields[filter].push value
            _.each fqFields, (fields, f) ->
                query.matchFilter f, fields
            return

        [ filter, value ] = fq.split(':')
        filter = solrManager.addSuffix filter

        query.matchFilter filter, [ value ]

    # Gets a list of IDs and an entity and fetches all items from the
    # entity's collection, replacing the IDs for full objects.
    setClinkItems: (entity, result, cb) =>
        return cb result unless result.response?.docs?.length
        solrManager = new SolrManager entity
        docs = result.response.docs
        async.each docs, (d, _cb) =>
            fields = solrManager.schema.getFieldsByType 'clink'
            return _cb() unless fields.length
            _.each fields, (field) =>
                return _cb() unless d[field.id]
                _solrManager = new SolrManager field.entity
                _solrManager.getItemById "(#{d[field.id].join(' ')})", (items) =>
                    d[field.id] =  items
                    _cb()
        , (err) =>
            throw err if err
            cb result


    # Return all fields specified as "searchable" (search: true) on the schema.
    getSearchableFields: (entity) =>
        solrManager = new SolrManager entity
        searchables = solrManager.schema.getFieldsByProp 'search'
        fields = {}
        _.each searchables, (f) =>
            return fields["#{f.id}-sort"] = 1 if @isMultivalue f
            fields[solrManager.addSuffix(f.id)] = 1 if f.search
        return fields


    # Checks if the requested resource is one of the available entities
    isEntity: (entity) =>
        return yes unless entities.indexOf(entity) is -1
        return no

    # Checks if the requested field is multivalue. Facet and tuple fields are
    # multivalue by definition.
    isMultivalue: (field) =>
        return yes if field.multivalue
        return yes if field.type is 'facet' or field.type is 'tuple'
        return yes if field.type is 'clink'
        return no

    # Converts a json array into a csv file
    toCSV: (entity, res, cb) ->

        str = ''
        del = ','
        headers = []

        schema = require "../entities/#{entity}/schema.json"

        _.each schema, (f) ->
            headers.push f.id

        str += headers.join del

        _.each res.response?.docs, (item) ->
            line = ''
            _.each headers, (header) ->
                line += del if line
                line += JSON.stringify item[header] if item[header]
            line = line.replace /\\"/g, '""'
            str += os.EOL + line
        cb str
