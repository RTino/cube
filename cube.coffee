#!/usr/bin/env coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
#
# @date: 11/2012

# Cube's nodejs server init

# First things first. Coffee...Script.
require "coffee-script"

# Main server configuration file. Please edit to your needs!
settings        = require "./server.settings.coffee"

# We all know express, don't we?
express         = require "express"

passport        = require "passport"

# Create express app
app = module.exports.app = express()

# The nodejs process will be called:
process.title   = "cube"

# Jade templates usually live in views/
app.viewsDir    = settings.Paths.viewsDir

# Public static files usually live in public/
app.publicDir   = settings.Paths.publicDir

# We are actually not using this
app.coffeeDir   = settings.Paths.coffeeDir

# Passport authentication middleware initialization
require("./server/passport.coffee")(passport)

# Config file has express settings
require("./server.config.coffee")(app, express, passport)

# Main routes file for express
require("./server.routes.coffee")(app, express, passport)


# Listen usually on port 3000
app.listen settings.Web.defaultPort
