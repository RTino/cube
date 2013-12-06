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

CalendarManager = require './calendarManager.coffee'

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
        app.get   '/:entity/calendar',        auth, (a...) => @calendar   a...
        app.get   '/:entity/property/:p/:v',  auth, (a...) => @getByProp  a...


    # Return appropriate schema for each entity
    schema: (req, res) ->
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1
        schema = require "#{__dirname}/../entities/#{entity}/schema.json"
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
        solrManager = new SolrManager entity
        solrManager.createQuery req, (query) =>
            solrManager.getCollection query, (err, result) =>
                return @error res, err if err
                @setResponse req, res, result, (result) =>
                    res.send result

    error: (res, err) =>
        res.statusCode = 500
        res.send err


    # Returns pane.json, containing extra data for custom panes.
    pane: (req, res) ->
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1
        file = "#{__dirname}/../entities/#{entity}/pane.json"
        res.setHeader 'Content-Type', 'application/json'
        fs.readFile file, "utf8", (err, data) =>
            return res.send {} if err
            res.send data


    # Get unique values from all the facet fields. Useful for autocomplete.
    ufacets: (req, res) =>
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1
        facetManager.distincts req.params.entity, (d) =>
            res.send d


    # Picture uploader. Save picture on tmp location, convert, manipulate and
    # move to storage location. Respond with an array of properties from the
    # uploaded image. Useful for backbone.
    picture: (req, res) =>
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1

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
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1
        res.render "../entities/#{entity}/templates"


    # Return all available entities with its settings
    getEntities: (cb) =>
        es = {}
        _.each entities, (e) =>
            settings = require "#{__dirname}/../entities/#{e}/settings.json"
            es[e] = settings
        cb es

    # Set response of a collection request, depending on the format asked.
    setResponse: (req, res, result, cb) =>
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


    # Checks if the requested resource is one of the available entities
    isEntity: (entity) =>
        return yes unless entities.indexOf(entity) is -1
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


    # Export selected or user events to .ics file
    calendar: (req, res) ->
        entity = req.params.entity
        return res.send 404 if entities.indexOf(entity) is -1

        params =
            entity: entity
            user: if req.session.passport.user? then req.session.passport.user else null
            selection: if req.query.selection? then JSON.parse(req.query.selection) else null

        cm = new CalendarManager(params)
        cm.get (ics) =>
            res.writeHead 200,
                'Content-Type': 'text/calendar'
                'Content-disposition': 'inline; filename="tech_academy.ics"'
            res.end ics


    getByProp: (req, res) ->

        entity  = req.params.entity
        prop    = req.params.p
        val     = req.params.v

        return res.send 404 if entities.indexOf(entity) is -1

        solrManager = new SolrManager entity

        solrManager.getItemsByProp prop, val, (err, items) =>
            res.send items

