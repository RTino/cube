#### Extensions

# Some extensions to javascript builtin objects, just to make our lifes easier


#### Facet Array
# Contains an array of facet objects ( { cat: category, field: fieldName } )
# and provides getters, setters and some array methods like push or 'toggle'
# that locate, add or remove facet objects in a simple way.

class window.FacetArray

    constructor: (arr) ->
        @arr = arr || new Array

    # Get the internal array
    get: () ->
        @arr
    # Override the internal array
    set: (a) ->
        @arr = a

    #### Push
    # Push the given object only if it doesn't exist already.
    # Avoids duplication of facet objects.
    push: (i) ->
        return unless @index i is -1
        @arr.push i

    #### Toggle (insert/remove)
    # Insert or remove a facet object in the array. If it is present, it
    # should be removed, otherwise it should be added. Thus 'toggling' the
    # existence of the object in the array.
    toggle: (o) ->

        i = @index o
        if i is -1
            @clearFacetCat o.cat
            return @arr.push cat: o.cat, field: o.field
        arr = []
        arr = $.grep @arr, (v, index) =>
            return v if index isnt i
        @arr = arr

    #### Clear by category
    # Remove all facet objects with a certain category
    clearFacetCat: (cat) =>
        arr = []
        arr = $.grep @arr, (v, index) =>
            return v if v.cat isnt cat
        @arr = arr

    #### Toggle multiple objects
    # Adds or Removes objects similar to toggle, but does it for an array of
    # given facet objects.
    toggleMult: (o) ->
        i = -1
        _.each @arr, (c, index) =>
            if c.cat is o.cat and c.field is o.field then i = index

        if i is -1 then return @arr.push cat: o.cat, field: o.field

        arr = new Array
        arr = $.grep @arr, (v, index) =>
            return v if index != i
        @arr = arr

    #### Index
    # Return the position of the facet object in the facet array
    index: (o) =>
        r = -1
        _.each @arr, (c, i) =>
            if c.cat is o.cat and c.field is o.field
                return r = i
        return r

    #### Index
    # Return the position of the facet object in the facet array
    indexCat: (o) =>
        r = -1
        _.each @arr, (c, i) =>
            if c.cat is o.cat
                return r = i
        return r
