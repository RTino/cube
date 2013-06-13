###
# Schema class
#
# Provides useful tools to handle schemas
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements
#
_ = require 'underscore'


class Schema

    module.exports = Schema

    # Initialize with schema from entity
    constructor: (@name) ->
        @fields = require "../entities/#{@name}/schema.json"

    # Get just one field from a field ID
    getFieldById: (id) =>
        field = {}
        _.each @fields, (f) =>
            field = f if f.id is id
        field

    # Get all fields that have a specific property
    getFieldsWithProperty: (property) =>
        fields = []
        _.each @fields, (f) =>
            fields.push f if f[property]
        fields

    # Get all fields that are searchable (search: true)
    getSearchables: () =>
        @getFieldsWithProperty 'search'
