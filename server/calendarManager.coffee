###
# CalendarManager.coffee
#
# Calendar Manager provides functions to create .ics files
#
# @author: Ivan Kamatovic <ivan.kamatovic@zalando.de>
###

_           = require 'lodash'
async       = require 'async'
SolrManager = require './solrManager.coffee'
moment      = require 'moment'

class CalendarManager
    constructor: (settings) ->
        # Template of ics file
        @ics = 'BEGIN:VCALENDAR\n' +
        'PRODID:Cube App\n' +
        'VERSION:2.0\n' +
        'CALSCALE:GREGORIAN\n' +
        'METHOD:PUBLISH\n' +
        '#events#' +
        'END:VCALENDAR'

        # Date of current active user
        @user = settings.user or null

        # Contains the values ​​of the selected items
        @selection = settings.selection or null

        # New instance of SolrManager
        @sm = new SolrManager(settings.entity)

        # Entity Schema
        @schema = require "../entities/#{settings.entity}/schema.json"

        # Entity settings
        @entitySettings = require "../entities/#{settings.entity}/settings.json"

        # Claendar settings
        @settings = @entitySettings.ics


    # Get .ics file with all user or selected events
    get: (cb) =>
        # Get events by required criteria
        @events (events) =>
            e = ''

            # Generate events string
            _.each events, (event) =>

                # Fill template with values of each event
                e += @generate(event)

            # Fill ics template with generated string of events
            @ics = @ics.replace('#events#', e)

            cb(@ics)

    # Get events from Solr
    events: (cb) =>

        # Get selected events
        if @selection?
                # Querying Sorl for events
                @sm.getItemById @selection , (err, r) =>
                    throw err if err

                    # Get data of foreign keys
                    @external r, (d) =>
                        cb(d)

        # Get all events of active user
        else if @user?
            # New SolrManager instance for team entity
            sm = new SolrManager('team')

            # Querying Sorl for user information
            sm.getItemsByProp 'email', @user.mail, (err, result) =>
                throw err if err
                return unless result[0]?.id?

                # Querying Sorl for events by active user ID
                @sm.getItemsByProp 'subscription', result[0].id, (err, r) =>
                    throw err if err
                    # Get data of foreign keys
                    @external r, (d) =>
                        cb(d)
    # Get data of FK and replace current value of events with them
    external: (events, cb) =>
        # Get all fields from schema which required data from other Cube entity
        fields = @sm.schema.getFieldsByType 'clink'

        # Return current events if there is no filed which require external data
        return cb(items) if fields.length is 0

        # Number of events
        el = events.length

        # Number of fields
        fl = fields.length

        # Event counter
        e = 0

        # Iterate through events
        async.eachSeries events, (event, c) =>

            # Iterate through fields
            _.each fields, (field, f) =>
                # Create new intance of SolrManager for entity of FK filed
                sm = new SolrManager field.entity

                # Querying Sorl for FK filed data
                sm.getItemById event[field.id], (err, r) =>

                    throw err if err

                    # Replace FK with real data
                    event[field.id] = r if r?

                    # If it is last filed
                    if fl is f + 1

                        # Call callback fn if it is last event
                        cb(events) if el is e + 1

                        # Increment events counter
                        e += 1

                        # Call Async callback to continue iteration
                        c()

    # Fill event template with real event data
    generate: (attributes) =>

        # Format event attributes according before file template
        attributes = @format(attributes)

        # Event template
        e = 'BEGIN:VEVENT\n' +
        'UID:#uid#\n' +
        'DTSTART:#start#\n' +
        'DTEND:#end#\n' +
        'DTSTAMP:#start#\n' +
        '#organizer#\n' +
        'DESCRIPTION:#description#\n' +
        'LOCATION:#location#\n' +
        'SEQUENCE:0\n' +
        'STATUS:CONFIRMED\n' +
        'SUMMARY:#summary#\n' +
        'TRANSP:OPAQUE\n' +
        'END:VEVENT\n'

        # Fill template with data
        _.each attributes, (val, key) =>
            e = e.replace(new RegExp("##{key}#", 'g'), val)

        return e

    # Format values of event according to ics standards (HARDOCDED!!!)
    format: (attributes) =>

        # Skeleton of formated object
        formated =
            start: ''
            end: ''
            attendee: ''
            organizer: ''
            location: ''
            summary:  ''
            description: ''
            uid: ''

        # List of functions by type of field
        fn =
            string: @fieldString
            facet: @fieldFacet
            clink: @fieldClink

        _.each formated, (val, key) =>
            # If value of formated filed is in calendar settings
            if @settings[key]?

                # Create f (field object) which contains all information about field
                f = {}
                # Adding properties from settings
                f = if typeof @settings[key] is 'object' then @settings[key] else field: @settings[key]
                # Set id
                f.id = if typeof f.field is 'object' then f.field.name else f.field
                # Set default type
                f.type = 'string'

                # Get type of field from entity schema
                _.each @schema, (sf) =>
                    if sf.id is f.id
                        f.type = if sf.type? then sf.type else 'string'

                # Assign the method to "vfn" (value function) according to field type
                vfn = fn[f.type] or fn.string

                # Get value for calendar filed
                v = vfn(f, attributes)

                # Store formated value
                formated[key] = @[key](f, v) if @[key]?

        formated

    # Get value of string field
    fieldString: (f, attributes) ->
        # Get filed name
        field = if typeof f.field is 'string' then f.field else f.field.name

        # Get value
        val = attributes[field] or f.default or ''

    # Get value of cLink field
    fieldClink: (f, attributes) ->
        # Get filed name
        field = if typeof f.field is 'string' then f.field else f.field.name

        # Get value
        val = attributes[field] or f.default or ''

    # Get value of facet field
    fieldFacet: (f, attributes) ->
        # Get filed name
        field = if typeof f.field is 'string' then f.field else f.field.name

        # Set value or use default value
        val = (if attributes[field]? and attributes[field].length > 0 then attributes[field] else null) or f.default or ''

        # Because facet is array of strings, the last element contains value
        if val instanceof Array then val.pop() else val

    # Format start attribute of ics
    start: (f, start) =>
        start = @preparation('start', f, start)

        if start then moment(start).format('YYYYMMDDTHHmmss') else ''


    # Format start attribute of ics
    end: (f, end) =>
        end = @preparation('end', f, end)
        if end then moment(end).format('YYYYMMDDTHHmmss') else ''

    # Format attendee attribute of ics
    attendee: (f, attendees) =>
        attendees = @preparation('attendee', f, attendees)

        # Subscriber template
        template = 'ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=#name#;X-NUM-GUESTS=0:mailto:#email#\n'
        subscribers = ''

        # Iterate through subscribers and append subscriptions with filled subscriber template
        _.each attendees, (a) =>
            subscribers += template.replace(new RegExp('#name#', 'g'), a.name).replace(new RegExp('#email#', 'g'), a.email)

        return subscribers

    # Format organizer attribute of ics
    organizer: (f, person) ->
        person = @preparation('organizer', f, person)

        template = 'ORGANIZER;CN=#organizer#:mailto:#email#\n'
        organizer = template.replace(new RegExp('#organizer#', 'g'), person.name).replace(new RegExp('#email#', 'g'), person.email)

    # Format location attribute of ics
    location: (f, location) ->
        location = @preparation('location', f, location)
        if location then location else 'Unknown'

    # Format summary attribute of ics
    summary:  (f, summary) ->
        summary = @preparation('summary', f, summary)
        if summary then summary else ''

    # Format description attribute of ics
    description: (f, description) ->
        description = @preparation('description', f, description)
        if description then description else ''

    # Return ID of course to set on UID
    uid: (f, uid) ->
        uid = @preparation 'uid', f, uid
        if uid then uid else ''

    # Preparing value before format applying
    preparation: (field, params, value) =>
        # In case when filed name from ics settings is string
        # create default config object
        if typeof params.field is 'string'

            if field == 'attendee'
                # Config for attendee field
                params.field = name: params.field, external: { name: 'name', email: 'email', concat: { name:'lastname', email: null } }
            else
                # And config other fields
                params.field = name: params.field, external: { field: null, concat: { field: null,} }

        switch field
            # Method which do formating of "organizer" field expect value which contains name and email params
            # and both of them should be a string values
            when 'organizer'
                if value instanceof Object
                    # New value with name/email params and applying concatenation on default value if that is required by "ics" settings
                    value =
                        name: if value[params.field.external.name]? then value[params.field.external.name] + (if params.field.external.concat.name? and value[params.field.external.concat.name]? then ' ' + value[params.field.external.concat.name] else '') else ''
                        email: if value[params.field.external.email]? then value[params.field.external.email] + (if params.field.external.concat.email? and value[params.field.external.concat.email]? then ' ' + value[params.field.external.concat.email] else '') else ''

                else
                    # In other cases create default value object
                    value =
                        name: if value? then value else ''
                        email: ''

            # Method which do formating of "attendee" field expect as value  array which contains objects with name and email params
            # and both of them should be a string values
            when 'attendee'
                # If value is array, iterate through that value and create for each element object name and email params
                if value instanceof Array
                    _.each value, (v, k) =>
                        value[k] =
                            name: if v[params.field.external.name]? then v[params.field.external.name] + (if params.field.external.concat.name? and v[params.field.external.concat.name]? then ' ' + v[params.field.external.concat.name] else '') else ''
                            email: if v[params.field.external.email]? then v[params.field.external.email] + (if params.field.external.concat.email? and v[params.field.external.concat.email]? then ' ' + v[params.field.external.concat.email] else '') else ''

                # If value is object create array with only one element, object with name and email params
                else if value instanceof Object
                    value = [
                        name: if value[params.field.external.name]? then value[params.field.external.name] + (if params.field.external.concat.name? and value[params.field.external.concat.name]? then ' ' + value[params.field.external.concat.name] else '') else ''
                        email: if value[params.field.external.email]? then value[params.field.external.email] + (if params.field.external.concat.email? and value[params.field.external.concat.email]? then ' ' + value[params.field.external.concat.email] else '') else ''
                    ]

                # If value isn't ether array or object create default value
                else
                    value = [
                        name: if value? then value else ''
                        email: ''
                    ]

            # For all other fields just apply concatenation if that is required and return value
            else

                value = if value[params.field.external.field]? then value[params.field.external.filed] + (if params.field.external.concat.field? and value[params.field.external.concat.field]? then ' ' + value[params.field.external.concat.name] else '') else value

        value

module.exports = CalendarManager
