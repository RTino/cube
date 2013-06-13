###
# ExtensionController.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
#
# Note: This file is currently unmantained. Entity creation feature is on hold.
#
###

fs = require 'fs'
_ = require 'underscore'
mime = require 'mime-magic'
http    = require "http"
async   = require "async"
exec    = require("child_process").exec

SolrManager = require './solrManager.coffee'
ItemController = require './itemController.coffee'

settings = require "#{__dirname}/../server.settings.coffee"
entities = require "#{__dirname}/../entities.json"

e = process.env.NODE_ENV
defaultDatabase = settings.Default.Database.development
defaultDatabase = settings.Default.Database.production if e is "production"
defaultAppSettings = settings.Default.Application

class ExtensionController
    module.exports = ExtensionController

    constructor: (app) ->
        app.post    '/entity/:name',     (a...)  => @create  a...
        app.delete  '/entity/:name',     (a...)  => @delete  a...

    create: (req, res) =>
        name = req.files.import.name.split('.')[0]
        type = req.files.import.name.split('.')[1]
        file = req.files.import.path
        r = {}

        async.series
            getMime: (cb) =>
                mime file, (err, t) ->
                    r.type = t
                    cb()

            readFile: (cb) =>
                fs.readFile file, 'utf8', (err, d) ->
                    r.data = d
                    cb(err)

            touchDirs: (cb) =>
                @touchExtensionDir name, (err) ->
                    cb(err)

            createCore: (cb) =>
                return cb() unless entities.indexOf(name) is -1
                @createCore name, (err) ->
                    cb(err)

            generateSchema: (cb) =>
                if entities.indexOf(name) isnt -1
                    fs.readFile "./entities/#{name}/schema.json", "utf8",
                        (err, s) ->
                            throw err if err
                            r.schema = s
                            return cb()
                else
                    if type is "csv"
                        ids = r.data.split('\n')[0].split(';')
                    else
                        ids = []
                        _.each JSON.parse(r.data), (item) ->
                            _.each item, (value, key) ->
                                ids.push key if ids.indexOf(key) is -1
                    @generateSchema name, ids, (s) ->
                        r.schema = s
                        cb()

            importData: (cb) =>
                if type is 'csv'
                    return @importFromCSV r.schema, name, r.data, (err) ->
                        cb(err)
                return @importFromJson r.schema, name, r.data, (err) ->
                    cb(err)

            saveFile: (cb) =>
                return cb() unless entities.indexOf(name) is -1
                entities.push name
                @saveJsonToFile entities, settings.EntitiesFile, (err) ->
                    cb(err)

            setResponse: (cb) =>
                fs.stat file, (err, stats) ->
                    res.setHeader 'Content-Type',
                        'text/plain; charset=utf8'
                    r.response = [
                        "name": name + '.csv'
                        "size": stats.size
                        "type": r.type
                    ]
                    cb(err)

            removeTmpFile: (cb) ->
                fs.unlink file, (err) ->
                    cb(err)
        ,
            (result) ->
                res.send r.response

    delete: (req, res) =>
        name = req.params.name
        child = exec "rm -rf entities/#{name} public/images/#{name}",
            (err) =>
                throw err if err
                es = []
                _.each entities, (e) =>
                    return if e is name
                    es.push e
                entities = es
                @saveJsonToFile entities, settings.EntitiesFile, () =>
                    @removeCore name, () ->
                        res.send 'Extension successfully removed'

    failedCreatingExtension: (name, err) =>
        console.log 'Failed creating entity: ', name
        @delete () ->
            throw err

    generateSchema: (name, ids, cb) =>
        schema = []
        _.each ids, (id) =>
            return if id is 'id'
            schema.push @createSchemaField id, 'string'
        path = "#{__dirname}/../entities/#{name}/schema.json"
        @saveJsonToFile schema, path, () ->
            cb schema

    touchExtensionDir: (name, cb) =>
        return cb() if entities.indexOf(name) isnt -1
        archivePath = "#{__dirname}/../public/images/#{name}/archive/"
        child = exec "mkdir -p #{archivePath}", (err) =>
            throw err if err
        extPath = "#{__dirname}/../entities/#{name}"
        child = exec "mkdir -p #{extPath}", (err) =>
            throw err if err
            _.each [ 'code.coffee', 'style.styl', 'templates.jade' ], (file) =>
                child = exec "touch entities/#{name}/#{file}", (err) =>
                    failedCreatingExtension name, err if err
            @touchDBSettingsFile(name)
            @touchAppSettingsFile(name)
            cb(err) if cb

    importFromJson: (schema, name, jsonarr, cb) =>
        jsonarr = JSON.parse jsonarr
        async.forEach jsonarr, (e, _cb) =>
            e = removeSuffix e
            id = @generateId()

            solrManager = new SolrManager name
            solrManager.createSolrClient name

            newItem = _.extend {id: id}, solrManager.addObjSuffix name, e

            solrManager.client.add [newItem], (err, result) ->
                throw err if err
                _cb()
        ,
            (err) ->
                throw err if err
                cb() if cb

    importFromCSV: (schema, name, csv, cb) =>
        lines = csv.split('\n')
        ids = lines[0].split(';')
        async.forEach lines.slice(1),
            (l, _cb) =>
                return _cb() unless l
                item = {}
                _.each l.split(';'), (v, i) =>
                    return _cb() unless v
                    item[ids[i].split('-')[0]] = v
                    field = @getFieldFromSchema name, ids[i].split('-')[0]
                    if field.multivalue
                        item[ids[i].split('-')[0]] = v.split(',')

                id = @generateId()

                solrManager = new SolrManager name
                solrManager.createClient()

                item = solrManager.addObjSuffix(name, item)
                newItem = _.extend {id: id}, item

                solrManager.client.add [newItem], (err, result) ->
                    throw err if err
                    _cb()
        ,
            (err) ->
                throw err if err
                cb() if cb

    createCore: (name, cb) =>
        solrPath = defaultDatabase.path
        dataRoot = defaultDatabase.dataRoot
        dataDir = "/data/zalando/app/#{dataRoot}/solr/data/#{name}/"
        path = "#{solrPath}/admin/cores?action=CREATE"
        path += "&name=#{name}"
        path += "&instanceDir=conf/cube"
        path += "&dataDir=#{dataDir}"
        db = _.extend {}, defaultDatabase
        db.path = path

        req = http.request db, (res) =>
            res.setEncoding 'utf8'
            res.on 'data', (chunk) =>
                cb() if cb

        req.on 'error', (e) =>
            console.log 'Failed creating core with error:', e.message

        req.write 'data\n'
        req.write 'data\n'
        req.end()

    removeCore: (name, cb) ->
        solrPath = defaultDatabase.path
        path = "#{solrPath}/admin/cores?action=UNLOAD"
        path += "&core=#{name}"
        path += "&deleteIndex=true"
        db = _.extend {}, defaultDatabase
        db.path = path

        req = http.request db, (res) ->
            res.setEncoding 'utf8'
            res.on 'data', (chunk) ->
                cb() if cb

        req.on 'error', (e) ->
            console.log 'Failed removing core with error:', e.message

        req.write 'data\n'
        req.write 'data\n'
        req.end()

    saveJsonToFile: (obj, path, cb) =>
        fs.writeFile path, JSON.stringify(obj, null, 4), (err) ->
            console.log 'Error writing file' if err
            throw err if err
            cb() if cb

    touchDBSettingsFile: (name, cb) =>
        return cb() if entities.indexOf(name) isnt -1
        db = _.extend {}, defaultDatabase
        db.core = name
        @saveJsonToFile db, "entities/#{name}/db.json", cb

    touchAppSettingsFile: (name, cb) =>
        return cb() if entities.indexOf(name) isnt -1
        appSettings = _.extend {}, defaultAppSettings
        appSettings.entity = name
        appSettings.title = name
        @saveJsonToFile appSettings, "entities/#{name}/settings.json", cb

    createSchemaField: (id, type) =>
        suffix = id.split('-')[1]
        id = id.split('-')[0]
        field = _.extend {}, settings.Default.SchemaField
        field.id = id
        field.label = id

        return field unless suffix
        field.type = settings.Default.Suffix[suffix]
        field

    getFieldFromSchema: (name, id) =>
        schema = require "#{__dirname}/../entities/#{name}/schema.json"
        field = {}
        _.each schema, (o) =>
            if o.id is id
                field = o
        field

    generateId: () ->
        chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        today = new Date()
        result = today.valueOf().toString 16
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result
