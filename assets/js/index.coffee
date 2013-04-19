# Index page
#
# Welcomes the user with a nice header and a list of available
# entities.

$ ->

    # Show a list of entities available
    _.each entities, (settings) ->

        name = settings.entity

        adminKey = if isAdmin() then "?admin=yes" else ''

        template = _.template $('#list-item').html()

        $('section#content ul').append template

            entity  : name,
            title   : settings.title
            desc    : settings.description
            icon    : '/assets/hypercube_logo_50.png',

        # Get each entitie's collection and show the amount of items.
        $.get "/#{name}/collection/", (col) ->

            l = col.response.numFound

            $("section#content ul li##{name} p#amount").html "(#{l})"

            $("section#content ul li##{name}").click () ->
                window.location = "/#{name}/#{adminKey}#qs/?"

    # File upload plugin
    $('input#import').fileupload dataType: 'json', done: ($e, data) ->


    $('input#import').bind 'fileuploaddone', (e, data) ->
        document.location.reload yes

    # Show extension add button if user is admin
    $('a.btn#add').css('display', 'block') if isAdmin()

    # Show input field to upload CSV/Json and import into a new extension.
    $('input#import').css('display', 'block') if isAdmin()


# Check if admin key is present in QS
isAdmin = () =>

    qs = window.location.search.split('?')[1]

    new RegExp('admin=').test qs
