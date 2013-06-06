#### Item Model

class @Item extends Backbone.Model

    #### Initialize bindings
    # Update the facets on a sync event. If the item belongs to a new category,
    # or any other faceted field, query solr to get the new facet fields and
    # redraw the items propperly.
    initialize: () =>
        @bind 'sync', window.App.updateFacets, window.App

    urlRoot: () =>
        return "/#{window.entity}/collection/"

    #### Destroy
    # Destroy the model but wait for the db to update
    clear: () ->
        @destroy wait: yes

    #### Parse en item
    # Returns a JSON object where the multivalue properties are
    # correctly parsed: i.e. 'cat1/subcat1, cat1/subcat2' should be
    # returned as [cat, cat1/subcat1, cat1/subcat2].
    # * This is used to relate facet categories to subcategories in solr.
    parseSubfields: () =>
        model = @toJSON()
        sep = window.settings.separator

        fields = window.settings.Schema.getMultivalues()
        _.each fields, (field) =>
            values = model[field.id]
            unique = []
            _.each values, (v, i) ->
                rem = values.slice(i+1).join()
                unique.push(v) if rem.indexOf(v) is -1
            model[field.id] = unique
        model

    # Return a string with the title of the item, based on the properties
    # that have 'thumbnail'
    getTitle: () ->
        t = []
        _.each window.settings.Schema.getThumbnails(), (l) =>
            t.push @get l.id
        return t.join ' '
