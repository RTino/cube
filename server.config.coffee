#### Cube's nodejs configuration
#
# Basic configuration options for the nodejs server.

module.exports = (app, express, passport, flash, store) ->

    app.configure ->

        # Stylus and CoffeeScript files are in assets/{css,js}
        ConnectAssets = (require "connect-assets") build: yes, minifyBuilds: no

        # Jade template engine settings. Find them at views/
        app.set "views", app.viewsDir
        app.set "view engine", "jade"
        app.set "view options", { layout: false }

        # Express static content. Located in public/
        app.use express.static "./public", maxAge: 0
        app.use(express.bodyParser({uploadDir:"./"}))
        app.use ConnectAssets

        # Express session
        app.use express.cookieParser()
        app.use express.session
            secret: 'cubic cat'
            cookie:
                maxAge: 86400000
            store: store
        app.use flash()

        # Passport authentication middleware
        app.use passport.initialize()
        app.use passport.session()


    # Development environment settings
    app.configure "development", ->

        app.use express.errorHandler dumpExceptions: true, showStack: true
