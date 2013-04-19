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

    #TODO no need for cb
    getField: (id, cb) ->
        _.each @arr, (f) ->
            return cb(f) if f.id is id

    getFieldById: (id) ->
        field = null
        _.each @arr, (f) ->
            field = f if f.id is id
        field

    getObjectsWithProperty: (p) ->
        arr = []
        _.each @arr, (o) =>
            arr.push o if o[p]
        arr

    getObjectsWithType: (t) ->
        arr = []
        _.each @arr, (o) =>
            arr.push o if o['type'] is t
        arr

    getPictures: () ->
        @getObjectsWithType 'img'

    getAdmins: () ->
        @getObjectsWithProperty 'admin'

    getSearchs: () ->
        @getObjectsWithProperty 'search'

    getMandatories: () ->
        @getObjectsWithProperty 'mandatory'

    getAdditionals: () ->
        @getObjectsWithProperty 'additional'

    getThumbnails: () ->
        @getObjectsWithProperty 'thumbnail'

    getMultivalues: () ->
        arr = []
        _.each @arr, (o) =>
            arr.push o if o['multivalue'] or o.type is 'facet'
        arr

    getIndexes: () ->
        @getObjectsWithProperty 'index'

    getMultiedits: () ->
        @getObjectsWithProperty 'multiedit'

    getMultilines: () ->
        @getObjectsWithType 'multiline'

    getEmails: () ->
        @getObjectsWithType 'email'

    getSkypes: () ->
        @getObjectsWithType 'skype'

    getBookmark: () ->
        @getObjectsWithProperty('bookmark')[0] || {}

    getFacets: () ->
        @getObjectsWithType 'facet'

    getTuples: () ->
        @getObjectsWithType 'tuple'

    getSpecials: () ->
        specials = {}
        _.each @arr, (o) =>
            specials[o.id] = o.specials if o['specials']
        specials

    getClassifier: () ->
        return @getObjectsWithProperty('classifier')[0] || []
