#!/usr/bin/env coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
#
# @date: 07/2013

# Cube's nodejs server init

# First things first. Coffee...Script.
require "coffee-script"

# Main server configuration file. Please edit to your needs!
settings        = require "./server.settings.coffee"

express         = require "express"

passport        = require "passport"

flash           = require "connect-flash"

redisStore      = require("connect-redis")(express)

redis           = require "redis"

db              = redis.createClient()

store           = new redisStore client: db

importManager   = require "./server/importManager.coffee"

env             = global.process.env.NODE_ENV

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
require("./server.config.coffee")(app, express, passport, flash, store)

# Main routes file for express
require("./server.routes.coffee")(app, express, passport, flash)


# Listen by default on port 3000. Change on server.settings.coffee.
app.listen settings.Web[env || 'development']?.port || 3000

# Start the import manager.
#importManager.start()
