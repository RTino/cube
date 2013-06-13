###
# ItemController.coffee
#
# Serves routes for items. i.e. Any url that contains one or more ids.
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

fs    = require 'fs'
_     = require 'underscore'
async = require 'async'
im    = require "imagemagick"
mime  = require "mime-magic"

# Server settings
settings = require "#{__dirname}/../server.settings.coffee"

# Solr Manager to add/remove solr suffixes
SolrManager = require './solrManager.coffee'

class ItemController

    module.exports = ItemController


    # Routes
    constructor: (app) ->

        # Get a single item
        app.get     "/:entity/collection/:id",  (a...)  => @get     a...

        # Create a new item
        app.post    "/:entity/collection",      (a...)  => @post    a...

        # Update an existing item
        app.put     "/:entity/collection/:id",  (a...)  => @put     a...

        # Remove an item
        app.delete  "/:entity/collection/:id",  (a...)  => @delete  a...

    # Get an item or an array of items from IDs
    get: (req, res) =>

        # Name of entity
        name = req.params.entity

        # Item ID
        id = req.params.id.split('|')

        # Return just 1 item
        if id.length is 1 then return @getItemById name, id[0], (docs) ->
            res.send docs

        # Return an array of items
        docs = []

        async.forEach id, (id, cb) =>
            @getItemById name, id, (item) ->
                docs.push item[0]
                cb()
        , (err) ->
            throw err if err
            return res.send docs

    # Create a new item
    post: (req, res) =>

        # Entity  name
        name = req.params.entity

        # Create solr manager for this entity
        solrManager = new SolrManager name

        db = solrManager.createClient()

        # Create and ID for the new item
        id = @generateId()

        # Get the id of the picture field
        picKey = @getPictureFields(name)[0]?.id

        # Create a new item with id
        item = _.extend {id: id}, solrManager.addObjSuffix name, req.body

        # Send the formed item with id unless there is a picture
        if !req.body[picKey]
            return @addItem res, solrManager, item, (_item) =>
                res.send solrManager.removeSuffix _item

        # Get pic url
        tmp_pic = "#{__dirname}/../public/#{req.body[picKey]}"
        target_file = "#{id}.jpg"
        target_path = "#{__dirname}/../public/images/#{name}/#{target_file}"

        # Move the picture to its final place and send item object back
        fs.rename tmp_pic, target_path, (err) =>
            throw err if err
            key = solrManager.addSuffix(name, picKey)
            item[key] = "/images/#{name}/#{target_file}" unless err
            @addItem res, solrManager, item, (_item) =>
                res.send solrManager.removeSuffix _item

    # Update an item
    put: (req, res) ->

        # Entity name
        name = req.params.entity

        # Solr manager for this entity to handle suffixes
        solrManager = new SolrManager name

        db = solrManager.createClient()

        # Picture id
        picKey = solrManager.addSuffix name, @getPictureFields(name)[0]?.id

        # Get item from db with ID
        @getItemById name, req.params.id, (result) =>

            item = solrManager.addObjSuffix(name, result[0])

            req.body = solrManager.addObjSuffix(name, req.body)

            # If client is admin, all fields are updated
            if req.query.admin isnt 'yes'
                protectedFields = @getFieldsWithProperty name, 'admin'

                # Update protected fields (additional: false)
                _.each protectedFields, (f) =>
                    f = solrManager.addSuffix(name, f)
                    req.body[f.key] = item[f.key]

                    # If its a multivalue field, add a copy field with its
                    # array stringified, so search and sort work on this field.
                    if solrManager.isMultivalue f
                        multivalueField = item[f.key].sort().join(" ")
                        req.body["#{f.key}-sort"] = multivalueField

            # If there is no picture field, respond with updated item object.
            if !req.body[picKey] or req.body[picKey] is item[picKey]
                return @addItem res, solrManager, req.body, (_item) =>
                    res.send solrManager.removeSuffix _item

            # Update picture field and respond.
            @updatePic item.id, name, req.body[picKey], item[picKey], (path) =>
                req.body[picKey] = path
                @addItem res, solrManager, req.body, (_item) =>
                    res.send solrManager.removeSuffix _item


    # Remove item and its picture (if it has).
    delete: (req, res) =>
        name = req.params.entity
        id = req.params.id
        solrManager = new SolrManager name
        db = solrManager.createClient()
        picKey = @getPictureFields(name)[0]?.id

        @getItemById name, id, (docs) =>
            _.each docs, (item) ->
                solrManager.client.deleteByID id, (err, result) ->
                    throw err if err
                    res.send result
                return unless picKey
                imgPath = "#{__dirname}/../public/#{item[picKey]}"
                fs.unlink imgPath, (err) ->
                    console.log "Failed to remove pic for user #{id}" if err


    # Update picture removing old picture and renaming new one.
    updatePic: (id, name, bodyPic, itemPic, cb) =>
        tmp_pic = "#{__dirname}/../public/#{bodyPic}"
        rnd = bodyPic.slice(21, 24)
        target_file = "/images/#{name}/#{id}_#{rnd}.jpg"
        target_path = "#{__dirname}/../public/#{target_file}"

        fs.stat tmp_pic, (err, stat) ->
            if err then console.log "ERROR[uid=#{id}]: No uploaded picture"
            fs.unlink "#{__dirname}/../public/#{itemPic}", (err) ->
                fs.rename tmp_pic, target_path, (err) ->
                    throw err if err
                    cb target_file


    # Get an Item by its ID
    getItemById: (name, id, cb) ->

        solrManager = new SolrManager name

        db = solrManager.createClient()

        query = db.createQuery()
            .q("id:#{id}")
            .start(0)
            .rows(1000)

        db.search query, (err, result) ->
            throw err if err
            docs = []
            _.each result.response?.docs, (doc) ->
                docs.push solrManager.removeSuffix doc
            cb docs

    # Get Picture fields from schema (type: "img").
    getPictureFields: (name) ->
        schema = require "#{__dirname}/../entities/#{name}/schema.json"
        arr = []
        _.each schema, (o) =>
            arr.push o if o.type is "img"
        arr

    # Add an item to the solr db
    addItem: (res, solrManager, item, cb) =>
        _item = _.extend {}, item
        solrManager.client.add [item], (err, result) ->
            throw err if err
            cb _item

    # Get all schema fields that cointain a specific property
    # TODO Get from schema class
    getFieldsWithProperty: (name, p) ->
        schema = require "#{__dirname}/../entities/#{name}/schema.json"
        arr = []
        _.each schema, (o) =>
            arr.push o if o[p]
        arr

    # Get all fields that have a specific type in an entity's schema
    getFieldsByType: (name, t) ->
        schema = require "#{__dirname}/../entities/#{name}/schema.json"
        arr = []
        _.each schema, (o) =>
            arr.push o if o.type is t
        arr

    # Generate an ID for the item on the db
    generateId: () ->
        chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        today = new Date()
        result = today.valueOf().toString 16
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result
