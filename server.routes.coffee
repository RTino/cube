####
# Cube Nodejs routes
# server.routes.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
####

module.exports = (app, express, passport) ->

    #### Requirements

    _           = require "lodash"
    fs          = require "fs"
    async       = require "async"


    # Server and default entity settings
    settings = require "#{__dirname}/server.settings.coffee"

    # Authentication strategy setting
    strategy = settings.Authentication.strategy

    # Ensure authentication by checking request. Return 403 if not.
    auth =  settings.Authentication.verify || (req, res, next) ->
        return next() unless settings.Authentication.strategy
        return next() if settings.Authentication.strategy is 'none'
        return next() if req.isAuthenticated()
        res.statusCode = 403
        res.send 'Unauthorized'

    # Ensure authentication by checking request. Redirect to /login if not.
    toLogin = settings.Authentication.toLogin || (req, res, next) ->
        return next() unless settings.Authentication.strategy
        return next() if settings.Authentication.strategy is 'none'
        return next() if req.isAuthenticated()
        req.flash 'target', req.url
        res.redirect '/login'

    # Apply strategy when posting credentials
    check = passport.authenticate(strategy, settings.Authentication.params)

    # List of available entities
    entities = require "./#{settings.EntitiesFile}"

    # Default entity is the first entity defined in the entities array
    defaultEntity = entities[0]

    # Application themes
    themes = require './themes.json'

    # Controllers

    # Serves any request about entities, like getting its collection
    EntityController    = require "./server/entityController.coffee"

    # Serves any request about an item, like querying by ID.
    ItemController      = require "./server/itemController.coffee"

    # Servers any request about extension administration, like creating one.
    ExtensionController = require "./server/extensionController.coffee"

    # Servers any request about the print view, like showing items for print.
    PrintController     = require "./server/printController.coffee"

    # Solr utility methods
    SolrManager         = require './server/solrManager.coffee'

    # Create instances from controllers
    new EntityController    app, auth, entities
    new ItemController      app, auth
    new ExtensionController app, auth
    new PrintController     app, auth


    #### Routes

    # Root route
    app.get '/',            toLogin,    (a...) -> root          a...

    # List of available entities with settings
    app.get '/entities',    auth,       (a...) -> listEntities  a...

    # Alive Response ({status:ok})
    app.get '/status',                  (a...) -> status        a...

    # Render login page
    app.get '/login',                   (a...) -> login         a...

    # Receive user credentials and authenticate
    app.post '/login',      check,      (a...) -> logged        a...

    # Logs Out a user and redirects to login page
    app.get '/logout',      auth,       (a...) -> logout        a...

    # Render the cube app for a specific entity
    app.get '/:entity',     toLogin,    (a...) => toEntity      a...


    #### Functionality

    # Serves request to '/'. Redirection to default host if the request
    # is coming from an old/deprectaed URL.
    root =  (req, res) ->

        # Req is fine, get available entities and render index page.
        res.render 'index', entities: getEntities(), user: req.user


    # Serves an entity rendering the app with the appropriate collection. It
    # also redirects to a default entity in case of misunderstandings.
    toEntity = (req, res) ->

        # Entity request from the client
        r = req.params.entity

        # URL used by the client
        u = req.url.split('?')[0]

        # Redirect to /path + / (trailing slash).
        # The app requires a URL ending with / to fetch static files correctly.
        # Otherwise the backbone app will append its routes to "path"
        # instead of absolute routing "/".
        return res.redirect "/#{r}/" unless u[u.length-1] is '/'

        # Render the index page if e is a valid entity
        return renderApp(req, res) if isEntity r

        # Redirect to index page if entity doesn't exists
        res.redirect '/'


    # List of available entities
    listEntities = (req, res) ->
        res.send getEntities()


    # Status alive response returns a JSON { "status": "ok" } object.
    status = (req, res) ->

        res.send status: 'ok'

    # Render login page
    login = (req, res) ->

        res.render 'login', flash: req.flash()

    # Redirect authenticated user to a specifc address from the querystring
    logged = (req, res) ->

        return res.redirect req.query.redirect if req.query.redirect

        res.redirect '/'

    # Log Out a user and redirect to index page (usually redir to /login)
    logout = (req, res) ->

        req.logout()

        res.redirect '/'


    # Render main cube backbone app
    renderApp = (req, res) ->

        name = req.params.entity

        user = {}
        user = mail: req.user?.mail

        params =  entity: name, entities: [], themes: themes, user: user

        # Read all configuration files from filesystem
        async.parallel [

            (cb) =>
                params.entities = getEntities()
                cb()

            (cb) =>
                params.settings = require "./entities/#{name}/settings.json"
                cb()

            ,(cb) =>
                getJsonFile 'pane.json', name, (pdata) ->
                    params.pdata = pdata
                    cb()

            ,(cb) =>
                getJsonFile 'etiquettes.json', name, (etiquettes) ->
                    params.etiquettes = etiquettes
                    cb()

            ,(cb) =>
                params.schema = require "./entities/#{name}/schema.json"
                cb()

            ,(cb) =>
                return cb() unless strategy is 'ldapauth' and req.user

                authEntity = settings.Authentication.entity

                eSettings = require "./entities/#{authEntity}/settings.json"

                return cb() unless eSettings.authentication

                { entityField, ldapField } = eSettings.authentication

                getLinkedEntityItem authEntity, entityField, req.user[ldapField], (user) =>
                    params.user = user
                    cb()

        ], () =>

            # Render backbonejs app
            res.render 'app', params


    # Get an item from a specific entity, based on 1 key/value pair criteria.
    getLinkedEntityItem = (entity, key, value, cb) =>

        solrManager = new SolrManager entity
        key = solrManager.addSuffix key
        db = solrManager.createClient()

        query = db.createQuery()
            .q("#{key}:#{value}")
            .start(0)
            .rows(1000)

        db.search query, (err, result) ->
            throw err if err
            docs = []
            _.each result.response?.docs, (doc) ->
                docs.push solrManager.removeSuffix doc
            docs = docs[0] if docs.length
            cb docs


    # Read a file and parse it as json, return a json object.
    getJsonFile = (file, entity, cb) =>

        f = "#{__dirname}/entities/#{entity}/#{file}"

        fs.readFile f, "utf8", (err, data) =>
            return cb({}) if err
            cb JSON.parse data


    # Return templates from an entity
    getTemplates = (req, res, cb) ->

        entity = req.params.entity
        file = "#{__dirname}/entities/#{entity}/templates"

        res.render file, (err, html) =>
            throw err if err
            cb templates: html


    # Get all available entities along with their settings
    getEntities = () ->
        es = []
        _.each entities, (e) ->
            esettings = require "./entities/#{e}/settings.json"
            schema = require "./entities/#{e}/schema.json"
            esettings.schema = schema
            es.push esettings
        es = sortEntities es, entities
        es


    # Sort entity names based on a predefined order
    sortEntities = (entities, orderedNames) =>
        ordered = []
        _.each orderedNames, (name) =>
            _.each entities, (e) =>
                if e.entity is name
                    ordered.push e
        _.each entities, (e) =>
            if orderedNames.indexOf(e.entity) is -1 then ordered.push e
        ordered


    # Return bool if e is in the entities array from the settings
    isEntity = (e) ->
        return entities.indexOf(e) isnt -1
