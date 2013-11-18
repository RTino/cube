###
# ItemController.coffee
#
# Serves routes for items. i.e. Any url that contains one or more ids.
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

fs    = require 'fs'
_     = require 'lodash'
async = require 'async'
im    = require "imagemagick"
mime  = require "mime-magic"

# Server settings
settings = require "#{__dirname}/../server.settings.coffee"

# Solr Manager to add/remove solr suffixes
SolrManager = require './solrManager.coffee'

Schema = require './schema.coffee'

class ItemController


    module.exports = ItemController


    # Routes
    constructor: (app, auth) ->

        # Get a single item
        app.get     "/:entity/collection/:id",  auth, (a...) => @get    a...

        # Create a new item
        app.post    "/:entity/collection",      auth, (a...) => @post   a...

        # Update an existing item
        app.put     "/:entity/collection/:id",  auth, (a...) => @put    a...

        # Remove an item
        app.delete  "/:entity/collection/:id",  auth, (a...) => @delete a...

        # Return one field from an item
        app.get     "/:entity/:item/property/:property", auth, (a...) => @prop   a...

        # Put a value in an items property
        app.put     "/:entity/:item/property/:property/:value", auth, (a...) =>
            @putValue  a...

        # Put a value in an items property
        app.delete  "/:entity/:item/property/:property/:value", auth, (a...) =>
            @delValue  a...


    # Get an item or an array of items from IDs
    get: (req, res) =>

        entity = req.params.entity
        solrManager = new SolrManager entity
        id = req.params.id.split('|')

        solrManager.getItemById id, (err, items) =>
            throw err if err
            items = items.pop() if items.length is 1
            res.send items


    # Create a new item
    post: (req, res) =>

        entity      = req.params.entity
        solrManager = new SolrManager entity
        schema      = solrManager.schema
        auth        = settings.Authentication
        eSettings   = require "../entities/#{entity}/settings.json"
        id          = @generateId()
        picKey      = schema.getFieldsByType('img')[0]?.id
        response    = null

        if auth?.strategy? isnt 'none' and eSettings.admins?.length and
            !@isAdmin req.user.mail, eSettings.admins
                res.setHeaders 403
                return res.send 'Unauthorized'


        # Create a new item with id
        item = _.extend {id: id}, req.body

        async.series [

            (cb) =>
                # Token Fields
                tokenFields = schema.getFieldsByProp 'token'
                return cb() unless tokenFields.length

                fid = tokenFields[0]?.id
                return cb() unless fid

                value = item[fid]
                return cb() unless value

                async.each value, (v, _cb) =>

                    return _cb() unless v

                    solrManager.getItemsByProp fid, v, (items) =>
                        docs = []
                        _.each items, (item, __cb) =>
                            return if item.id is req.body.id
                            item[fid] = _.without item[fid], v
                            delete item[fid] if item[fid].length is 0
                            docs.push item

                        solrManager.addItems docs, (err, docs) =>
                            throw err if err
                            _cb()

                , (err, result) =>
                    throw err if err
                    cb()

            , (cb) =>
                # Check for picture
                return cb() if response

                # Ready to add items to db if they don't have a picture
                return cb() unless req.body[picKey] is item[picKey]

                response = item

                cb()

            , (cb) =>
                # Save picture

                return cb() if response

                # Update picture field and add items to db
                @savePic id, entity, item, (path) =>
                    item[picKey] = path
                    response = item
                    cb()

            , (cb) =>
                # Extended Backend

                ExtBackend = require("../entities/#{entity}/backend.coffee").ExtBackend

                return cb() unless ExtBackend

                extBackend = new ExtBackend item

                return cb() unless extBackend.create

                extBackend.create (err, i) ->
                    throw err if err
                    item = i
                    cb()

            , (cb) =>
                # Save item to DB

                solrManager.addItems item, (err, item) =>
                    throw err if err
                    response = item.pop()
                    cb()

        ], (err, result) =>
            throw err if err

            res.send response


    # Update an item
    put: (req, res) =>

        entity = req.params.entity
        eSettings = require "../entities/#{entity}/settings.json"
        solrManager = new SolrManager entity
        schema = solrManager.schema
        picKey = schema.getFieldsByType('img')[0]?.id
        item = null
        response = null

        async.series [

            (cb) =>
                # Get item from the id on the querystring
                solrManager.getItemById req.params.id, (err, result) =>
                    return cb err if err
                    if result.length is 1
                        item = result.pop()
                        return cb()
                    res.statusCode = 404
                    response = "Item to update doesn't exist"
                    cb()

            , (cb) =>
                return cb() if response

                # Detect concurrency issues and respond 409 in case.
                if !@isVersionValid item, req.body
                    res.statusCode = 409
                    response = {}
                    return cb()
                cb()

            , (cb) =>
                # Remove this item's token values from all other items.
                return cb() if response

                tokenFields = schema.getFieldsByProp 'token'
                return cb() unless tokenFields.length

                fid = tokenFields[0]?.id
                return cb() unless fid

                value = req.body[fid].split(',')
                return cb() unless value

                async.each value, (v, _cb) =>

                    return _cb() unless v

                    solrManager.getItemsByProp fid, v, (err, items) =>
                        docs = []
                        _.each items, (item, __cb) =>
                            return if item.id is req.body.id
                            item[fid] = _.without item[fid], v
                            delete item[fid] if item[fid].length is 0
                            docs.push item

                        solrManager.addItems docs, (err, docs) =>
                            return cb err if err
                            _cb()

                , (err, result) =>
                    return cb err if err
                    cb()

            , (cb) =>
                return cb() if response

                # Update additional information fields. No privilege required.
                _.each solrManager.schema.getFieldsByProp('additional'), (field) =>
                    item[field.id] = req.body[field.id] if req.body[field.id]

                auth = settings.Authentication
                if auth?.strategy? isnt 'none' and eSettings.admins?.length
                    return cb() unless @isAdmin req.user.mail, eSettings.admins

                # Update all fields
                _.each solrManager.schema.fields, (field) ->
                    return if field.id is picKey
                    item[field.id] = req.body[field.id]

                cb()

            , (cb) =>
                return cb() if response

                # Ready to add items to db if they don't have a picture
                return cb() unless req.body[picKey] is item[picKey]

                response = item

                cb()

            , (cb) =>
                return cb() if response

                # Update picture field and add items to db
                @updatePic item.id, entity, req.body[picKey], item[picKey], (path) =>
                    item[picKey] = path
                    response = item
                    cb()

            , (cb) =>

                ExtBackend = require("../entities/#{entity}/backend.coffee").ExtBackend

                return cb() unless ExtBackend

                extBackend = new ExtBackend item

                return cb() unless extBackend.update

                extBackend.update (err, i) ->
                    return cb err if err
                    item = i
                    cb()

            , (cb) =>

                solrManager.addItems item, (err, item) =>
                    cb err if err
                    cb()

        ], (err, result) ->

            if err
                console.log 'Error: ', err
                res.statusCode = 500
                return res.send err

            # Ready to send the response back to backbone app
            res.send response


    # Remove item and its picture (if it has).
    delete: (req, res) =>
        entity = req.params.entity
        id = req.params.id
        solrManager = new SolrManager entity
        schema = solrManager.schema
        picKey = schema.getFieldsByType('img')[0]?.id

        solrManager.getItemById id, (err, docs) =>
            throw err if err
            _.each docs, (item) =>

                ExtBackend = require("../entities/#{entity}/backend.coffee").ExtBackend

                if ExtBackend
                    extBackend = new ExtBackend item if ExtBackend
                    extBackend.delete (err, i) ->
                        throw err if err

                solrManager.client.deleteByID id, (err, result) ->
                    throw err if err
                    res.send result

                return unless picKey

                imgPath = "#{__dirname}/../public/#{item[picKey]}"
                fs.unlink imgPath, (err) ->
                    console.log "Failed to remove pic for user #{id}" if err


    # Update picture removing old picture and renaming new one.
    updatePic: (id, entity, bodyPic, itemPic, cb) =>
        tmp_pic = "#{__dirname}/../public/#{bodyPic}"
        rnd = bodyPic.slice(21, 24)
        target_file = "/images/#{entity}/#{id}_#{rnd}.jpg"
        target_path = "#{__dirname}/../public/#{target_file}"

        fs.stat tmp_pic, (err, stat) ->
            if err then console.log "ERROR[uid=#{id}]: No uploaded picture"
            fs.unlink "#{__dirname}/../public/#{itemPic}", (err) ->
                fs.rename tmp_pic, target_path, (err) ->
                    throw err if err
                    cb target_file

    savePic: (id, entity, item, cb) =>
        # Get pic url
        tmp_pic = "#{__dirname}/../public/#{item[picKey]}"
        target_file = "#{id}.jpg"
        target_path = "#{__dirname}/../public/images/#{entity}/#{target_file}"

        # Move the picture to its final place and send item object back
        fs.rename tmp_pic, target_path, (err) =>
            return cb err if err
            item[picKey] = "/images/#{entity}/#{target_file}" unless err
            solrManager.addItems item, (err, item) =>
                throw err if err
                response = item.pop()
                return cb()


    # Get the value of a property from one specific item
    prop: (req, res) =>

        entity  = req.params.entity
        item    = req.params.item
        prop    = req.params.property

        solrManager = new SolrManager entity

        solrManager.getItemById item, (err, items) ->
            throw err if err
            return res.send [] unless items.length
            res.send items[0][prop]


    # Set or insert a value on a property from an item
    putValue: (req, res) =>

        entity  = req.params.entity
        item    = req.params.item
        prop    = req.params.property
        value   = req.params.value

        Verify  = require("../entities/#{entity}/code.coffee").Verify

        # Check if its allowed to make this change
        unless Verify
            res.statusCode = 403
            return res.send "Not allowed"

        verify = new Verify req

        verify.isAllowed (allowed) =>

            unless allowed
                res.statusCode = 403
                return res.send "Not allowed"

            solrManager = new SolrManager entity

            solrManager.getItemById item, (err, items) =>
                throw err if err
                return res.send [] unless items.length

                item = items[0]

                item[prop] = [] unless item[prop]

                if typeof item[prop] is typeof []
                    item[prop].push value if item[prop].indexOf(value) is -1
                else
                    item[prop] = value

                solrManager.addItems item, (err, item) =>
                    throw err if err
                    res.send item


    # Delete a value from an item
    delValue: (req, res) =>

        entity  = req.params.entity
        item    = req.params.item
        prop    = req.params.property
        value   = req.params.value

        Verify  = require("../entities/#{entity}/code.coffee").Verify

        unless Verify
            res.statusCode = 403
            return res.send "Not allowed"

        # Check if its allowed to make this change
        verify = new Verify req

        verify.isAllowed (allowed) =>

            if not allowed
                res.statusCode = 403
                return res.send "Not allowed"

            solrManager = new SolrManager entity

            solrManager.getItemById item, (err, items) =>
                throw err if err
                return res.send [] unless items.length

                item = items[0]

                return req.send 404 unless item[prop]

                if item[prop] instanceof Array
                    index = item[prop].indexOf value
                    item[prop] = item[prop].splice index, 1
                    delete item[prop] if item[prop].length is 1
                else
                    delete item[prop]

                solrManager.addItems item, (err, _item) =>
                    throw err if err
                    res.send _item


    # Generate an ID for the item on the db
    generateId: () ->
        chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        today = new Date()
        result = today.valueOf().toString 16
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result


    # Check version match for concurrency issues
    isVersionValid: (reqItem, dbItem) =>
        return yes unless dbItem['_version'] and reqItem['_version_']
        dbTimestamp  = new Date dbItem['_version_']
        reqTimestamp = new Date reqItem['_version_']
        if reqTimestamp < dbTimestamp
            return no
        yes


    # Check if id is in list
    isAdmin: (id, list) =>
        return yes if list.indexOf(id) isnt -1
        no
