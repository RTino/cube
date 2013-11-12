#### Backbone Routes

$ ->

    class window.Routes extends Backbone.Router


        routes:
            "qs/:qs"    : "getRoute"
            ""          : "root"


        # Route to the appropriate state based on the Querystring parameters.
        getRoute: (qs, params) =>

            @setSort    params.sort    if params.sort
            @setRows    params.rows    if params.rows
            @setPage    params.page    if params.page
            @setDisplay params.display if params.display

            # This is a fix. Sometimes the parameters come as a string,
            # instead of as an array, defined by '|' as the splitting char.
            # This makes shure its an array.
            params.fs = @parseToArr params.fs if params.fs
            params.id = @parseToArr params.id if params.id?.indexOf('|') isnt -1

            if params.id is "new" then @setPage 0

            if typeof params.id is "string" and !params.page
                return @getPageOfId params.id, 0, (page) =>
                    @setPage page
                    return @onRoute params
            @onRoute params


        onRoute: (params) =>

            # Get view mode: list or thumbnail.
            window.settings.view = params.view || 'list'
            if window.settings.view isnt 'list'
                $('span#view').removeClass 'list'

            # If there is a profileView present, destroy it. It will generate
            # the correct profile view later.
            window.profileView?.close()

            # Clear search field
            $('#inputSearch').val ''

            @setFacet params.fs || [], params.s, () =>
                @setId params.id if params.id
                window.App.navigate replace:yes
                @trigger 'route'

            @display params.display


        #### Route to initial state
        root: () =>

            # Destroy profile view if existent
            window.profileView?.close()

            window.extendedView?.close()

            $('.pane').hide()
            $('.pane').html ''

            # Remove all items selections
            # window.App.clearSelection()

            # Reset facet filters
            window.App.resetAllFilters()


        #### Set ID
        # * If ID is 'New' show empty profile view to add a new item.
        # * If ID is a string, there is just 1 item selected. Show its profile.
        # * If ID is an array, there is a multiple selection. Show the
        # corresponding group view.
        setId: (id) =>

            if id is 'new'
                if settings.detailedView is 'team'
                    window.App.showExtendedView new window.Item
                    return window.extendedView.edit()
                window.App.showProfile new window.Item
                return window.profileView.form()

            if typeof id is typeof 'string' and settings.detailedView is 'team'
                return window.App.showExtendedView window.collection.get id

            if typeof id is typeof 'string'
                return unless @isItemInCol id
                return window.App.selectOne $("##{id}", '#items')

            if typeof id is typeof []
                _.each id, (_id) =>
                    return unless @isItemInCol _id
                    if $("##{_id}", '#items').length
                        window.App.addToSelection $("##{_id}", '#items')
                window.App.showGroupView()

        #### Set Filters state
        # 1. Get all filters from the querystring parameters
        # 2. Select filters that are available
        # 3. Expand facet categories that have selections
        # 4. Filter the collection
        setFacet: (fs, s, cb) =>
            _fs = []
            sep = window.settings.separator
            _.each fs, (facet) =>
                if !@isFacetInFacets facet
                    facet = @traverseUpwards facet
                return unless facet
                cat = facet.split(':')[0]
                field = facet.split(':')
                field.splice(0,1)
                field = field.join(':')
                _fs.push cat: cat, field: field
            window.App.setFacetState _fs
            itemsUrl = window.App.getFilterQS(_fs)

            @setSearch s

            window.facets.fetch
                data: itemsUrl
                success: () =>
                    window.App.hideError()
                    window.App.fetchItems
                        data: itemsUrl
                        success: () =>
                            window.App.genPageIndex()
                            window.App.setFacetState _fs
                            if _fs.length
                                $('span#reset').show()
                            cb() if cb
                error: (col, res, opts) =>
                    # Redirect to login page in case it got a 403
                    window.location.href = '/login' if res.status is 403

                    window.App.showError()


        traverseUpwards: (f) =>
            sep = window.settings.separator
            field = f.split(':')[1].split(sep)
            field = field.slice(0, field.length-1).join(sep)
            return f unless field
            f = f.split(':')[0] + ":" + field
            return @traverseUpwards(f) unless @isFacetInFacets f
            return f


        #### Set search
        # Set the search text on the search input and filter the collection
        setSearch: (s) =>
            return unless s
            s = s.toLowerCase()
            window.collection.search = s
            $('#inputSearch').val s


        setSort: (s) =>
            window.collection.sort = s or window.settings.sort


        setRows: (r) =>
            window.collection.rows = r or window.settings.rows


        setPage: (p) =>
            window.collection.page = p


        setDisplay: (d) =>
            window.collection.display = d or null


        # Check if the item is still in the items collection
        isItemInCol: (id) =>
            return yes if window.collection.get id
            window.App.navigate replace: yes
            return no


        # Check if the facet field is still in the facets collection
        isFacetInFacets: (f) =>
            cat = f.split(':')[0]
            field = f.split(':')[1]
            if $("li[data-title='#{field}']", "ul#facet li ul\##{cat}").length
                return yes
            if $("span[data-type='#{cat}'][data-title='#{field}']").length
                return yes
            return no


        # Find the page where a member with ID is located at.
        getPageOfId: (id, page, cb) =>
            rows = parseFloat window.collection.rows
            $.get window.App.commonURL(page, 1000), (result) =>
                index = 0
                return cb 0 unless result.response?.docs.length
                _.each result.response.docs, (doc, i) =>
                    index = i if id is doc.id
                return cb Math.floor(index/rows) if index >= 0
                return @getPageOfId id, page+1, cb


        parseToArr: (source) ->
            return source unless typeof source is "string"
            s = []
            _.each source.split('|'), (v) ->
                s.push v if v
            return s


        display: (mode) ->
            page =
                header: $('#header')
                facets: $('#index')
                content: $('#content')
                pane: $('.pane')
                footer: $('#footer')

            if mode == 'fullScreen'
                page.header.hide()
                page.facets.hide()
                page.content.css top: 0, right: 0, left: 0
                #page.pane.css 'margin-top': 0
                page.footer.css left: 0

            else
                page.header.show()
                page.facets.show()
                window.App.resizeIndex()
                #page.pane.css 'margin-top': 50
