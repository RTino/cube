#### Cube's nodejs authentication with Passportjs
#
# Passport module initialization

_               = require 'underscore'
bcrypt          = require 'bcrypt'

users           = require './../.htpasswd.json'

passportHttp    = require('passport-http')
BasicStrategy   = passportHttp.BasicStrategy

salt            = bcrypt.genSaltSync 10

passportLdap    = require('passport-ldapauth')
LdapStrategy    = passportLdap.Strategy

ldapOPTS =
    server:
        url: 'ldap://'
        adminDn: ''
        adminPassword: ''
        searchBase: ''
        searchFilter: '(uid={{username}})'

module.exports = (passport) ->

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

    ###
    passport.use new BasicStrategy {}, (uname, pword, cb) ->
        findByUsername uname, (err, user) ->
            return cb err if err
            return cb null, no unless user
            return cb null, no unless bcrypt.compareSync pword, user.password
            cb null, user
    ###

    passport.use new LdapStrategy ldapOPTS

    passport.serializeUser (user, cb) ->
        cb null, user

    passport.deserializeUser (obj, cb) ->
        cb null, obj
