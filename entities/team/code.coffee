class @Extensions

    constructor: () ->

    init: () ->

        @app = window.App

        @el = $('span#newbies', '#controls #extensions')

        @el.click () =>
            @toggleNewbiesFilter()

        @app.bind 'profileClosed',  @onProfileClosed, @
        @app.bind 'resetFilters',   @onResetFilters,  @
        @app.bind 'resetFacets',    @onResetFacets,   @
        @app.bind 'filterByFacet',  @onFilterByFacet, @
        @app.bind 'updateFacetState', @onFilterByFacet, @
        @app.router.bind 'route',   @onRoute,         @

    toggleNewbiesFilter: () ->
        return @removeNewbiesFilter() if $(@el).hasClass 'active'
        @applyNewbiesFilter()

    applyNewbiesFilter: () =>
        @app.filterSelection.push cat: 'startDate', field: 'new'

        @app.filterByFacet (col) =>
            if col.length is 0
                @app.resetFacets()
                return @app.filterByFacet () =>
            @el.addClass 'active'
            @showPaneView()

    removeNewbiesFilter: () =>
        @app.filterSelection.clearFacetCat 'startDate'

        @app.filterByFacet (col) =>
            window.paneView?.close()
            $('#items .thumbnailContainer, #tableContainer, #footer')
                .removeClass 'onProfile'
            $(@el).removeClass 'active'

    showPaneView: () ->
        return if window.profileView or window.groupView

        template = _.template $("#app > #extensions #newbies-template").html()
        window.paneView = new PaneView template,
            t: window.pdata['team']['Mentoring']
        $('#pane').css('display', 'block').html window.paneView.render().el

        $(window.paneView.el).bind 'close', () =>
            @toggleNewbiesFilter()

    onProfileClosed: () ->
        @showPaneView() if $(@el).hasClass 'active'

    onResetFacets: () ->
        if @app.filterSelection.index(cat: 'startDate', field: 'new') is -1
            @el.removeClass 'active'

    onResetFilters: () =>
        @el.removeClass 'active'
        window.paneView?.destroy()

    onRoute: () ->
        i = @app.filterSelection.index cat: 'startDate', field: 'new'
        if i isnt -1
            @el.addClass 'active'
            @showPaneView()

    onFilterByFacet: () ->
        if @app.filterSelection.index(cat: 'startDate', field: 'new') isnt -1
            @showPaneView()

