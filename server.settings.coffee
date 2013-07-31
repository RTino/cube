# Cube's nodejs basic server settings

ServerSettings = ->

    #### Web server settings
    # Define web server settings on different environments like development,
    # staging, production. Set the desired environment with NODE_ENV env var.
    # Default port is 3000.
    Web:

        development:

            port: 3000

        production:

            port: 34225

    #### Authentication settings
    # Available authentication mechanisms are basic and ldap.
    # Basic authentication is Basic HTTP Authentication strategy that
    # matches credentials against an array of plain text user entries.
    # Add your users to the file .htpasswd. Example:
    #
    # Authentication:
    #   strategy: 'basic'
    #
    # LDAP authentication accepts an options object where you can specify your
    # ldap settings. A params (parameters) object allows you to specify
    # passportjs options. A verify call is used to check API points, which
    # normally in case of not authenticated request it responds with a 403.
    # On the other hand a toLogin call is used for client end points and
    # redirects to the login page when required. Entity property allows you
    # to specify an entity where the profiles of your users are stored. Usually
    # the 'team' entity is used for that.
    #
    # Authentication:
    #   strategy: 'ldap'
    #   options:
    #            url             : 'ldaps://ldap.example.com:636'
    #            adminDn         : 'uid=myadminusername,ou=users,o=example.com'
    #            adminPassword   : 'mypassword'
    #            searchBase      : 'ou=users,o=example.com'
    #            searchFilter    : '(uid={{username}})'
    #   params:
    #            failureRedirect : '/login'
    #            failureFlash    : yes
    #   verify: (req, res, next) ->
    #            return next() if req.isAuthenticated()
    #            res.statusCode = 403
    #            res.send 'unauthorized'
    #   toLogin: (req, res, next) ->
    #            return next() if req.isAuthenticated()
    #            req.flash 'target', req.url
    #            res.redirect '/login'
    #   entity:  "team"
    #
    # Avoid any authentication by setting strategy to 'none'

    Authentication:
        strategy: 'none'


    #### Nodejs Paths
    Paths:

        # Path to the Jade templates directory
        viewsDir: __dirname + "/views/"

        # Path to the public static folder
        publicDir: __dirname + "/public/"

        # Path to the coffee files
        coffeeDir: __dirname + "/coffee/"


    #### Entities json file
    EntitiesFile: 'entities.json'


    #### Entity creation defaults.
    # Modify only if you know what you're doing.
    # This is not the place to configure your entity. Check entities/ dir.


    # Default application settings
    Application:

        description : "Dynamically generated entity"
        itemType    : [ "item", "items"]
        separator   : "/"
        view        : "list"
        sort        : "name:asc"
        rows        : 50


    # Used when creating a new entity from the CSV importer.
    # To configure your entitie's database, edit
    # entities/<entity name>/db.json
    Default:

        # Default database settings.
        Database:

            production:
                host        : 'localhost'
                port        : '38730'
                path        : '/cube-solr'
                method      : 'GET'
                dataRoot    : "default"

            development:
                host        : 'localhost'
                port        : '38730'
                path        : '/cube-solr'
                method      : 'GET'
                dataRoot    : "default"


    # Default parameters of a field for solr's schema
    SchemaField:

        index       : yes
        search      : yes
        thumbnail   : yes
        multivalue  : yes


    # Type of fields on a suffix. i.e. team-f from a csv or json file
    Suffix:

        f: 'facet'
        i: 'img'
        e: 'email'
        s: 'skype'
        d: 'date'


#### Singleton implementation
ServerSettings.getInstance = ->
    @instance = new ServerSettings() if not @instance?
    return @instance

module.exports = ServerSettings.getInstance()
