#### Cube's nodejs authentication with Passportjs
#
# Passport module initialization

_               = require 'lodash'
SolrManager     = require './solrManager.coffee'

passportHttp    = require('passport-http')
BasicStrategy   = passportHttp.BasicStrategy

passportLdap    = require('passport-ldapauth')
LdapStrategy    = passportLdap.Strategy

LdapAuth        = require 'ldapauth'

authSettings    = require('../server.settings.coffee').Authentication


# Basic HTTP Authentication, clear text passwords matched agains users array.
basicStrategy = new BasicStrategy {}, (uname, pword, cb) ->

    users = require './../.htpasswd.json'

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

ldapStrategy = new LdapStrategy server: authSettings.options, (user, done) ->
    console.log 'user authenticated'
    done null, user


# List of avialble auth strategies
strategies =
    basic: basicStrategy
    ldapauth: new LdapStrategy {server: authSettings.options}, (profile, done) ->

        solrManager = new SolrManager 'team'

        solrManager.getItemsByProp 'email', profile.mail, (err, data) ->
            console.log err if err
            profile.cubeId = data.pop()?.id
            done null, profile


module.exports = (passport) ->

    return unless strategies[authSettings.strategy]

    passport.use strategies[authSettings.strategy]

    passport.serializeUser (user, cb) ->
        cb null, user

    passport.deserializeUser (obj, cb) ->
        cb null, obj
