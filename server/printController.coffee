###
# PrintController.coffee
#
# Renders the print view
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# List of available entities
entities = require "#{__dirname}/../entities.json"

class PrintController

    module.exports = PrintController


    # Print route
    constructor: (app, auth) ->

        app.get "/:entity/print", auth, (a...) => @print a...


    # Render print view
    print: (req, res) ->

        entity = req.params.entity

        return res.send 404 if entities.indexOf(entity) is -1

        res.render 'printIndex', entity: entity
