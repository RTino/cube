#!/usr/bin/env coffee

require 'coffee-script'
ENV = global.process.env.NODE_ENV || 'development'
showLog = yes
entity = 'jira'
limit = 100
insertedProjects = []

fs = require 'fs'
_ = require 'underscore'
request = require 'request'
async = require "async"
solr = require 'solr-client'
SolrManager = require '../server/solrManager'
solrManager = new SolrManager(entity)

schema = require '../entities/' + entity + '/schema.json'
settings = require '../entities/' + entity + '/settings.json'
map = require './importer-jira-settings.json'
db = require '../entities/' + entity + '/db.json'

unless settings.jiraApi
    logger 'JIRA API config missing...', false
    return

api = settings.jiraApi if settings.jiraApi?
api.host += 'rest/api/' # add static part of URL to host
lockFilePath = settings.lockFilePath[ENV]
lastSyncFilePath = settings.lastSyncFilePath[ENV]

fetch = () ->
    #check if fatch() running
    return logger '\nUpdating is in progress...', false if lock()

    lock true

    fs.writeFileSync lastSyncFilePath, '{"date": "1970-01-01 00:00"}' unless fs.existsSync lastSyncFilePath

    @lastSync = JSON.parse fs.readFileSync lastSyncFilePath
    # this object should be used for storing information about projects
    @projects = {}

    @start = Date.now()
    #get basic information about projects (URL, key, name, description etc...)
    async.each api.projects,
    (project, callback) ->
        logger 'Processing of ' + project + ' project started...', false
        request api.host + api.version + '/project/' + project,
            headers : api.auth,
            (err, res, body) =>
                return logger err, true if err?

                @projects[project] = {total: 0, inserted: 0, failed: []}
                getNumberOfIssues JSON.parse(body), (err, total) =>
                    if total < 1
                        logger 'Project ' + project + ' is up to date!', false
                        insertedProjects.push project
                        lock false if lock()
                    else
                        @projects[project].total = total
                        n = Math.ceil (total / limit)

                        async.each [0..n], (k, cb) =>
                            getProjectIssues JSON.parse(body), (limit * k) , (err, issue) =>
                                return logger err, true if err?
                                insert issue, (err) =>
                                    logger err, true if err?
                            cb()
                    callback()
#check the number of issues
getNumberOfIssues = (project, callback) ->
    request api.host + api.version + '/search?jql=project="' + project.key + '"+and+updated>="'+ @lastSync.date + '"&startAt=0&maxResults=1',
        headers : api.auth,
        (err, res, result) =>
            return callback err, true if err?

            callback err, JSON.parse(result).total

#get all issues for project
getProjectIssues = (project, offset, callback) ->
    request api.host + api.version + '/search?jql=project="' + project.key + '"+and+updated>="'+ @lastSync.date + '"&startAt='+offset+'&maxResults=' + limit,
        headers : api.auth,
        (err, res, result) =>
            return callback err if err?

            result = JSON.parse(result)
            issues = result.issues

            async.each issues,
            (issue, cb) ->

                getIssue issue, (err, data) =>
                    return callback err if err?

                    @projects[project.key].failed.push issue unless data.key

                    formatIssue data, (err, formatedIssue) =>
                        return callback err if err?

                        callback null, formatedIssue

                    cb()


#get all information about issue
getIssue = (issue, callback) ->

    request issue.self + '?expand=renderedFields',
        headers : api.auth,
        (err, res, body) =>
            return callback err if err?

            callback err, JSON.parse(body)

#adjust issue format to schema format
formatIssue = (issue, callback) ->

    formated = {}
    try
        schema.forEach (field, key) =>
            if map[field.id]?
                value = false

                map[field.id].root.forEach (item) =>
                    if value
                        value = if value[item]? then value[item] else false
                    else
                        value = if issue[item]? then issue[item] else false

                if map[field.id].sub? and map[field.id].sub != false and value != false
                    value = getSubValue value, map[field.id]

                if field.type == 'facet' and value != false
                    value = formatFacet value

                if field.type == 'date' and value != false
                    d = new Date(value)
                    value = d.toISOString()

                formated[field.id] = value if value != false
    catch error
        return callback error, null if error?

    callback null, formated

#getting issue attribut sub-value
getSubValue = (value, field) ->
    subValue = if typeof subField == 'object' then getComplexSubValue(value, field) else value[field.sub] || false
    subValue

#formating complex issue attributes
getComplexSubValue = (value, field) ->
    arrayOfSubElements = []

    value.forEach (subitem) =>
        subValue = false

        field.sub.forEach (item) =>
            if subValue
                subValue = subValue[item] if subValue[item]?
            else
                subValue = value[item] if subitem[item]?

        arrayOfSubElements.push subValue if subValue
    arrayOfSubElements || false

#formating facet issue attributes
formatFacet = (facet) ->
    if typeof facet != 'object'
        formated = solrManager.formHierarchyArray facet, settings.separator
    else
        formated = []
        facet.forEach (item) =>
            solrManager.formHierarchyArray(item, settings.separator).forEach (i) =>
                formated.push i

    formated
#update info about last synchronization
updateLastSync = () ->
    t = new Date()
    y = t.getFullYear()
    m = if t.getMonth().toString().length == 2 then t.getMonth() else '0' + (t.getMonth() + 1)
    d = if t.getDate().toString().length == 2 then t.getDate() else '0' + t.getDate()
    h = if t.getHours().toString().length == 2 then t.getHours() else '0' + t.getHours()
    _m = if t.getMinutes().toString().length == 2 then t.getMinutes() else '0' + t.getMinutes()

    date = y + '-' + m + '-' + d + ' ' + h + ':' + _m

    fs.writeFile lastSyncFilePath, JSON.stringify {date:date}

#insert issue
insert = (issue, callback) ->
    project = issue.projectKey

    #issue = solrManager.addObjSuffix issue

    # Concatenating all field's values into one string field for searches
    setSearchField issue

    solrManager.addItems issue,
    (result) ->
        #return callback err if err?

        @projects[project].inserted++

        if @projects[project].total == @projects[project].inserted + @projects[project].failed.length

            time = Date.now()
            logger '\nProccessing of the ' + project + ' project finished ->', false
            logger '\tInserted: ' + @projects[project].inserted + ' issues', false
            logger '\tFailed: ' + @projects[project].failed.length, false
            logger '\tTime spent: ' + ((time - @start) / 1000) + ' sec', false

            if @projects[project].failed.length > 0
                insertFaildIssues project, (err) =>
                    return callback err if err?
                    insertedProjects.push project

                    if insertedProjects.length == api.projects.length and @projects[project].failed.length == 0
                        updateLastSync()
                        insertedProjects = []
                        lock false if lock()
            else
                insertedProjects.push project

                if insertedProjects.length == api.projects.length and @projects[project].failed.length == 0
                    updateLastSync()
                    insertedProjects = []
                    lock false if lock()

#inserting unsuccessfully inserted issues
insertFaildIssues = (project) ->
    issues = @projects[project].failed
    @projects[project] = {total: issues.length , inserted: 0, failed: []}

    async.each issues,
    (issue, cb) ->
        getIssue issue, (err, data) =>
            if err?
                @projects[project].failed.push issue
                logger err, true
                return
            try
                @projects[project].failed.push issue unless data.key
            catch error
                logger 'JIRA importer crashed :(', true

            formatIssue data, (err, formatedIssue) =>
                return logger err, true if err?

                insert formatedIssue, (err) =>
                    return logger err, true if err?
            cb()

#set search field
setSearchField = (issue) ->
    sf = []
    _.each issue, (value, key) ->
        return unless value
        value = value.join(' ') if typeof value is typeof []
        value = value.split('-').join(' ') if key is 'id'
        sf.push value if value
    issue['search-s'] = sf.join ' '


fetch()
