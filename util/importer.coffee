#!/usr/bin/env coffee
#
#### Cube's Importer template
#
# $ coffee util/importer.coffee [-q]
#
# This is a general importer script that offers some functionality for you
# to extend it and import your own data into the solr database.
#
# If you have a CSV file, place it in the util/ directory together with this
# script, or modify csvfile variable to point to it.

#### Configuration variables
# Please edit to suit your usecase.

entity      = ""                        # Fill with the name of your entity
solrCore    = entity                    # Replace if different than entity
csvfile     = "./util/data.csv"         # CSV file with your data
sepchar     = ";"                       # CSV separator character
mvchar      = ","                       # Multiple value fields in yoru csv
                                        # must be character separated strings.
                                        # Usually commas are used.

dbSettings =
    host: "localhost"                   # host domain or ip address
    port: "38730"                       # port, normally 38730.
    core: solrCore                      # core name, normally equal entity name
    path: "/cube-solr"                  # solr path, normally /cube-solr
    autoCommit: yes                     # Autocommit, yes commits on every request


#### Script starts here...

# Requirements

require "coffee-script"

_       = require "underscore"
fs      = require "fs"
async   = require "async"
request = require "request"
solr    = require "solr-client"

SolrManager = require '../server/solrManager'
solrManager = new SolrManager


#### Functionality...
# Main function will start script, called at bottom of script.

# Log function
log = (arg...) -> console.log(arg...) if verbose

# Avoid logging if started with -q parameter.
verbose = no if process.argv.indexOf('-q') isnt -1

# Creating a solr client
solrClient = solr.createClient dbSettings.host,
  dbSettings.port, dbSettings.core, dbSettings.path

# Commit normally set to false, only to commit changes at the end.
solrClient.autoCommit = dbSettings.autoCommit

# CSV Headers
keys = []

# Deletes all data on Solr
deleteData = (cb) ->

    query = solrClient.createQuery()
        .q("*:*")
        .start(0)
        .rows(1000)

    solrClient.deleteByQuery "*:*", (err, result) ->
        log 'Deleted all entries'
        cb()

# Iterates through your json data, creating items and adding them to solr
addData = (data) ->
        i = 0

        log 'Adding entries...'

        # replace async.each for async.eachSeries if your solr can't handle
        # so many parallel connections.
        async.each data,
            (item, cb) ->

                # Appends a suffix to each field, required by solr's dynamic
                # schema. i.e. -s for strings.
                item = solrManager.addObjSuffix entity, item

                # Add a hashed id
                item.id = generateId()

                solrClient.add item, (err, result) ->
                    throw err if err
                    i++
                    cb()

            , (err) ->
                throw err if err
                log 'Added ', i, ' entries.'
                solrClient.commit () ->
                    date = new Date()
                    log date.toString(), "- Data imported"

# Read CSV File
readCSVFile = (cb) ->
    fs.readFile csvfile, 'utf-8', (err, data) ->
        throw err if err
        cb data

# CSV 2 Json parser
# Forms a JSON array of objects from a CSV file based on the entitie's schema.
# Each line in the CSV is transformed into one json object.
csv2json = (csvdata) ->
    lines = csvdata.split '\n'
    header = lines[0].split sepchar
    lines = lines.slice(1)

    arr = []
    _.each lines, (line) ->
        item = {}
        _.each line.split(sepchar), (field, index) ->
            item[header[index]] = field
        arr.push item
    arr

# Create a hash to be used as an id
generateId = () ->
    chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    today = new Date()
    result = today.valueOf().toString 16
    result += chars.substr Math.floor(Math.random() * chars.length), 1
    result += chars.substr Math.floor(Math.random() * chars.length), 1
    return result

# Main function
main = () =>

    readCSVFile (csvdata) ->
        jsonData = csv2json csvdata

        deleteData () =>
            addData jsonData

# Start importing
main()
