###
# SolrManager.coffee
#
# Solr Manager provides useful functions to handle solr connections
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

# Underscore js library
_     = require 'underscore'

# Solr Nodejs Client library
solr  = require 'solr-client'

# Schema manager
Schema = require './schema'


class SolrManager


    module.exports = SolrManager


    constructor: (@name) ->


    # Create a Solr instance with propper database connection
    createClient: () =>

        # DB Settings for name entity
        db = require "../entities/#{@name}/db.json"

        # Create client with settings
        @client = solr.createClient db.host, db.port, db.core, db.path

        # Commit after each request
        @client.autoCommit = yes

        # Return new db connection
        @client


    # Dynamic schemas in solr require a suffix that specifies the type of field
    # to create. Fields in the DB will be stored with the suffix, but the
    # front-end should not know about it.
    addSuffix: (name, p) =>

        schema = new Schema name

        # id field doesn't have a suffix, its not a dynamic field.
        return p if p is "id" or p is undefined

        # Get field information from the schema
        f = schema.getFieldById p

        # Add suffix
        sf = "-s"                               # String with analytics field
        sf = "-i" if f.type is 'integer'        # Integer field
        sf = "-f" if f.type is 'float'          # Float field
        sf += "m" if @isMultivalue f            # Multivalue field (array)
        sf += "r" if f.mandatory                # Required field

        # Return property with suffix appended at the end
        p + sf


    # Adds suffixes to all keys of an Object
    addObjSuffix: (name, obj) =>

        # Object to return with suffixes appended.
        newObj = {}

        schema = new Schema name

        _.each obj, (v, k) =>

            # Add suffix to the key
            ks = @addSuffix name, k

            # Get field from Schema with all properties
            f = schema.getFieldById k

            # Set value to new object
            newObj[ks] = v

            # Multivalue fields should have a stringified copy in another field
            @setMultivalueField newObj, f, v, k, ks if @isMultivalue f

        newObj


    # If the field is a multivalue field and contains subcategories (bar/foo)
    # it has to be splitted into (bar, bar/foo) for solr to return the correct
    # facet results and be able to render the correct tree structure.
    setMultivalueField: (newObj, f, v, k, ks) ->

        newObj[ks] = []

        # If the value is a comma separated list, make it an array.
        v = v.toString().split(',') if typeof v isnt typeof []

        _.each v, (value) ->

            # Push the original value
            newObj[ks].push value

            # Get the parent category and add it to the list of values
            if value.indexOf('/') isnt -1
                parent = value.split('/')[0]
                newObj[ks].push parent if value.indexOf(parent) is -1

        # A sort field needs to be added for every multivalue field
        @addSortField newObj, f, v, k, ks

        newObj

    # Form a hierarchy array from a string like main/node1/node2.
    # result: [ "main", "main/node1", "main/node1/node2" ]
    formHierarchyArray: (str, sep) ->
        h = []
        sep = '/' unless sep
        _.each str.split(sep), (v, i) ->
            h.push str.split(sep).slice(0, i+1).join(sep)
        h

    # Solr is not able to sort multivalue fields or fields with analyzers.
    # To be able to do it, a stringified copy of the multivalue field has
    # to be stored in a simple 'string' type field, and use it for sort.
    addSortField: (newObj, f, v, k, ks) ->

        newObj["#{k}-sort"] = newObj[ks].sort().join(' ')


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
        return no

    # Replaces matchFilter method on solr-client until we find a better way
    # to do this.
    customMatchFilter: (field,values) ->
        options = []
        tag = "{!tag=_#{field}}"
        fq = "fq=#{tag}("

        value = encodeURIComponent values.pop()

        op = "#{field}%3A\"#{value}\""

        # A string null as a value is a not set value. In other words,
        # filtering by 'null' returns all items without the property.
        op = "(*:*%20-#{field}:[*%20TO%20*])" if value is 'null'


        # TODO Make this generic
        if value is 'new'
            d = new Date()
            d.setDate d.getDate() - 31
            op = "startDate-sr%3A[#{d.toISOString()}%20TO%20*]"

        options.push(op)

        _.each values, (v) ->
            op = "#{field}:\"#{encodeURIComponent(v)}\""
            op = "*:*%20-#{field}:[*%20TO%20*]" if v is 'null'
            options.push(op)

        fq += options.join '+OR+'
        fq += ')'

        @parameters.push(fq)
