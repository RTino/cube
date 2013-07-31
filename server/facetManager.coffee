###
# FacetManager.coffee
#
# Provides extra methods to get useful facet information like distinct, all
# fields or listed fields in schema.
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

async = require 'async'
_     = require 'underscore'

Schema      = require './schema.coffee'
SolrManager = require './solrManager.coffee'

class FacetManager

    module.exports = FacetManager

    constructor: () ->

    # Returns an array of unique facet values for each facet type field in
    # your schema.
    distincts: (name, cb) =>
        d = {}

        schema = new Schema name

        async.forEach schema.getFieldsByType('facet'), (f, cb) =>
            @fields name, f.id, (data) ->
                d[f.id] = data
                cb()
        , (err) =>
            throw err if err
            cb d

    # Return all values for each facet
    fields: (name, field, cb) =>

        solrManager = new SolrManager name

        client = solrManager.createClient()

        query = client.createQuery()
            .q('*:*')
            .start(0)
            .rows(0)
            .facet on: yes, field: solrManager.addSuffix field

        fields = []
        client.search query, (err, result) =>
            throw err if err
            ff = result?.facet_counts?.facet_fields
            _.each ff[solrManager.addSuffix field], (f) ->
                fields.push(f) if typeof f is "string"
            cb fields
