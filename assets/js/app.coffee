#### Cube App
#
# The cube is composed of a nodejs backend and a backbonejs frontend. This is
# the start of the backbonejs application. Please checkout cube.coffee to
# find more about the backend.
#
# You can also visit our github page and repository
#
# http://cubeapp.io
#
# @autor: Emanuel Lauria <emanuel.lauria@zalando.de>
# @date:  Apr/2013

$ =>

    # Backbone collection to hold all items from our entity.
    @collection = new @Collection

    # Facets collection, holding all facet fields.
    @facets = new @Facets

    # Extensions code
    @extensions = if @Extensions then new @Extensions else null

    #### Main View
    # Holds a new user profile view, handles search and filtering
    # on the items collection and updates between views and collections.
    class AppView extends Backbone.View

        el: $('#app')

        events:
            "keyup #inputSearch"                        : "onSearchInput"
            "click a#add.btn"                           : "addNewItem"
            "click span#reset a"                        : "resetAllFilters"
            "click span#view"                           : "toggleViewMode"
            "click span#print"                          : "print"
            "click #exporter span"                      : "export"
            "click #entityTitle"                        : "toggleEntitiesMenu"
            "click #columnsMenu"                        : "toggleColumnsMenu"
            "click #columnOptions ul li span"           : "handleColumnsMenuClick"
            "click #entities ul li"                     : "redirectToEntity"
            "click span#pageL"                          : "previousPage"
            "click span#pageR"                          : "nextPage"
            "click span#jumpToFirst"                    : "jumpToFirst"
            "click span#jumpToLast"                     : "jumpToLast"
            "click #footer li"                          : "jumpToPage"
            "click table th .sort"                      : "sortTable"
            "mouseenter #columnsMenu"                   : "overColumnsMenu"
            "mouseenter .th-inner"                      : "showColumnsBtn"
            "mouseleave .th-inner"                      : "hideColumnsBtn"
            "click"                                     : "documentClick"
            "mousedown table th .ganttLeftArrow"        : "ganttMove"
            "mousedown table th .ganttRightArrow"       : "ganttMove"
            "mouseup table th .ganttLeftArrow"          : "ganttMove"
            "mouseup table th .ganttRightArrow"         : "ganttMove"
            "mouseleave table th .ganttLeftArrow"       : "ganttMove"
            "mouseleave table th .ganttRightArrow"      : "ganttMove"
            "mouseenter .ganttCell"                     : "ganttNotification"
            "mouseleave .ganttCell"                     : "ganttNotification"


        #### Initialize
        initialize: () =>

            # Create router object
            @router = new window.Routes

            # Set application settings from settings.json
            @setAppSettings()

            # Set collection settings like sort criteria or amount of rows
            @setColSettings()

            # Get the schema of the current entity
            @getSchema()

            # Create style object
            @style = new window.Style

            # Collection bindings only if necessary
            @bindCollections()

            # Get entity's custom templates and start app on success.
            @getExtensions () =>

                @start()

        #### Bindings for collections
        bindCollections: () =>

            # Display any new items in the container.
            window.collection.bind  'add',      @addOne,        @

            # Updte facets whenever an item is added to the collection
            window.collection.bind  'add',      @updateFacets,  @

            # Redraw items whenever the collection is resetted.
            window.collection.bind  'reset',    @reset,         @

            # Draw all facets whenever the collection is resetted.
            window.facets.bind      'reset',    @addAllFacets,  @


        #### Start
        start: =>

            # Set icon with picture and show logout btn if auth worked
            @setUser()

            # Set the application's title (extension name on top left)
            @setAppTitle()

            # Start loading animation timer (1second timeout)
            @showLoadingAnimation()

            # Set view icon's state to show current view mode (top right).
            # If no pictures on the schema, thumbnail view mode is disabled
            @setViewMode()

            # Hide the index pane or resize it to appropriate size
            @setAppFacetsState()

            #Set Schema indexes from localStorage
            @setColumnSelection()

            #Set Schema colors from localStorage
            @setColumnColors()

            # Create the columns menu
            @generateColumnsMenu()

            # Create the entities menu
            @generateEntitiesMenu()

            # Start app with search input text focused
            $('#inputSearch').focus() unless @isTablet()

            # Hide Add item button unless admin key is present
            @setAdminState()

            # Profile additional info open/close state. Default is closed.
            @setProfileState()

            # Listen for arrow keys to move between items
            @setMoveKeybindings()

            # Set listener for resize event
            @setResizeListener()

            # Activate exporter menu
            @exportMenu()

            # Fetch facets and start backbone history right after.
            @initFacets () => Backbone.history.start()


        # Facet collection init
        initFacets: (cb) =>

            return cb() if settings.facets is 'tree'

            #Fetch facets from database
            window.facets.fetch success: () =>

                # Hide any ajax error on success
                @hideError()

                # Set expanded/folded state on facet HTML index
                @setFacetOpenState()

                cb()

            , error: (col, res, opts) =>

                # Redirect to login page in case it got a 403
                window.location.href = '/login' if res.status is 403

                # Show error icon on controls section (top right)
                @showError()


        # Set user icon on controls section as a logout btn.
        setUser: () ->

            if window.user?.pic
                $('#controls a#profile')
                    .css 'background-image', "url(#{window.user.pic})"
            else
                console.log 'no session'
                $('#controls a#profile').hide()

            username = window.user.mail
            if window.user.name and window.user.lastname
                username = "#{window.user.name} #{window.user.lastname}"

            $('#controls a#profile')
                .attr('title', 'Logged in as ' + username)
                .css('display', 'inline-block' if username)
                .attr 'href', '/team/#qs/?id=' + window.user?.id

            $('#controls a#logout')
                .css 'display', 'inline-block' if window.user.id


        # Settings object holds all configuration parameters
        setAppSettings: () ->

            # Etiquettes definition (etiquettes.json)
            window.settings.etiquettes = window.etiquettes

            # Available entities
            window.settings.entities = window.entities

        # Set collection settings like sort and rows.
        setColSettings: () ->

            # Sort criteria (i.e. name:asc)
            window.collection.sort = @getSort()

            # Rows to show (default: 50)
            window.collection.rows = window.settings.rows


        # Set the application's title on top left corner (top entities menu)
        setAppTitle: () =>

            # Show name on top left corner and window title
            $('#header #entityTitle h1').html window.settings?.title

            # Show arrow on title if is possible to chose other entity
            if window.settings.entities.length > 1
                $('#header #entityTitle').addClass 'selectable'


        # Set the view mode to either thumbnail or list
        setViewMode: () =>

            # No picture? no thumbnail view.
            pictureFields = window.settings.Schema.getPictures()
            $('span#view').hide() if pictureFields.length is 0

            # Set list view as default if in settings
            $('span#view').addClass 'list' if window.settings?.view is 'list'


        # Set the facet pane state
        setAppFacetsState: () =>

            # Get facet fields from Schema
            facets = window.settings.Schema.getFacets()

            # If there are no facet fields, hide the facet pane
            # return @disableFacets() unless facets.length

            # Resize the facet pane to user preferences
            @setIndexResizable()


        # Set the application edit capabilities
        setAdminState: () =>

            # Check if entity is editable and user has provided admin key
            if @isEditable() and @isAdmin()

                $('a#add.btn').css 'display', 'inline-block'


        # Save profile state
        setProfileState: () =>

            window.profileState =
                additionalOpen: no
                openTab: 'details'


        setResizeListener: () =>
            window.onresize = () =>
                @ganttInfoInit()


        # Get extesion HTML/JS code and append it to dom.
        getExtensions: (cb) =>

            $.get 'template', (exthtml) ->

                # Append HTML on extension container
                $('#app > #extensions').html exthtml

                # Get extension controls and append them
                controls = $("#app > #extensions #controls")

                if controls.length
                    t = _.template controls.html() if controls.length
                    $('#controls #extensions').append t({})

                # Initialize extended javascript
                window.extensions?.init?()

                cb()


        # Add Profile extension code
        addProfileExtensions: (item) =>

            if $('#actions-template', '#app > #extensions').length

                actionsTemplate = _.template $('#app > #extensions #actions-template')
                    .html()

                $('.pane #buttons #btnExtensions').append actionsTemplate()

                window.extensions?.bindActions()?

            if $('#details-template', '#app > #extensions').length

                detailsTemplate = _.template $('#app > #extensions #details-template')
                    .html()

                $('.pane #extensions').append detailsTemplate t:item


        # Get schema and attach it to our Settings object
        getSchema: ->

            window.settings?.Schema = new window.Schema window.schema


        # Switches between list view mode and thumbnail view mode
        toggleViewMode: () =>

            # Choose view mode to toggle to
            v = if window.settings.view is 'list' then 'thumbnail' else 'list'

            # Set new view mode
            window.settings.view = v

            # Set control icon appearance
            $('span#view').removeClass 'list'
            $('span#view').addClass 'list' if v is 'list'

            # Redraw collection of items
            @filterByPage () =>

                @scrollToSelection $('#items .active'), yes

                @navigate()


        # Redraw collection after a reset event
        reset: (attr) =>

            letters = $("#inputSearch").val().toLowerCase()

            $('#search span#reset').show()

            $('#search span#reset').hide() unless letters or @filterSelection
                .get().length

            @renderTreeView() if settings.facets is 'tree'

            return @addAll window.collection


        # Add one item to the items container. Either in thumnail mode
        # (picture and name) or in list mode (pic, full name, teams, etc.)
        addOne: (m) =>

            view = window.settings.view

            return window.App.addOneThumbnail(m) if view is 'thumbnail'

            window.App.addOneList m


        # Add one item to the table of items (list view mode)
        addOneList: (item) =>

            # Create a new list view
            view = new ItemListView model: item

            # Append it to the table
            @$("#items #tableContainer table tbody").append view.render().el


        # Add one item with a thumbnail view
        addOneThumbnail: (item) =>

            # Create a new Thumbnail view
            view = new ItemThumbnailView model: item

            if settings.facets is 'tree'
                return @$('ul.thumbnailContainer ul.container', '#items')
                    .append view.render().el

            # Choose category to append it to appropriate container
            cat = item.get window.settings.Schema.getClassifier().id
            cat = cat[0] if typeof cat is typeof []
            cat = 'null' if cat is undefined
            cat = window.categories.indexOf cat

            # Append to category container
            @$("li#category-#{cat} ul", '#items').append view.render().el


        # Render all items in the given collection
        addAll: (col, cb) =>

            view = window.settings.view

            columnsMenuIsOpen = $('#columnsMenu').hasClass 'active'

            # Render view mode
            render = @renderTableView
            render = @renderCategoryView if view is 'thumbnail'

            render () =>

                # Add each item in the collection
                col.each @addOne

                # Hide categories that ended up with no items
                @hideEmptyCategories() if view is 'thumbnail'

                # Set total amount of items
                @setTotals()

                # Update facet selection and items selection
                @updateSelection()

                # Scroll page to closes selected item
                @scrollToSelection $($('#items .active')[0]), yes

                # Show columns menu if it was active before
                $('#columnOptions').show() if columnsMenuIsOpen
                $('#columnsMenu').addClass 'active' if columnsMenuIsOpen

                # Fix gantt width (firefox issue)
                @ganttWidthFix()

                # Set gantt arrows
                @ganttInfoInit()

                # Apply content style from schema
                @style.apply()

                #Add Color to columns
                @colorize()

                cb() if cb


        # Create an empty profileView to add an item
        addNewItem: () =>

            @clearSelection()

            if settings.detailedView is 'team'
                @showExtendedView new window.Item
                window.extendedView.edit()
                return @navigate()

            @showProfile new window.Item
            window.profileView.form()
            @navigate()


        # Select one item with a normal click. Delete previous selection if
        # present and save selected item as the firstActiveItem
        selectOne: ($e, attr) =>

            @clearSelection()

            @addToSelection $e

            @scrollToSelection $e

            if settings.detailedView is 'team'
                return @showExtendedView  window.collection.get $e.attr 'id'

            @showProfile window.collection.get($e.attr('id')), attr


        # Add a item to the selection array
        addToSelection: ($e) =>

            id = $e.attr 'id'

            $e.addClass 'active'

            window.firstActiveItem = id if @itemSelection.length is 0

            @itemSelection.add window.collection.get id


        # On list mode, when selection is too close to top or bottom border,
        # do a page up/down respectively.
        scrollToSelection: ($e, center) =>

            return unless $e.length

            posY = $e.offset().top - 90

            $container = $('.fixed-table-container-inner, .thumbnailContainer')

            scrollTop = $container.scrollTop()

            height    = $container.height()

            eHeight   = if window.settings.view is 'list' then 39 else 196

            if posY + eHeight > height
                top = scrollTop + eHeight - (height - posY)
                top += height/2 if center
                return $container.scrollTop top

            if posY < 0
                top = scrollTop + posY + 1
                return $container.scrollTop top


        # Add all facets from the facet collection
        addAllFacets: () =>

            $('ul#facet').html ''

            window.facets.each @addOneFacet

            @resizeIndex()

            @setFacetWidth()


        # Add one facet field with a title name and a list of values
        addOneFacet: (facet) ->

            view = new FacetView model: facet

            @$('ul#facet').append view.render().el


        # Fetch all items for the collection
        fetchItems: (attr) =>

            @showLoadingAnimation()

            # Unbind all item views so they get removed when HTML is replaced
            # TODO prob possible to remove with Backbonejs 1.0
            @unbindItemViews()

            # Fetch items. cb() in attr.
            window.collection.fetch attr


        # Fetch facets
        fetchFacet: (cb) =>

            return cb() if settings.facets is 'tree'

            @showLoadingAnimation()

            # Fetch facets using current facet selection as filters
            window.facets.fetch

                # Get parameters for request (selected facet filters)
                data: @getFilterQS()

                success: () =>

                    @updateFacetState()
                    @setFacetState @filterSelection.get()
                    @hideError()
                    cb()

                error: (col, res, opts) =>
                    # Redirect to login page in case it got a 403
                    window.location.href = '/login' if res.status is 403

                    @showError()

        # Fetch a paginated collection
        filterByPage: (cb) =>

            # Re-fetch facets and re-apply filter selection
            @fetchFacet () =>

                # Fetch items based on filter selection, page, etc.
                @fetchItems

                    data: @getFilterQS()

                    success: (col) =>

                        @trigger 'filterByFacet'

                        # Generate page navigation (bottom right)
                        @genPageIndex()

                        @hideError()

                        # Show profile view if there was any open
                        @showPaneView()

                        @navigate()

                        cb(col) if cb

                    error: (col, res, opts) =>
                        # Redirect to login page in case it got a 403
                        window.location.href = '/login' if res.status is 403

                        @showError()

        # Fetch a collection by facet filter. Sets page back to 0.
        filterByFacet: (cb) =>

            window.collection.page = 0

            @filterByPage cb

        # Updates the facet collection
        updateFacets: (m) =>

            # Re-fetch facets from DB
            window.App.fetchFacet () =>

                # Re-fetch items based on the new filter selection
                window.App.fetchItems

                    data: window.App.getFilterQS()

                    success: (col) =>

                        window.App.genPageIndex()
                        window.App.hideError()
                        window.App.showPaneView()

                        # If the colection isn't empty, we are done
                        return if col.length

                        # Otherwise reset the app by clearing all filters
                        $('#inputSearch').val ''
                        window.App.resetAllFilters()

                    error: (col, res, opts) =>
                        # Redirect to login page in case it got a 403
                        window.location.href = '/login' if res.status is 403

                        window.App.showError()

        # Reset all filters.
        resetAllFilters: () =>

            # Useful event for extension code
            @trigger 'resetFilters'

            # Reset the facet state selection to none
            @setFacetState []

            # Clear search string
            window.collection.search = ''
            $('#inputSearch').val ''

            # Fetch facets and items
            @fetchFacet () =>

                @fetchItems

                    data: @getFilterQS()

                    success: () =>

                        @genPageIndex()
                        @hideError()
                        @navigate()

                    error: (col, res, opts) =>
                        # Redirect to login page in case it got a 403
                        window.location.href = '/login' if res.status is 403

                        @showError()

        # Reset only the facet fields but not the search or any other
        resetFacets: (cb) =>

            @trigger 'resetFacets'

            @setFacetState []

            @fetchFacet () =>

                @fetchItems

                    data: @getFilterQS()

                    success: () =>

                        @genPageIndex()
                        @hideError()
                        cb() if cb

                    error: (col, res, opts) =>
                        # Redirect to login page in case it got a 403
                        window.location.href = '/login' if res.status is 403

                        @showError()


        # Jump to previous page
        previousPage: () =>

            return if window.collection.page <= 0

            window.collection.page--

            @filterByPage () =>


        # Jump to next page
        nextPage: () =>

            total = window.collection.total
            rows = window.collection.rows
            lastPage = Math.ceil(total/rows) - 1

            return if window.collection.page >= lastPage

            window.collection.page++

            @filterByPage () =>


        # Jump to a specific page
        jumpToPage: (e) =>

            $e = $(e.currentTarget)

            window.collection.page = $e.attr 'id'

            @filterByPage () =>


        # Jump to first page
        jumpToFirst: () =>

            window.collection.page = 0

            @filterByPage () =>


        # Jump to last page
        jumpToLast: () =>

            total = window.collection.total
            rows = window.collection.rows
            lastPage = Math.ceil(total/rows) - 1

            window.collection.page = lastPage

            @filterByPage () =>


        # Generate the page index on the bottom
        genPageIndex: () =>

            template = _.template $('#pagination-index-template').html()
            total = parseFloat window.collection.total
            rows = parseFloat window.collection.rows
            page = parseFloat window.collection.page + 1
            first = parseFloat page * rows - rows + 1
            last = if page * rows > total then total else page * rows

            if total > rows
                $('#content').removeClass 'noPages'
                $('#footer').html template()

                # Apply content style from schema
                @style.apply()

                return $('#footer').show()

            $('#content').addClass 'noPages'
            $('#footer').hide()

            # Apply content style from schema
            @style.apply()


        # Reset filtes and set app state. User clicked on "reset filters" link.
        onResetFilter: () =>

            @resetFilter () =>

                @navigate()


        # Set facets expanded/folded state
        setFacetState: (s) =>

            @filterSelection.set s

            _.each s, (c) =>

                $f = $(".field[data-title='#{c.field}']",
                  "ul#facet li ul##{c.cat}")
                $f.addClass 'active'
                $('span.amount', $f).addClass 'active'

                $p = $f.parent()
                $('>span.fold', $p.parents()).addClass('open').html '–'
                $('>ul', $p.parents()).css('display', 'block')

            _.each @facetOpenState.get(), (c) =>

                $f = $("li[data-name='#{c.cat}'][data-title='#{c.field}']")
                $('>span.fold', $f).addClass('open').html '–'
                $('>ul', $f).removeClass 'hidden'

            @showPaneView()


        # Update facets selection state
        updateFacetState: () =>

            @trigger 'updateFacetState'

            $('.pane').hide() unless window.groupView or window.paneView or window.extendedView

            # New filter selection
            nf = []

            # Add remaining selected filters to new filter selection
            _.each @filterSelection.get(), (c) =>
                $e = $("span[data-type='#{c.cat}'][data-title='#{c.field}']")
                $f = $(".field[data-title='#{c.field}']",
                      "ul#facet li ul##{c.cat}")
                nf.push cat: c.cat, field: c.field if $f.length or $e.length

            # Set filterSelection with the new selection (remaining filters)
            @filterSelection.set nf

            # Hide 'reset filters' link unless there are filters selected
            $('span#reset').hide() unless nf.length


        # Forms an array of facet field parameters to put in the querystring
        getFilterQS: (state) =>

            s = state || @filterSelection.get()

            data = {fs: [] }

            _.each s, (f) -> data.fs.push "#{f.cat}:#{f.field}"

            data


        # Query URL to get a filtered collection of items from the Solr DB.
        commonURL: (page, rows) =>

            url = "collection/"

            fs = []

            fs.push "page=#{page}" if page isnt undefined
            fs.push "rows=#{rows}" if rows isnt undefined
            fs.push "sort=#{window.collection.sort}"

            fs.push "q=#{window.collection.search}" if window.collection.search

            _.each window.settings.Schema.getFacets(), (field) ->
                fs.push 'facet.field=' + field.id

            url += '?' + fs.join '&' if fs.length

            url


        # Trigger a search when users presses a key in the input search field.
        onSearchInput: (e) =>

            # Disable keys like ctrl, alt, shift from trigerring a search.
            disabledKeys =
                [ 18, 17, 16, 9, 20, 27, 33, 34, 35, 36, 37, 38, 39, 40 ]

            keyIndex = disabledKeys.indexOf e.keyCode

            if e.keyCode then return unless keyIndex is -1

            @search()

            @navigate()


        # Perform a search operation on the collection
        search: (attr) =>

            # Get lowercased string from search input field
            letters = $("#inputSearch").val().toLowerCase()

            # Avoid trigerring search if collection is already filtered by it.
            return if window.collection.search is letters

            # Show 'reset filters' link
            $('#search span#reset').show()
            $('#search span#reset').hide() unless letters or @filterSelection
                .get().length

            # Prepare item views to be removed
            @unbindItemViews()

            # Set new search string in the collection
            window.collection.search = letters

            # Reset page to first page
            window.collection.page = 0

            # Filter collection with new search string
            @filterByFacet () =>


        # Sort table when clicking on header. Toggle asc/desc modes.
        sortTable: (e) =>

            $e = $(e.currentTarget)
            $h = $e.parent()
            id = $h.attr 'id'

            # Remove all sort indicators (background and arrow) on headers
            _.each $h.siblings(), (s) ->
                $('.th-inner', s).removeClass('asc desc')

            # Add sort indicator (arrow) appropriately
            if $e.hasClass 'asc' then $e.removeClass('asc').addClass('desc')
            else $e.removeClass('desc').addClass('asc')

            # Toggle sort orer in collection
            order = 'asc'
            order = 'desc' if $e.hasClass 'desc'
            window.collection.sort = "#{id}:#{order}"
            window.collection.page = 0

            # Save sort preference on localStorage
            @saveSort()

            # Refetch collection based on new sort order
            @filterByFacet () =>


        # Save sort criteria on localStorage
        saveSort: () ->

            entity = window.settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            ls.sort = {} unless ls.sort
            ls.sort = window.collection.sort

            window.localStorage[entity] = JSON.stringify ls


        # Get sort criteria from localStorage or default configuration.
        getSort: () =>

            entity = window.settings.entity

            return window.settings.sort unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]

            return window.settings.sort unless ls.sort

            return ls.sort


        # Show a detailed view of an item in the rightmost pane
        showProfile: (item) =>

            # Destroy a groupView if any
            window.groupView?.destroy()

            # Create paneView with item data
            window.profileView = new ProfileView model: item

            # Render profile View
            $('.pane').html window.profileView.render().el

            # Shrink table to make space for the profile view
            $('#tableContainer, #thumbnailContainer').addClass 'onProfile'
            $('#footer, #columnsSelectWrapper').addClass 'onProfile'

            # Add extension code to the profileView
            @addProfileExtensions item


        # Show a Group view when many items have been selected
        showGroupView: () =>

            window.groupView?.destroy()
            window.profileView?.destroy()

            window.groupView = new GroupView unless window.groupView

            $('.pane').css('display', 'block').html window.groupView.render().el

            @navigate()


        showPaneView: () =>

            # profileViews and groupViews have preference over pane views
            return if window.profileView or window.groupView

            # Only show paneView when just 1 facet is selected
            return if @filterSelection.get().length isnt 1

            { field, cat } = @filterSelection.get()[0]

            return window.paneView?.close() unless window.pdata[cat]?[field]

            template = _.template $("#app > #extensions #pane-template").html()

            window.paneView = new PaneView template, t: window.pdata[cat][field]

            $('.pane').css('display', 'block').html window.paneView.render().el

            # Close pane only after successfull reset of facets
            $(window.paneView.el).bind 'close', () =>
                $(window.paneView.el).unbind 'close'
                @resetFacets () =>
                    window.paneView?.close()


        # ProfileClosed event notifies when a profile has been closed
        profileClosed: () =>

            # Catch this in your extension code!
            @trigger 'profileClosed'


        paneClosed: () =>

            @trigger 'paneClosed'

        # Destroy all item views, unbinding and removing html elements
        removeItemViews: () ->

            window.collection.each (item) ->

                item.view?.destroy()


        # Unbind all item views
        unbindItemViews: () ->

            window.collection.each (item) ->

                item.view?.release()


        # Renders containers for each category on the thumbnail view mode.
        renderCategoryView: (cb) =>

            template = _.template $('#category-template').html()

            c = window.settings.Schema.getClassifier()

            onProfile = ''
            onProfile = 'onProfile' if window.paneView or window.profileView

            html = "<ul class='thumbnailContainer #{onProfile}'></div>"
            $('#items').html html

            if settings.facets is 'tree'
                $('#items .thumbnailContainer').append template
                    cat: settings.itemType[1]
                    index: 1
                return cb()

            window.facets?.each (facet) =>

                return unless facet.get('name') is c.id

                window.categories = []

                presentCategories = _.extend {},

                    facet.get('fields').normal, facet.get('fields').special

                # Add the present categoriesin that have a predefined order
                _.each c.classifier, (cat) =>
                    if window.App.isCatInCats cat, presentCategories
                        if window.categories.indexOf(cat) is -1
                            window.categories.push(cat)
                        delete presentCategories[cat]

                # Add all other present categories
                _.each presentCategories, (amount, cat) =>
                    return if cat is 'null'
                    window.categories.push cat

                # Lastly, add 'not set' category
                window.categories.push 'null' if presentCategories['null']

                # Generate categories based on calculated order
                _.each window.categories, (category, index) =>
                    $('#items .thumbnailContainer').append template
                        cat: category
                        index: index
                cb()

        # Renders a table to show items in 'list' view.
        renderTableView: (cb) =>

            $('#items').html ''

            classes = "onProfile" if window.paneView or window.groupView

            $('#items').append _.template $('#table-template').html(),
                h: window.settings.Columns
                classes: classes

            cb()

        renderTreeView: () =>

            model = new Tree window.collection.models.slice(0)

            treeView = new TreeView model: model
            $('ul#facet').html('').append treeView.render().el


        isPresent: (node, col) ->
            present = no
            _.each col, (_node) ->
                present = yes if _node.get('id') is node.get('id')
            return present

        showExtendedView: (model) =>

            parent = window.collection.get(model.get('parentId'))?.get 'name'
            model.set 'parentId', parent if parent

            window.extendedView = new window.ExtendedView model: model

            $('#pane').append window.extendedView.render().el
            $('.pane').addClass 'extendedContainer'
            $('.pane').show()

            $('.field.active').removeClass 'active'
            $("##{model.id}.field").addClass 'active'

            @navigate()

        # Hide empty categories on thumbnail view after all items were added.
        hideEmptyCategories: () =>

            $("#items li ul").each (i, cat) ->

                $($(cat).parent()).show()

                $($(cat).parent()).hide() if $(cat).find('li').length is 0


        # Set the amount of items in the collection on the <em> next to the
        # inputSearch field and on each category title
        setTotals: (total) =>
            _.each $('#items ul'), (ul) =>
                amount = $(ul).find('li').length
                $('em', $(ul).siblings('label')).html amount

            return $('span#total').html total unless total is undefined
            $('span#total').html window.collection.total

            $('#search label').html @getItemType() + ' found'

        # Returns the tag of the items on the search label. i.e. people, items.
        getItemType: () =>
            itemType = window.settings.itemType[1]
            if window.collection.length is 1
                itemType = window.settings.itemType[0]
            return itemType

        # Utility to determine if the given category for a item is listed in
        # the predefined categories or not. It is not about felines!
        isCatInCats: (cat, cats) =>
            return yes unless cats[cat] is undefined or cats[cat] is null
            return no

        # After a change in the collection, re-selects items that remained
        updateSelection: () =>
            @hideLoadingAnimation()
            return unless @itemSelection.length
            return if window.profileView
            if @itemSelection.length and window.groupView
                return @showGroupView()
            window.groupView?.destroy()
            @clearSelection()

        # Deselect all items and clear selection array
        clearSelection: () =>
            $('.active', '#items').removeClass 'active'
            @itemSelection = new window.Collection
            @navigate()

        # Check if admin key is present in QS
        isAdmin: () =>

            return yes if window.settings.unrestricted

            uid = window.user.email or window.user.mail

            return yes unless uid

            return yes unless window.settings.admins and window.settings.admins.length

            return yes unless window.settings.admins.indexOf(uid) is -1

            no

        # Check if the entity is editable at all
        isEditable: () =>
            return no if window.settings.editable is false
            yes

        # Check if the profile view is editable at all
        isProfEditable: () =>
            return no unless @isEditable()
            return yes if @isAdmin()
            return no unless window.settings.Schema.getAdditionals().length
            return yes if window.user.email is window.profileView.model.get('email')
            no

        # Set browsers URL to point to the current application state
        navigate: (attr) =>
            url =  'qs/?' + @navigateURL().join('&')
            @router.navigate url, attr

        # Form QS from current application state
        navigateURL: () =>
            page = "page=#{window.collection.page}"
            rows = "&rows=#{window.collection.rows}"
            sort = "&sort=#{window.collection.sort}"

            display = ''
            display = "&display=#{window.collection.display}" if window.collection.display

            nav = [page + rows + sort + display]
            id = ''
            fs = ''
            search = ''

            @setWindowTitle()

            if @filterSelection.get().length
                f = []
                _.each @filterSelection.get(), (facet) ->
                    cat = encodeURIComponent facet.cat
                    field = encodeURIComponent facet.field
                    f.push "#{cat}:#{field}"
                fs = 'fs=' + f.join '|'

                @setWindowTitle "#{f.join()}"

            if window.profileView
                id = window.profileView.model.id || 'new'
                @setWindowTitle window.profileView.model?.getTitle()

            else if window.extendedView
                id = window.extendedView.model.id || 'new'
                @setWindowTitle window.extendedView.model?.getTitle()

            else if window.groupView
                id = []
                @itemSelection.each (m) =>
                    id.push m.get 'id'
                id = id.join '|'
                if @itemSelection.length is 1
                    id = '|' + @itemSelection.models[0].id
                @setWindowTitle "Group"

            search = $('#inputSearch').val().toLowerCase()

            nav.push "id=#{id}" if id
            nav.push fs if fs
            if window.settings.view isnt "list"
                nav.push "view=#{window.settings.view}"
            nav.push "s=#{encodeURI(search)}" if search

            nav


        # Item selection by using arrow keys.
        setMoveKeybindings: () =>

            @unsetMoveKeybindings()

            $('body').keyup @arrowUp
            $('body').keydown  @arrowDown


        # Unbind to stop responding to keypress events for movement
        unsetMoveKeybindings: () =>

            $('body').unbind 'keyup', @arrowUp

            $('body').unbind 'keydown', @arrowDown


        # Select item above currently selected item
        arrowUp: (e) =>

            @app = window.App

            selectedId = @app.itemSelection?.models[0]?.id

            elem = $("##{selectedId}", '#items')

            if  (e.which is 37 or e.which is 38) and elem.prev().length
                @app.selectOne $("##{selectedId}", '#items')
                    .prev()

            if  (e.which is 39 or e.which is 40) and elem.next().length
                @app.selectOne $("##{selectedId}", '#items')
                    .next()

            @app.navigate()


        # Select item below currently selected item
        arrowDown: (e) =>

            @app = window.App

            return unless @app.itemSelection.length

            return false if e.which >= 37 && e.which <= 40


        # Show a loading wheel in the middle of the items container, if the
        # items havent been rendered after 1 second
        showLoadingAnimation: () =>

            return if @loadingAnimation

            @loadingAnimation = setTimeout () =>
                $('span#loading').show()
              ,
                1000


        # Display error icon on controls section (top right corner)
        showError: () =>

            @hideLoadingAnimation()

            $('span#error').show()


        # Hide error icon
        hideError: () =>

            $('span#error').hide()


        # Hide the loading animation wheel
        hideLoadingAnimation: () =>

            clearTimeout @loadingAnimation

            @loadingAnimation = null

            $('span#loading').hide()


        # Parses a given Date into a readable formatted string (DD MMMM YYYY)
        formatDate: (date) =>

            if date instanceof Array then date = date[0]

            return '' unless date

            moment(date).format('DD MMM YYYY')

        # Parses a given Date into a readable formatted string (DD MMMM YYYY HH mm)
        formatDateTime: (datetime) =>

            if datetime instanceof Array then datetime = datetime[0]

            return '' unless datetime

            moment(datetime).format('DD MMM YYYY HH:mm')

        # Parses a given Number into a readable formatted string like 000,000.00
        formatNumber: (number) =>

            return unless number

            number = number.toString()

            pattern = /(-?\d+)(\d{3})/
            while pattern.test number
                number = number.replace pattern, "$1,$2"

            number


        # Show print view on a new window/ab
        print: () =>

            url = [ "page=#{window.collection.page}" ]

            url.push "rows=#{window.collection.total}"

            url.push "id=#{window.profileView.model.id}" if window.profileView

            url.push "id=#{window.extendedView.model.id}" if window.extendedView

            url.push "id=#{@groupIds()}" if window.groupView

            url = url.join '&'

            window.open 'print?' + url, '_blank'

        # Add animated effects to export menu
        exportMenu: () =>
            container   = $('#exporter')
            json        = $('#json')
            csv         = $('#csv')
            xml         = $('#xml')
            over        = () ->
                container.animate {'width': '111px'}, 200, () ->
                    json.css 'background-image' : 'url(../assets/json-text.png)'
                    xml.fadeIn 300
                    csv.fadeIn 300

            out = () ->
                json.css('background-image': 'url(../assets/export.png)')
                csv.fadeOut 300
                xml.fadeOut 300, () ->
                    container.animate({'width': '37px'}, 200)


            container.hover over, out

            json.click out
            xml.click out
            csv.click out


        # Export items to json on a new tab
        export: (e) =>
            to = $(e.target).attr('id')
            url = "#{@commonURL(0, window.collection.total)}"

            if @getFilterQS().fs.length
                url += '?' unless url.indexOf('?') isnt -1
                _.each @getFilterQS().fs, (f) =>  url += "&fs=#{f}"

            selection = ''
            _.each window.App.itemSelection.each(), (val, key) ->
                selection += "&fs=id:#{val.id}"

            url += selection if selection

            url += "&#{to}=true"

            window.open url, '_blank'


        # Hide facets container on the left
        disableFacets: () ->

            $('#index').hide()

            $('#content').addClass 'noFacets'


        # Create the entities menu
        generateEntitiesMenu: () ->

            entities = window.settings.entities

            _.each entities, (e) ->

                return if e.entity is window.settings.entity or e.hidden

                o = "<li id='#{e.entity}'><span>#{e.title}</span></li>"
                $("#entities ul", "#header").append o

            # Hide entities menu if only one entity available
            $('#entityTitle span').hide() if entities.length is 1


        # Redirect to an entity
        redirectToEntity: (e) ->

            entity = $(e.currentTarget).attr 'id'

            window.location = "/#{entity}/"


        # Create the columns menu that allows a user to choose visible colums
        # of the table on the list view.
        generateColumnsMenu: () ->

            template = _.template $('#columns-menu-template').html()

            _.each window.settings.Schema.get(), (field) =>

                $('#columnOptions ul').append template field: field


        # Open/Close entities menu
        toggleEntitiesMenu: (e) ->

            e.stopPropagation()

            return unless window.settings.entities.length > 1

            $('#entityTitle', '#header').toggleClass 'active'

            $("#entities", "#header").toggle()


        # Hide entities menu
        hideEntitiesMenu: (e) ->

            $('#entityTitle', '#header').removeClass 'active'

            $('#entities', '#header').hide()


        # Show columns button on top right corner of table view
        showColumnsBtn: (e) ->

            $('#columnsMenu').show()


        # Hide columns button
        hideColumnsBtn: (e) ->

            return if $('#columnOptions').css('display') is 'block'

            $('#columnsMenu').hide()


        # Show columns menu button on hover
        overColumnsMenu: (e) ->

            $('#columnsMenu').show()

            e.stopPropagation()


        # Open/Close columns menu
        toggleColumnsMenu: (e) ->

            e.stopPropagation()

            $('#columnOptions').toggle()

            $('#columnsMenu').toggleClass 'active'


        # Change visibility or background color of table columns
        handleColumnsMenuClick: (e) ->
            e.stopPropagation()

            conf =
                visible:
                    schemaFiled: 'index'
                    save:        @saveColumnSelection
                    action:      @toggleColumnVisibility
                colorize:
                    schemaFiled: 'colorize'
                    save:        @saveColumnColors
                    action:      @colorize

            $e = $(e.currentTarget)
            id = $e.parents('li').attr('id')
            cl = $(e.currentTarget).attr('class').replace('active', '').trim()

            return if cl == 'label'

            state = if $e.hasClass 'active' then false else true

            _.each window.settings.Schema.get(), (f) =>
                if f.id is id then f[conf[cl].schemaFiled] = state

            if state then $e.addClass 'active' else $e.removeClass 'active'

            conf[cl].save()
            conf[cl].action(id, state)

            @style.apply()

            #fix for problem with table header
            @addAll window.collection if cl == 'visible'

        # Show/hide a column from the table
        toggleColumnVisibility: (id) =>
            id = id.replace(new RegExp(':', 'g'), '\\\\:')
            $th =  $("table ##{id}").toggle()
            $td =  $("table .#{id}").toggle()


        showColumn: (id) =>
            id = id.replace(new RegExp(':', 'g'), '\\\\:')
            $th =  $("table ##{id}").show()
            $td =  $("table .#{id}").show()


        # Set the title for the window
        setWindowTitle: (t) ->

            title = window.settings?.title

            title += " - #{t}" if t

            $('head title').text(title).html()


        # Set resizable handler for facet index
        setIndexResizable: () =>

            $('#index').resizable

                handles: 'e'
                resize: @resizeIndex
                stop: @saveFacetWidth


        # Get Facet index Width
        getIndexWidth: () =>

            w = $('#index').width()

            return w if w

            entity = window.settings.entity

            return unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]
            w = parseFloat ls.css?.facet_width

            w


        # Resize facet index
        resizeIndex: (event, ui) =>

            return unless $('#index').is(':visible')

            w = window.App.getIndexWidth()

            $('#content').css 'left', w + 21
            $('#footer').css 'left', w + 21
            $('#innerIndex').width w - 10

            $('#content').trigger 'left'


        # Save column selection on local storage
        saveColumnSelection: () =>

            entity = window.settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}

            indexes = []
            _.each window.settings.Schema.getIndexes(), (s) ->
                indexes.push s.id
            ls.columns = {} unless ls.columns
            ls.columns = indexes

            window.localStorage[entity] = JSON.stringify ls


         # Set column selection from localStorage
        setColumnSelection: () =>

            entity = window.settings.entity

            ls = window.localStorage[entity]
            return unless ls

            ls = JSON.parse ls
            columns = ls.columns
            return unless ls.columns

            _.each window.settings.Schema.getIndexes(), (i) ->
                i.index = no

            _.each columns, (cid) ->
                f = window.settings.Schema.getFieldById cid
                f.index = yes

        # Save column color on local storage
        saveColumnColors: () =>

            entity = window.settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}

            colorize = []
            _.each window.settings.Schema.getColorized(), (s) ->
                colorize.push s.id

            ls.colorize = {} unless ls.colorize
            ls.colorize = colorize

            window.localStorage[entity] = JSON.stringify ls

        # Set column selection from localStorage
        setColumnColors: () =>

            ls = window.localStorage[entity]
            return unless ls

            ls = JSON.parse ls
            colorize = ls.colorize
            return unless ls.colorize

            _.each window.settings.Schema.getColorized(), (i) ->
                i.colorize = no

            _.each colorize, (cid) ->
                f = window.settings.Schema.getFieldById cid
                f.colorize = yes

        # Save width of facet index
        saveFacetWidth: (event, ui) =>

            entity = window.settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}

            w = $('#index').width()

            ls.css = {} unless ls.css
            ls.css['facet_width'] = w

            window.localStorage[entity] = JSON.stringify ls


        # Set Facet index width from localStorage
        setFacetWidth: () =>

            entity = window.settings.entity

            return unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]
            w = parseFloat ls.css?.facet_width

            $('#index').width w if w

            @resizeIndex()


        # Get an etiquette object with its ID
        getEtiquetteById: (id) =>

            etq = null

            _.each window.settings.etiquettes, (e) ->
                return etq = e if e.id is id

            etq


        # Get a mini etiquette for the pic in the table view
        getMiniEtiquette: (etiquettes) =>

            etq = null

            _.each etiquettes, (e) =>

                e = @getEtiquetteById e

                etq = e unless etq or !e?.mini

            etq


        # Determines etiquettes for a given item
        getItemEtiquettes: (model) =>

            return unless window.settings.Schema.getTuples().length

            facet = window.App.filterSelection.get()[0]
            tuple = window.settings.Schema.getTuples()[0].id
            [team, role] = tuple.split(':') #team

            etiquettes = []

            _.each model.get(tuple), (t) =>

                [ mteam, mrole ] = t.split(':')

                _.each mrole.split(','), (r) =>

                    return if etiquettes.indexOf($.trim(r)) isnt -1

                    etiquettes.push $.trim r

            etiquettes = @sortEtiquettes etiquettes

            etiquettes


        # Sort etiquettes from etiquettes.json order
        sortEtiquettes: (etiquettes) =>

            ordered = []

            _.each window.etiquettes, (e) =>

                ordered.push e.id if etiquettes.indexOf(e.id) isnt -1

            _.each etiquettes, (e) =>

                ordered.push e if ordered.indexOf(e) is -1

            ordered


        # Save open/closed state of facets on localStorage
        saveFacetOpenState: () =>

            entity = window.settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            ls.facetOpenState = @facetOpenState.get()

            window.localStorage[entity] = JSON.stringify ls


        # Set facet open/closed state of facets on localStorage
        setFacetOpenState: () =>

            entity = window.settings.entity

            return @initFacetOpenState() unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]
            fs = ls.facetOpenState

            return @initFacetOpenState() unless fs

            @facetOpenState.arr = fs


        # Initialize facet open/close state array
        initFacetOpenState: () =>

            window.facets.each (f) =>
                name = f.get 'name'
                field = window.settings.Schema.getFieldById name
                return if field.collapse
                @facetOpenState.push cat: name, field: 'facet'


        # Catch a click anywhere in the app
        documentClick: () =>

            @hideEntitiesMenu()

            $('#columnsMenu').hide().removeClass 'active'

            $('#columnOptions').hide()


        # Get the thumbnail label used in thumbnail views
        getThumbnailLabel: (model, schema) =>

            schema = new Schema schema

            label = []

            _.each schema.getThumbnails(), (f) =>  label.push model[f.id]

            label.join ' '


        # Checks if id is a valid tuple field
        isTuple: (id) =>

            tuples = window.settings.Schema.getTuples()

            allTuples = []

            _.each tuples, (t) =>

                allTuples.push t.id.split(':')[0]

                allTuples.push t.id.split(':')[1]

            return no if allTuples.indexOf(id) is -1
            return yes


        # Forms a string of selected item ids concatenated by '|'
        groupIds: () =>

            ids = []

            _.each window.App.itemSelection.each (m) =>

                ids.push m.get 'id'

            ids.join '|'


        # Check if browsing from an iPad/Android device
        isTablet: () =>

            return navigator.userAgent.match(/iPad|Android/i) isnt null

        # Colorize table columns
        colorize: (column = null, active = true) =>

            colorize = new window.Colorize

            if column?
                column = column.replace(new RegExp(':', 'g'), '\\:')

                return  $("td.#{column}").css 'background-color', '' unless active

                colorize.set({selector: "td.#{column}", mixWith: {r: 255, g: 255, b: 255}}).select().apply()
            else
                _.each window.settings.Schema.get(), (item) =>

                    if item.colorize? and item.colorize == true
                        column = item.id.replace(new RegExp(':', 'g'), '\\:')
                        colorize.set({selector: "td.#{column}", mixWith: {r: 255, g: 255, b: 255}}).select().apply()


        # Handle Gantt movement
        ganttMove: (e) =>

            field = $(e.currentTarget).parents('th')

            direction = $(e.currentTarget).attr('data-direction')

            event = e.type

            if event == 'mousedown'

                @ganttEvent = setInterval ( => @ganttMoveTo direction, field ), 100

            else

                window.clearInterval @ganttEvent


        # Move Gantt chart in left/right direction
        ganttMoveTo: (direction, field) =>

            configuration =
                left:
                    limit: 0
                    arrow: field.find '.ganttLeftArrow'
                    step: 40
                    week: -1
                right:
                    limit: 40
                    arrow: field.find '.ganttRightArrow'
                    step: -40
                    week: 1

            settings = configuration[direction]

            items = $(".#{field.attr('id')} .ganttItem")

            ganttBtn = field.find('.ganttBtn')

            arrow = settings.arrow

            position = @ganttPosition(field)

            if position[direction] == settings.limit + (-1 * settings.step)

                arrow.css {'background-color': '#CCC', 'cursor': 'default'}

            else if position[direction] == settings.limit

                return

            else

                ganttBtn.css {'background-color': '#999', 'cursor': 'pointer'}

            @ganttChangeWeek(settings.week, field)

            items.each (key, item) =>

                item = $(item)

                itemPosition = item.css('margin-left').replace('px', '')

                item.css('margin-left', "#{parseInt(itemPosition, 10) + settings.step}px")

                @ganttInfo item

        # Show/Hide notification relative to Gantt Cell
        ganttNotification: (e) =>

            type = e.type

            item = $(e.currentTarget)

            fieldId = item.parents('td').attr('class').split(' ')[0]

            header = $("##{fieldId}").find('.ganttHeaderContent')

            header.empty()

            header.append(item.attr('data-notification')) if type != 'mouseleave'

        # Show/Hide Gantt info
        ganttInfo: (item) =>

            info =
                left:     false
                centar:   false
                right:    false

            chartCell = item.parent()

            lInfo = chartCell.find('.ganttInfoL')

            cInfo = chartCell.find('.ganttInfoC')

            rInfo = chartCell.find('.ganttInfoR')

            visible = Math.floor chartCell.width() / 40

            start = parseInt item.attr('data-start'), 10

            end = parseInt item.attr('data-end'), 10

            current = parseInt item.attr('data-current'), 10

            info.left = true if start + 3 < current && current <= end + 3

            info.right = true if end + 3 >= current + visible and current + visible >= start + 3

            info.center = true if current + visible < start + 3 || current > end + 3

            if current < end + 3 then cInfo.css('left' , chartCell.width() - 80) else cInfo.css('left' , 0)

            if current < end + 3 then cInfo.css('left' , chartCell.width() - 80) else cInfo.css('left' , 0)

            if current < end + 3 then cInfo.css('left' , chartCell.width() - 80) else cInfo.css('left' , 0)

            start = if start < 1 then "&lt; #{start + 52}" else "&lt; #{start}"

            end = if end > 52 then "#{end - 52} &gt;" else "#{end} &gt;"

            lInfo.html(start)

            cInfo.html("#{start} #{end}")

            rInfo.html(end)

            if info.left then lInfo.show() else lInfo.hide()

            if info.center then cInfo.show() else cInfo.hide()

            if info.right then rInfo.show() else rInfo.hide()


        # Show/Hide info for all Gantt intems
        ganttInfoInit: () =>
            $('.ganttItem').each (key, item) =>
                @ganttInfo $(item)


        # Chnage week
        ganttChangeWeek: (step, field) =>

            items = $(".#{field.attr('id')} .ganttItem")

            current = parseInt items.attr('data-current'), 10

            items.attr('data-current', current + step)


        # Calculate poistion of Gantt chart
        ganttPosition: (field) =>

            position =
                left:     0
                right:    0
                maxWidth: 0

            items = $(".#{field.attr('id')} .ganttItem")

            items.each (key, item) =>

                left = parseInt $(item).css('margin-left').replace('px', ''), 10

                width = $(item).find('.ganttCell').length  * 40

                right = left + width

                position.left = left if left < position.left

                position.right = right if right > position.right

            position.maxWidth = position.right - position.left

            position


        # Set width of Gantt items to be == to item with largest width
        ganttWidthFix: () =>
            $('th[data-type="gantt"]').each (key, field) =>
                field = $(field)
                position = @ganttPosition field
                $(".#{field.attr('id')} .ganttItem").css 'width', position.maxWidth


        # Looks for an entity in the entities list and returns its settings
        getEntitySettings: (id) =>
            entity = {}
            _.each window.entities, (e) ->
                return entity = e if e.entity is id
            entity


        # Keep an array of the selected facet fields
        # TODO Use a backbone collection for this
        filterSelection: new window.FacetArray

        # Keep an array of the facets expanded/folded state
        # TODO Use a backbone collection for this
        facetOpenState: new window.FacetArray

        # Array to store the selected item ids
        itemSelection: new window.Collection


    #Lets create our app!
    @App = new AppView
