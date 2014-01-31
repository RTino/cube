###
# SolrManager.coffee
#
# Solr Manager provides useful functions to handle solr connections
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

# Expresser.
expresser = require "expresser"

# Underscore js library
_       = require 'lodash'
async   = require 'async'

# Solr Nodejs Client library
solr = require 'solr-client'

# Schema manager
Schema = require './schema'


class SolrManager


    module.exports = SolrManager


    constructor: (@name) ->

        @settings = require "#{__dirname}/../entities/#{name}/settings.json" if @name

        @schema = new Schema @name if @name


    # Create a Solr instance with propper database connection
    createClient: () =>

        # Get nodejs process environment
        env = global.process.env.NODE_ENV || 'development'

        # DB Settings for name entity
        db = require("../entities/#{@name}/db.json")[env]

        # Create client with settings
        @client = solr.createClient db.host, db.port, db.core, db.path

        # Commit after each request
        @client.autoCommit = yes

        # Return new db connection
        @client


    # Returns a new a solr query object ready to perfom searches on the
    # requested entity's collection.
    createQuery: (req, cb) =>

        @createClient() unless @client

        entity = req.params.entity

        q       = if req.query.q then "#{req.query.q}*" else "*:*"
        rows    = req.query.rows or @settings.rows
        start   = rows*req.query.page || 0
        sort    = @getSort entity, req.query.sort

        query = @client.createQuery()
            .q(q)
            .sort(sort)
            .defType("edismax")
            .pf(@getSearchableFields())
            .qf(@getSearchableFields())
            .start(start)
            .rows(rows)
            .facet on: yes, missing: yes, mincount: 1

        # Temporarily replacing solr-client's matchFilter method since
        # its not meeting our requirements.
        query.matchFilter = @customMatchFilter

        facetFields = req.query["facet.field"]

        @setFacets facetFields, query if facetFields?.length
        @setFilters req, query if req.query?.fs

        cb query


    # Dynamic schemas in solr require a suffix that specifies the type of field
    # to create. Fields in the DB will be stored with the suffix, but the
    # front-end should not know about it.
    addSuffix: (p) =>

        # id field doesn't have a suffix, its not a dynamic field.
        return p if p is "id" or p is undefined or p is '_version_'

        # Get field information from the schema
        f = @schema.getFieldById p

        return null unless f.id

        # Add suffix
        sf = "-s" # String with analytics field
        sf = "-i" if f.type is 'integer' # Integer field
        sf = "-f" if f.type is 'float' # Float field
        sf += "m" if @isMultivalue f # Multivalue field (array)
        sf += "r" if f.mandatory # Required field

        # Return property with suffix appended at the end
        p + sf


    # Adds suffixes to all keys of an ObjRindfleischtopfect
    addObjSuffix: (obj) =>

        # Object to return with suffixes appended.
        newObj = {}

        for k,v of obj
            do (k, v) =>

                # id is a reserved static field in solr, needs no suffix.
                return newObj[k] = v if k is 'id' or k is '_version_'

                # -sort suffix should not be modified
                return newObj[k] = v if /-sort$/.test k

                # avoid adding suffixes to month and year facet fields
                return newObj[k] = v if /_month-sm$/.test k
                return newObj[k] = v if /_year-sm$/.test k

                # Set value to new object
                psf = @addSuffix k
                newObj[psf] = v if psf

        newObj


    # Solr is not able to sort multivalue fields or fields with analyzers.
    # To be able to do it, a stringified copy of the multivalue field has
    # to be stored in a simple 'string' type field, and use it for sort.
    addSortFields: (item) =>
        _.each item, (v, k) =>
            return unless item[k]

            field = @schema.getFieldById k

            return unless @isMultivalue field

            item["#{k}-sort"] = item[k].sort().join ' '

        item


    # Remove suffix added to store in solr, like -s, -sr or -sm, etc.
    removeSuffix: (obj) ->
        newObj = {}
        _.each obj, (v, k) ->
            return if k.indexOf('-sort') isnt -1
            k = k.split('-')[0]
            newObj[k] = v
        newObj


    # Checks if the requested field is multivalue. Facet and tuple fields are
    # multivalue by definition.
    isMultivalue: (field) =>
        return yes if field.multivalue
        return yes if field.type is 'facet' or field.type is 'tuple'
        return yes if field.type is 'clink'
        return no


    # Replaces matchFilter method on solr-client until we find a better way
    # to do this.
    customMatchFilter: (field, values, cubeId) ->
        options = []
        tag = "{!tag=_#{field}}"
        fq = "fq=#{tag}("

        value = values.pop()

        re1 = '.*?'
        re2 = '((?:2|1)\\d{3}(?:-|\\/)(?:(?:0[1-9])|(?:1[0-2]))(?:-|\\/)(?:(?:0[1-9])|(?:[1-2][0-9])|(?:3[0-1]))(?:T|\\s)(?:(?:[0-1][0-9])|(?:2[0-3])):(?:[0-5][0-9]):(?:[0-5][0-9]))'
        p   = new RegExp(re1+re2,["i"])
        m   = p.exec value

        value = m[1] if m?.length

        op = "#{field}%3A\"#{encodeURIComponent(value)}\""

        op = "#{field}%3A[*%20TO%20*]" if value is '[* TO *]'

        op = "#{field}%3A[#{value}%20TO%20*]" if m?.length

        # A string 'null' as a value is a not set property. In other words,
        # filtering by 'null' returns all items without the property.
        op = "(*:*%20-#{field}:[*%20TO%20*])" if value is 'null'

        options.push(op)

        _.each values, (v) ->
            op = "#{field}:\"#{encodeURIComponent(v)}\""
            op = "*:*%20-#{field}:[*%20TO%20*]" if v is 'null'
            options.push(op)

        fq += options.join '+OR+'
        fq += ')'

        @parameters.push(fq)


    # Return all items from a core
    getCollection: (query, cb) =>

        @createClient() unless @client

        unless query
            query = @client.createQuery()
                .q("*:*")
                .start(0)
                .rows(999999)


        @client.search query, (err, result) =>
            return cb err, result if err
            @parseCollection result, (err, result) =>
                throw err if err
                cb null, result


    # Prepare items in the collection to be ready for backend use. Some
    # fields are stored as stringified json objects for example, and all fields
    # in Solr contain a suffix which should be removed.
    parseCollection: (result, cb) =>
        docs = []
        _.each result.response?.docs, (doc) =>
            doc = @removeSuffix doc
            doc = @parseJsonFields doc
            docs.push doc
        result.response.docs = docs

        @setClinkItems result.response.docs, (docs) =>
            result.response.docs = docs
            cb null, result


    # Get a document from Solr based on its ID
    getItemById: (id, cb) =>

        @createClient() unless @client

        id = id.join(' OR ') if id instanceof Array

        query = @client.createQuery()
            .q("id:(#{id})")
            .start(0)
            .rows(1000)

        @client.search query, (err, result) =>
            return cb err, result if err
            docs = []
            _.each result.response?.docs, (doc) =>
                doc = @removeSuffix doc
                doc = @parseJsonFields doc
                docs.push doc
            cb null, docs


    # Get all documents from Solr that match a value
    getItemsByProp: (key, value, cb) =>
        key = @addSuffix key

        @createClient() unless @client

        query = @client.createQuery()
            .q("#{key}:#{value}")
            .start(0)
            .rows(1000)

        @client.search query, (err, result) =>
            return cb err, result if err
            docs = []
            _.each result.response?.docs, (doc) =>
                docs.push @removeSuffix doc
            cb null, docs


    # Get the sort parameter. If its not specified on QS, the default value
    # is specified in the settings file.
    getSort: (entity, sort) =>

        sorts = {}

        sort = @settings.sort unless sort

        _.each sort.split(','), (s) =>
            [ id, order ] = s.split ':'
            if s.split(':').length is 3
                [id1, id2, order] = s.split ':'
                id = "#{id1}:#{id2}"
            field = @schema.getFieldById id

            # Solr can't sort multivalue fields. There is a stringified copy
            # of each mv field with the suffix -sort appended to its id.
            if @isMultivalue field then id = "#{id}-sort"
            else id = @addSuffix id

            sorts[id] = order
        sorts


    # Return all fields specified as "searchable" (search: true) on the schema.
    getSearchableFields: () =>
        searchables = @schema.getFieldsByProp 'search'
        fields = {}
        _.each searchables, (f) =>
            return fields["#{f.id}-sort"] = 1 if @isMultivalue f
            fields[@addSuffix(f.id)] = 1 if f.search
        return fields

    # Add a month field that acts like a facet
    addMonthFacetFields: (item) =>
        dateFields = @schema.getFieldsByType('date')
        dateTimeFields = @schema.getFieldsByType('datetime')

        fields = dateFields.concat(dateTimeFields)

        _.each fields, (f) =>
            return unless item[f.id] and f.facet is 'month'
            d = new Date(item[f.id]).getMonth()
            monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]
            d = monthNames[d]
            item["_#{f.id}_month-sm"] = [ d ]
        item


    # Add a year field that acts like a facet
    addYearFacetFields: (item) =>
        dateFields = @schema.getFieldsByType('date')
        dateTimeFields = @schema.getFieldsByType('datetime')

        fields = dateFields.concat(dateTimeFields)

        _.each fields, (f) =>
            return unless item[f.id] and f.facet is 'year'
            year = []
            d = new Date(item[f.id]).getFullYear()
            year.push d
            item["_#{f.id}_year-sm"] = year
        item


    # Add a document to the solr collection
    addItems: (items, cb) =>
        @createClient() unless @client

        docs = []
        _.each [].concat(items), (item) =>
            item = @resetClinkFields item
            item = @stringifyJsonItem item
            item = @tokenizeFacetFields item
            item = @addSortFields item
            item = @addMonthFacetFields item
            item = @addYearFacetFields item
            item = @addObjSuffix item
            item.id = @generateId() unless item.id
            item['_version_'] = new Date().toISOString()
            docs.push item

        @client.add docs, (err, result) =>
            return cb err, result if err
            items = []
            _.each docs, (doc) => items.push @removeSuffix doc
            cb null, items


    # Adds fields that are of facet type to the query so that the faceted
    # response includes them.
    setFacets: (facetFields, query) =>
        facetFields = [ facetFields ] if typeof facetFields is "string"
        _.each facetFields, (f) =>
            fieldParam = @addSuffix f
            query.facet
                field: "{!ex=_#{fieldParam}}#{fieldParam}"
                limit: -1


    # Adds filter parameters to a query. i.e. facet filters or search terms.
    setFilters: (req, query) =>

        fqFields = {}
        fq = req.query.fs

        cubeId = req.user?.cubeId || null

        # Handle an array of facet filters
        if typeof fq is typeof []
            _.each fq, (fq) =>
                [filter, value] = @parseFilter fq
                fqFields[filter] = [] unless fqFields[filter]
                fqFields[filter].push value
            _.each fqFields, (fields, f) ->
                query.matchFilter f, fields, cubeId
            return

        [filter, value] = @parseFilter fq

        query.matchFilter filter, [ value ], cubeId


    # Gets a query parameter from &fs and parses it to return a filter and value
    parseFilter: (str) ->
        filter = str.split(':')[0]
        filter = @addSuffix filter
        value = str.split(':')
        value.splice(0,1)
        value = value.join(':')
        [filter, value]


    # Get data of cube link fields ant set it for each item.
    setClinkItems: (docs, cb) =>

        return cb docs unless docs.length

        fields = @schema.getFieldsByType 'clink'

        return cb docs unless fields.length

        async.each docs, (doc, _cb) =>
            async.each fields, (field, __cb) =>
                @setClinkField field, doc, () =>
                    return __cb()
            , (err) ->
                throw err if err
                return _cb()
        , (err) =>
            throw err if err
            cb docs


    # Retreive data of a cube link field from another entity and set it.
    setClinkField: (field, d, cb) =>

        solrManager = new SolrManager field.entity

        if field.cid
            return cb() unless d[field.id]

            if field.cid isnt 'id'
                return solrManager.getItemsByProp field.cid, d[field.id].pop(), (err, items) =>
                    throw err if err
                    d[field.id] = items
                    cb()

            solrManager.getItemById "(#{d[field.id].join(' ')})", (err, items) =>
                throw err if err
                d[field.id] =  items
                return cb()

        if field.cfs
            cfs = d[field.cfs]
            cfs = cfs[cfs.length-1] if cfs instanceof Array
            opts =
                params: entity: field.entity
                query: rows: 10000, fs: "#{field.entity}:#{cfs}"
            solrManager.createQuery opts, (query) =>
                solrManager.getCollection query, (err, result) =>
                    d[field.id] = result.response.docs
                    return cb()


    # Cube link fields need to be a list of IDs to be saved
    resetClinkFields: (item) =>

        _.each @schema.getFieldsByType('clink'), (field) =>

            return delete item[field.id] if field.cfs

            cid = field.cid || field.id

            oarr = []

            items = item[field.id]
            items = [ items ] unless items instanceof Array

            _.each items, (i) =>
                return unless i
                return oarr.push i if typeof i is "string" and oarr.indexOf(i) is -1
                oarr.push i[cid] if i[cid] and oarr.indexOf(i[cid]) is -1

            item[field.id] = oarr
        item

    # Fields with property 'json' are saved as stringified json objects. This
    # will bring json life into them.
    parseJsonFields: (doc) =>
        fields = @schema.getFieldsByProp 'json'
        _.each fields, (field) =>
            doc[field.id] = JSON.parse doc[field.id] if doc[field.id]
        doc


    # Prepare an item with json fields to be stored
    stringifyJsonItem: (item) =>
        fields = @schema.getFieldsByProp 'json'
        _.each fields, (field) =>
            item[field.id] = JSON.stringify item[field.id]
        item


    tokenizeFacetFields: (item) =>
        fields = @schema.getFieldsByType 'facet'
        _.each fields, (field) =>
            return unless item[field.id]
            return item[field.id] = [ item[field.id].toLowerCase() ] if field.token
            item[field.id] = @tokenizeField item[field.id]
        item


    tokenizeField: (value) =>
        tokens = []
        value = value.toString()
        _.each value.split(','), (v, i) =>
            v = v.trim()
            _.each @getUniqueTokens(v), (t) =>
                tokens.push(t) unless tokens.indexOf(t) isnt -1
        tokens

    # result: [ "main", "main/node1", "main/node1/node2" ]
    getUniqueTokens: (str, sep) =>
        h = []
        sep = '/' unless sep
        _.each str.split(sep), (v, i) ->
            h.push str.split(sep).slice(0, i + 1).join(sep)
        h

    # Remove all documents from core. USE WITH CAUTION!
    purge: (cb) =>
        @createClient() unless @client
        @client.deleteByQuery "*:*", (err, result) -> cb() if cb?

    # Generate a random ID
    generateId: () ->
        chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        today = new Date()
        result = today.valueOf().toString 16
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        return result
