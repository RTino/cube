#### Cube's nodejs authentication with Passportjs
#
# Passport module initialization

_               = require 'underscore'
bcrypt          = require 'bcrypt'

users           = require './../.htpasswd.json'

passportHttp    = require('passport-http')
BasicStrategy   = passportHttp.BasicStrategy

passportLdap    = require('passport-ldapauth')
LdapStrategy    = passportLdap.Strategy

LdapAuth        = require 'ldapauth'

authSettings    = require('../server.settings.coffee').Authentication

strategy        = authSettings.strategy


# Basic HTTP Authentication, clear text passwords matched agains users array.
basicStrategy = new BasicStrategy {}, (uname, pword, cb) ->

    findById = (id, cb) ->
        user = null
        _.each users, (u) ->
            user = u if u.id is id
        cb null, user

    findByUsername = (name, cb) ->
        user = null
        _.each users, (u) ->
            user = u if u.username is name
        cb null, user

    findByUsername uname, (err, user) ->

        return cb err if err
        return cb null, no unless user
        return cb null, no unless pword is user.password

        cb null, user

# Bassic HTTP Authentication LDAP Binded.
ldapStrategy = new BasicStrategy {}, (uname, pword, cb) ->

    ldapauth = new LdapAuth authSettings.options

    ldapauth.authenticate uname, pword, (err, user) ->
        return cb null, no if err
        return cb null, no unless user
        cb null, user

# List of avialble auth strategies
strategies =

    basic: basicStrategy

    ldap: ldapStrategy

selectedStrategy = strategies[strategy]

module.exports = (passport) ->

    passport.use selectedStrategy if selectedStrategy

    passport.serializeUser (user, cb) ->
        cb null, user

    passport.deserializeUser (obj, cb) ->
        cb null, obj
