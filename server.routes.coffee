####
# Cube Nodejs routes
# server.routes.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
####

module.exports = (app, express, passport) ->

    #### Requirements

    _           = require "underscore"
    fs          = require "fs"
    async       = require "async"


    # Server and default extension settings
    settings = require "#{__dirname}/server.settings.coffee"

    # List of available entities
    entities = require "./#{settings.EntitiesFile}"

    # Default entity is the first entity defined in the entities array
    defaultEntity = entities[0]


    # Controllers

    # Serves any request about entities, like getting its collection
    EntityController    = require "./server/entityController.coffee"

    # Serves any request about an item, like querying by ID.
    ItemController      = require "./server/itemController.coffee"

    # Servers any request about extension administration, like creating one.
    ExtensionController = require "./server/extensionController.coffee"

    # Servers any request about the print view, like showing items for print.
    PrintController     = require "./server/printController.coffee"


    # Create instances from controllers
    new EntityController    app
    new ItemController      app
    new ExtensionController app
    new PrintController     app

    #### Routes

    ensureAuth = (req, res, next) ->
        return next() if req.isAuthenticated()
        console.log 'User not authenticated, redirecting to login form'
        res.redirect '/login'


    # Root route
    app.get '/', ensureAuth, (a...) -> root a...

    app.get '/login', (req, res) ->
        res.render 'login'

    # Entity route
    app.get '/:resource', ensureAuth, (a...) => resource a...

    # Authentication
    app.post '/login', passport.authenticate('basic', {
            session: true
            failureRedirect: '/login'
        }), (req, res) ->
            res.redirect '/'


    #### Functionality

    # Serves request to '/'. Redirection to default host if the request
    # is coming from an old/deprectaed URL.
    root =  (req, res) ->

        # Req is fine, get available entities and render index page.
        getEntities (es) =>

            res.render 'index', entities: es, user: req.user


    # Serves an entity rendering the app with the appropriate collection. It
    # also redirects to a default entity in case of misunderstandings.
    resource = (req, res) ->

        # Entity request from the client
        r = req.params.resource

        # URL used by the client
        u = req.url.split('?')[0]

        # Redirect to /path/. The app requires a URL ending with / to
        # fetch static files correctly. Otherwise the backbone app will
        # append its routes to "path" instead of absolute routing "/".
        return res.redirect "/#{r}/" unless u[u.length-1] is '/'

        # Render the index page if e is a valid entity
        return renderApp(req, res) if isEntity r

        # Response 'ok' for status (NAGIOS)
        return res.send('ok') if r is 'status'

        return res.render 'login' if r is 'login'

        if r is 'logout'
            req.logout()
            return res.redirect '/login'

        # Return list of entities
        if r is 'entities' then return getEntities (e) ->

            res.send e

        # Redirect to default app in any other case
        return redirectToDefault req, res


    # Default redirection to the default entity app
    redirectToDefault = (req, res) ->

        res.redirect "/#{defaultEntity}/"


    # Redirect the client to the correct domain and entity for the team app.
    redirectToDefaultHost = (req, res) ->

        res.redirect "http://#{settings.Web.defaultHost}/#{defaultEntity}/"


    # Render main cube backbone app
    renderApp = (req, res) ->

        name = req.params.resource

        params =  entity: name, entities: entities

        async.parallel [

            (cb) =>
                getJsonFile 'settings.json', name, (settings) =>
                    params.settings = settings
                    cb()

            ,(cb) =>
                getJsonFile 'pane.json', name, (pdata) =>
                    params.pdata = pdata
                    cb()

            ,(cb) =>
                getJsonFile 'etiquettes.json', name, (etiquettes) =>
                    params.etiquettes = etiquettes
                    cb()

            ,(cb) =>
                getJsonFile 'schema.json', name, (schema) =>
                    params.schema = schema
                    cb()

        ], () =>

            res.render 'app', params


    # Read a file and parse it as json, return a json object.
    getJsonFile = (file, entity, cb) =>

        f = "#{__dirname}/extensions/#{entity}/#{file}"

        fs.readFile f, "utf8", (err, data) =>
            return cb({}) if err
            cb JSON.parse data


    # Return templates from an extension
    getTemplates = (req, res, cb) ->

        entity = req.params.resource
        file = "#{__dirname}/extensions/#{entity}/templates"

        res.render file, (err, html) =>
            throw err if err
            cb templates: html


    # Get all available entities along with their settings
    getEntities = (cb) ->

        eFile = "#{__dirname}/#{settings.EntitiesFile}"

        fs.readFile eFile, 'utf-8', (err, d) =>
            throw err if err
            entities = JSON.parse d
            es = []

            async.forEach entities,

                (e, cb) ->
                    getJsonFile 'settings.json', e, (s) ->
                        es.push s
                        cb()

                ,(err) ->
                    throw err if err
                    es = sortEntities es, entities
                    return cb es


    # Sort entity names based on a predefined order
    sortEntities = (entities, orderedNames) =>

        ordered = []

        _.each orderedNames, (name) =>
            _.each entities, (e) =>
                if e.entity is name
                    ordered.push e

        _.each entities, (e) =>
            if orderedNames.indexOf(e.entity) is -1 then ordered.push e

        return ordered


    # Return bool if e is in the entities array from the settings
    isEntity = (e) ->

        return entities.indexOf(e) isnt -1
