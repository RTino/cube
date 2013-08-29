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
_ = require 'lodash'

# Solr Nodejs Client library
solr = require 'solr-client'

# Schema manager
Schema = require './schema'


class SolrManager


    module.exports = SolrManager


    constructor: (@name) ->
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


    # Dynamic schemas in solr require a suffix that specifies the type of field
    # to create. Fields in the DB will be stored with the suffix, but the
    # front-end should not know about it.
    addSuffix: (p) =>

        # id field doesn't have a suffix, its not a dynamic field.
        return p if p is "id" or p is undefined

        # Get field information from the schema
        f = @schema.getFieldById p

        # Add suffix
        sf = "-s" # String with analytics field
        sf = "-i" if f.type is 'integer' # Integer field
        sf = "-f" if f.type is 'float' # Float field
        sf += "m" if @isMultivalue f # Multivalue field (array)
        sf += "r" if f.mandatory # Required field

        # Return property with suffix appended at the end
        p + sf


    # Adds suffixes to all keys of an Object
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
                newObj[@addSuffix(k)] = v

        newObj


    # Form a hierarchy array from a string like main/node1/node2.
    # result: [ "main", "main/node1", "main/node1/node2" ]
    formHierarchyArray: (str, sep) =>
        h = []
        sep = '/' unless sep
        _.each str.split(sep), (v, i) ->
            h.push str.split(sep).slice(0, i + 1).join(sep)
        h

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
    customMatchFilter: (field, values) ->
        options = []
        tag = "{!tag=_#{field}}"
        fq = "fq=#{tag}("

        value = values.pop()

        op = "#{field}%3A\"#{encodeURIComponent(value)}\""

        op = "#{field}%3A[*%20TO%20*]" if value is '[* TO *]'

        # A string 'null' as a value is a not set property. In other words,
        # filtering by 'null' returns all items without the property.
        op = "(*:*%20-#{field}:[*%20TO%20*])" if value is 'null'

        # TODO Make this generic
        if value is 'new'
            d = new Date()
            d.setDate d.getDate() - 31
            op = "startDate-s%3A[#{d.toISOString()}%20TO%20*]"

        options.push(op)

        _.each values, (v) ->
            op = "#{field}:\"#{encodeURIComponent(v)}\""
            op = "*:*%20-#{field}:[*%20TO%20*]" if v is 'null'
            options.push(op)

        fq += options.join '+OR+'
        fq += ')'

        @parameters.push(fq)


    # Get a document from Solr based on its ID
    getItemById: (id, cb) =>
        client = @createClient()

        id = id.join(' OR ') if id instanceof Array

        query = client.createQuery()
        .q("id:(#{id})")
        .start(0)
        .rows(1000)

        client.search query, (err, result) =>
            return cb err, result if err
            docs = []
            _.each result.response?.docs, (doc) =>
                docs.push @removeSuffix doc
            cb null, docs

    # Get all documents from Solr that match a value
    getItemsByProp: (key, value, cb) =>
        key = @addSuffix key

        client = @createClient()

        query = client.createQuery()
        .q("#{key}:#{value}")
        .start(0)
        .rows(1000)

        client.search query, (err, result) =>
            return cb err, result if err
            docs = []
            _.each result.response?.docs, (doc) =>
                docs.push @removeSuffix doc
            cb null, docs

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
            item = @addSortFields item
            item = @addMonthFacetFields item
            item = @addYearFacetFields item
            item = @addObjSuffix item
            item['_version_'] = new Date().toISOString()
            docs.push item

        @client.add docs, (err, result) =>
            return cb err, result if err
            items = []
            _.each docs, (doc) => items.push @removeSuffix doc
            cb null, items
