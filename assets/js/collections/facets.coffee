#### Facet Collection

class @Facets extends Backbone.Collection

    # Contains facet objects ( { cat: category, field: name })
    model: window.Facet,

    # URL from QS
    # This collection needs to get the querystring parameters that will be
    # passed to solr.
    url: () =>
        window.App.commonURL()

    #### Parse
    # 1. Get special fields from the schema (the ones that should go below
    # the horizontal line on the facet area)
    # 2. Create an empty facet object of the described form.
    # 3. Initialize normal and special facet objects arrays containers
    # 4. Go through the solr response and push facet objects into their
    # appropriate normal/special arrays.
    # 5. Since the facet response from solr is very weird ( its an array of
    # facet name followed by the amount number, followed by the next facet...
    # i.e. [ 'pizzas', 3, 'pastas', 5, 'desserts', 2], we parse it into a
    # cleaner json object.
    # 6. For undefined fields (null) add them as 'not set'
    parse: (res) =>
        s = window.settings.Schema.getSpecials()
        facetFields = []

        _.each res.facet_counts?.facet_fields, (fields, name) =>
            name = name.split('-')[0]
            f = window.settings.Schema.getFieldById name
            facetFields.push @createFacet(name, f, fields)
        facetFields

    # Create a facet category like 'team', 'group', 'role', etc. Composed of a
    # label and normal and special fields. Normal fields go above a gray line,
    # special fields below.
    createFacet: (facetName, field, fields) =>

        facetName = field.id.split('-')[0]
        facetLabel = field.label

        sep = field.separator || window.settings.separator

        normal = []
        special = []

        _.each fields, (field, i) =>
            return unless i% 2 is 0
            return if field is null
            return special.push(field) if @isSpecial facetName, field, sep
            normal.push(field)

        normal = @sort field, normal
        special = @sort field, special

        # null values are not-set values, it has to show not-set values too
        # and the amount of items who don't have this facet set.
        normal.push "null"

        root =
            name: facetName
            label: facetLabel
            fields:
                normal: {},
                special: {}

        _.each normal, (field) =>
            tree = root.fields.normal
            @createNode field, fields, tree, sep

        _.each special, (field) =>
            tree = root.fields.special
            @createNode field, fields, tree, sep

        root

    # Create a facet field object with name, amount of items in it and
    # all sub-facet fields. (deeper level nodes).
    createNode: (field, amounts, tree, sep) =>
        tokens = field.split sep
        name = tokens.pop()
        if tokens.length then _.each tokens, (token) =>
            tree = tree[token].subs if tree[token]
        path = if name is "null" then null else field
        tree[name] =
            amount: amounts[amounts.indexOf(path)+1],
            path: field
            subs: {}

    # Sort facet fields based on a specific order (specified in entity's
    # settings file) or alphabetically.
    sort: (field, arr) =>
        return arr.sort() unless field.order
        order = field.order
        sorted = []
        _.each order, (field) ->
            sorted.push field if arr.indexOf(field) isnt -1
        _.each arr.sort(), (field) ->
            sorted.push field if sorted.indexOf(field) is -1
        sorted

    # Determine if the facet field is listed in the special property array
    # on the schema definition. If its special it will be rendered below a
    # gray line on the facet pane.
    isSpecial: (name, field, sep) =>
        parent = field.split(sep)[0]
        specials = window.settings.Schema.getSpecials()
        return no unless specials[name]
        return yes if specials[name].indexOf(parent) isnt -1
        return no
