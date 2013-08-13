# JIRA IMPORTER
# --------------------------------------------------------------------------
# Imports data from a JIRA server to Cube.

BaseImporter = require "../baseImporter.coffee"

class JiraImporter extends BaseImporter

    async = require "async"
    expresser = require "expresser"
    request = require "request"

    # Holds a copy of projects to be imported.
    projects: {}


    # IMPLEMENTATION
    # ----------------------------------------------------------------------

    # Get all issues related to the passed project.
    getProjectIssues = (project, offset, callback) =>
        headers = {headers: @options.api.auth}
        uri = @options.api.host + @options.api.version + '/search?jql=project="' + project.key + '"+and+updated>="'+ @lastSync.date + '"&startAt='+offset+'&maxResults=' + limit

        request uri, headers, (err1, res, result) =>
            if err1?
                return callback err1

            result = JSON.parse result
            issues = result.issues

            async.each issues, (issue, cb) =>
                getIssue issue, (err2, data) =>
                    if err2?
                        return callback err2

                    @projects[project.key].failed.push issue unless data.key

                    formatIssue data, (err, formatedIssue) =>
                        return callback err if err?

                        callback null, formatedIssue

                    cb()

    # Helper to get number of issues for a particular project.
    getNumberOfIssues = (project, callback) =>
        headers = {headers: @options.api.auth}
        uri = @options.api.host + @options.api.version + '/search?jql=project="' + project.key + '"+and+updated>="'+ @lastSync.date + '"&startAt=0&maxResults=1'

        request uri, headers, (err, res, result) =>
            if err?
                return callback err

            callback null, JSON.parse(result).total

    # Helper to get relevant data about an issue.
    getIssue = (issue, callback) =>
        headers = {headers: @options.api.auth}

        request issue.self + "?expand=renderedFields", headers, (err, res, body) =>
            if err?
                return callback err

            callback err, JSON.parse(body)

    # Helper to format the JIRA issue before sending to Solr.
    formatIssue = (issue, callback) =>
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
        if typeof facet != "object"
            formatted = solrManager.formHierarchyArray facet, settings.separator
        else
            formatted = []
            facet.forEach (item) => solrManager.formHierarchyArray(item, settings.separator).forEach (i) => formatted.push i

        return formatted

    # Fetch data from JIRA.
    fetch: (callback) =>
        async.each @options.api.projects, (project, cb) =>
            headers = {headers: @options.api.auth}
            uri = @options.api.host + @options.api.version + "/project/" + project

            request uri, headers, (err1, res, body) =>
                if err?
                    return callback err1

                body = JSON.parse body
                @projects[project] = {body: body, total: 0, inserted: 0, failed: []}

                getNumberOfIssues body, (err2, total) =>
                    if err2?
                        return callback err2, null

                    @projects[project].total = total

                    if total < 1
                        expresser.logger.info "JiraImporter", "fetch", "Project #{project} is up-to-date!"
                    else
                        async.each [0..n], (k, cb) =>
                            getProjectIssues body, (limit * k) , (err3, issue) =>
                                if err3?
                                    return callback err3

                                insert issue, (err) =>
                                    logger err, true if err?
                            cb()


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = new JiraImporter()