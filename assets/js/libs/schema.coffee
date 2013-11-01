#### Schema class
#
# Provides a set of methods to get objects from the Schema that have certain
# properties like 'mandatory', 'index', etc. Its quite self-explanatory.

class window.Schema

    constructor: (arr) ->
        @arr = arr || new Array

    get: () ->
        @arr

    set: (a) ->
        @arr = a

    getFieldById: (id) ->
        field = null
        _.each @arr, (f) ->
            field = f if f.id is id
        field

    getFieldsByType: (t) ->
        arr = []
        _.each @arr, (o) =>
            arr.push o if o['type'] is t
        arr

    getFieldsByProp: (p) ->
        arr = []
        _.each @arr, (o) =>
            arr.push o if o[p]
        arr

    getPictures: () ->
        @getFieldsByType 'img'

    getAdmins: () ->
        @getFieldsByProp 'admin'

    getSearchs: () ->
        @getFieldsByProp 'search'

    getMandatories: () ->
        @getFieldsByProp 'mandatory'

    getUnique: () ->
        @getFieldsByProp 'unique'

    getAdditionals: () ->
        @getFieldsByProp 'additional'

    getThumbnails: () ->
        @getFieldsByProp 'thumbnail'

    getMultivalues: () ->
        arr = []
        _.each @arr, (o) =>
            arr.push o if o['multivalue'] or o.type is 'facet'
        arr

    getIndexes: () ->
        @getFieldsByProp 'index'

    getMultiedits: () ->
        @getFieldsByProp 'multiedit'

    getMultilines: () ->
        @getFieldsByType 'multiline'

    getEmails: () ->
        @getFieldsByType 'email'

    getSkypes: () ->
        @getFieldsByType 'skype'

    getBookmark: () ->
        @getFieldsByProp('bookmark')[0] || {}

    getFacets: () ->
        @getFieldsByType 'facet'

    getTuples: () ->
        @getFieldsByType 'tuple'

    getColorized: () ->
        @getFieldsByProp 'colorize'

    getSpecials: () ->
        specials = {}
        _.each @arr, (o) =>
            specials[o.id] = o.specials if o['specials']
        specials

    getClassifier: () ->
        return @getFieldsByProp('classifier')[0] || []

    getImgKey: () ->

        return @getPictures()[0]?['id']
