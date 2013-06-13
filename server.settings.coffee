# Cube's nodejs basic server settings

ServerSettings = ->

    #### Web server settings
    Web:

        # Default hostname of your project, please edit.
        defaultHost: 'localhost'

        # Port to run your nodejs service, i.e. 3000.
        defaultPort: 3000


    #### Default settings.
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

    # Default application settings
    Application:

        description : "Dynamically generated entity"
        itemType    : [ "item", "items"]
        separator   : "/"
        view        : "list"
        sort        : "name:asc"
        rows        : 50


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
