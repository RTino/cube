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
        uri = api.host + api.version + '/search?jql=project="' + project.key + '"+and+updated>="'+ @lastSync.date + '"&startAt='+offset+'&maxResults=' + limit

        request uri, headers, (err, res, result) =>
            if err?
                return callback err

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

    # Fetch data from JIRA.
    fetch: (callback) =>
        async.each @options.api.projects, (project, cb) =>
            headers = {headers: @options.api.auth}
            uri = @options.api.host + @options.api.version + "/project/" + project

            request uri, headers, (err1, res, body) =>
                if err?
                    return callback err1, null

                body = JSON.parse body
                @projects[project] = {body: body, total: 0, inserted: 0, failed: []}

                getNumberOfIssues body, (err2, total) =>
                    if err2?
                        return callback err2, null

                    @projects[project].total = total

                    if total < 1
                        expresser.logger.info "JiraImporter", "fetch", "Project #{project} is up-to-date!"
                    else
                        getProjectIssues JSON.parse(body), (limit * k) , (err, issue) =>
                            return logger err, true if err?
                            insert issue, (err) =>
                                logger err, true if err?
                        cb()


# EXPORTS
# --------------------------------------------------------------------------
module.exports = exports = new JiraImporter()