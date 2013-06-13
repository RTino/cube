#### Item Model

class @Item extends Backbone.Model

    #### Initialize bindings
    # Update the facets on a sync event. If the item belongs to a new category,
    # or any other faceted field, query solr to get the new facet fields and
    # redraw the items propperly.
    initialize: () =>
        @bind 'sync', window.App.updateFacets, window.App

    #### URLRoot
    # Returns the base url part for a given entity
    urlRoot: () =>
        return "/#{window.entity}/collection/"

    #### Destroy
    # Destroy the model but waiting for the db to update
    clear: () ->
        @destroy wait: yes

    #### Parse
    # Forms a JSON object with the model propertie's and prepares it for
    # rendering in the templates. Escapes HTML characters and forms
    # multivalue strings.
    parseSubfields: () =>

        model = @toJSON()

        sep = window.settings.separator

        _.each model, (value, field) =>
            model[field] = _.escape value if typeof value is typeof "string"

        fields = window.settings.Schema.getMultivalues()

        _.each fields, (field) =>

            model[field.id] = @parseMultivalueField model[field.id]

        model

    # Multivalue strings are stored in Solr in a special way. For example,
    # given the string "TeamA/GroupX/Subgroup1" its stored in solr as:
    # [ "TeamA", "TeamA/GroupX", "TeamA/GroupX/Subgroup1" ]. This reverses the
    # array into the original string.
    parseMultivalueField: (arr) =>

        unique = []

        _.each arr, (v, i) ->
            rem = arr.slice(i+1).join()
            unique.push(_.escape(v)) if rem.indexOf(v) is -1

        unique


    # Return a string with the title of the item, based on the properties
    # that have 'thumbnail'
    getTitle: () ->
        t = []
        _.each window.settings.Schema.getThumbnails(), (l) =>
            t.push @get l.id
        return t.join ' '
