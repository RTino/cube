#### Cube App
#
# The cube is composed of a nodejs backend and a backbonejs frontend. This is
# the start of the backbonejs application. Please checkout cube.coffee to
# find more about the backend.
#
# You can also visit our github page and repository
#
# http://zalando.github.io/cube/
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
            "keyup #inputSearch"            : "onSearchInput"
            "click a#add.btn"               : "addNewItem"
            "click ul#facet ul li .field"   : "handleFacetClick"
            "click span#reset a"            : "resetAllFilters"
            "click span#view"               : "toggleViewMode"
            "click ul#facet li ul span.fold": "toggleFacetSubfields"
            "click ul#facet>li>span.fold"   : "toggleFacetNode"
            "click ul#facet>li>h4"          : "toggleFacetNode"
            "click span#print"              : "print"
            "click span#json"               : "toJson"
            "click #entityTitle"            : "toggleEntitiesMenu"
            "click #columnsMenu"            : "toggleColumnsMenu"
            "click #columnOptions ul li"    : "toggleColumnVisibility"
            "click #entities ul li"         : "redirectToEntity"
            "click span#pageL"              : "previousPage"
            "click span#pageR"              : "nextPage"
            "click span#jumpToFirst"        : "jumpToFirst"
            "click span#jumpToLast"         : "jumpToLast"
            "click #footer li"              : "jumpToPage"
            "click table .th-inner"         : "sortTable"
            "mouseenter #columnsMenu"       : "overColumnsMenu"
            "mouseenter .th-inner"          : "showColumnsBtn"
            "mouseleave .th-inner"          : "hideColumnsBtn"
            "click"                         : "documentClick"

        #### Initialize
        initialize: () =>

            # Create router object
            @router = new window.Routes

            # Set application settings from settings.json
            @setAppSettings()

            # Set collection settings like sort criteria or amount of rows
            @setColSettings()

            # Set the schema ffor the entity
            @createSchema()

            #### Collections bindings

            # Display any new items in the container.
            window.collection.bind  'add',      @addOne,        @

            # Updte facets whenever an item is added to the collection
            window.collection.bind  'add',      @updateFacets,  @

            # Redraw items whenever the collection is resetted.
            window.collection.bind  'reset',    @reset,         @

            # Draw all facets whenever the collection is resetted.
            window.facets.bind      'reset',    @addAllFacets,  @

            # Get extension templates and start app on success.
            @getExtensions () =>

                @start()


        #### Start
        start: =>

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

            # Create the columns menu
            @generateColumnsMenu()

            # Create the entities menu
            @generateEntitiesMenu()

            # Fetch facets and start backbone history right after. This will
            # route to window.Settings.Separator which in turn will fetch
            # items and draw app.
            @initFacets()

            # Start app with search input text focused
            $('#inputSearch').focus() unless @isTablet()

            # Hide Add item button unless admin key is present
            @setAdminState()

            # Profile additional info open/close state. Default is closed.
            @setProfileState()

            # Listen for arrow keys to move between items
            @setMoveKeybindings()


        # Facet collection init
        initFacets: () =>

            #Fetch facets from database
            window.facets.fetch success: () =>

                # Hide any ajax error on success
                @hideError()

                # Set expanded/folded state on facet HTML index
                @setFacetOpenState()

                # App is ready to start navigation history
                Backbone.history.start()

            , error: () =>

                # Show error icon on controls section (top right)
                @showError()


        # Settings object holds all configuration parameters
        setAppSettings: () ->

            # Entity settings
            settings = window.settings

            # Etiquettes definition (etiquettes.json)
            settings.etiquettes = window.etiquettes

            # Available entities
            settings.entities = window.entities

            # Global Settings object
            window.Settings = settings


        # Set collection settings like sort and rows.
        setColSettings: () ->

            # Sort criteria (i.e. name:asc)
            window.collection.sort = @getSort()

            # Rows to show (default: 50)
            window.collection.rows = window.Settings.rows


        # Set the application's title on top left corner (top entities menu)
        setAppTitle: () =>

            # Show name on top left corner and window title
            $('#header #entityTitle h1').html window.Settings?.title

            # Show arrow on title if is possible to chose other entity
            if window.Settings.entities.length > 1
                $('#header #entityTitle').addClass 'selectable'


        # Set the view mode to either thumbnail or list
        setViewMode: () =>

            # No picture? no thumbnail view.
            pictureFields = window.Settings.Schema.getPictures()
            $('span#view').hide() if pictureFields.length is 0

            # Set list view as default if in settings
            $('span#view').addClass 'list' if window.Settings?.view is 'list'


        # Set the facet pane state
        setAppFacetsState: () =>

            # Get facet fields from Schema
            facets = window.Settings.Schema.getFacets()

            # If there are no facet fields, hide the facet pane
            return @disableFacets() unless facets.length

            # Resize the facet pane to user preferences
            @setIndexResizable()


        # Set the application edit capabilities
        setAdminState: () =>

            # Check if entity is editable and user has provided admin key
            if @isEditable() and @isAdmin()

                $('a#add.btn').css 'display', 'block'


        # Save profile state
        setProfileState: () =>

            window.additionalOpen = no


        # Get extesion HTML/JS code and append it to current dom.
        getExtensions: (cb) =>

            $.get 'extensions', (exthtml) ->

                # Append HTML on extension container
                $('#app > #extensions').html exthtml

                return cb() unless $("#app > #extensions #controls").length

                # Get extension controls and append them
                t = _.template $("#app > #extensions #controls").html()
                $('#controls #extensions').append t({})

                # Initialize extended javascript
                window.extensions?.init?()

                cb()


        # Add Profile extension code
        addProfileExtensions: (item) =>

            return unless $('#app > #extensions #details-template').length

            template = _.template $('#app > #extensions #details-template')
                .html()

            $('#pane #extensions').append template t:item


        # Get schema and attach it to our Settings object
        createSchema: ->

            window.Settings?.Schema = new window.Schema window.schema


        # Switches between list view mode and thumbnail view mode
        toggleViewMode: () =>

            # Choose view mode to toggle to
            v = if window.Settings.view is 'list' then 'thumbnail' else 'list'

            # Set new view mode
            window.Settings.view = v

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

            return @addAll window.collection


        # Add one item to the items container. Either in thumnail mode
        # (picture and name) or in list mode (pic, full name, teams, etc.)
        addOne: (m) =>

            view = window.Settings.view

            return window.App.addOneThumbnail(m) if view is 'thumbnail'

            window.App.addOneList m


        # Add one item to the table of items (list view mode)
        addOneList: (item) =>

            # Create a new list view
            view = new ItemListView model: item

            # Append it to the tabel
            @$("table tbody", "#items").append view.render().el


        # Add one item with a thumbnail view
        addOneThumbnail: (item) =>

            # Create a new Thumbnail view
            view = new ItemThumbnailView model: item

            # Choose category to append it to appropriate container
            cat = item.get window.Settings.Schema.getClassifier().id
            cat = cat[0] if typeof cat is typeof []
            cat = 'null' if cat is undefined
            cat = window.categories.indexOf cat

            # Append to category container
            @$("li\#category-#{cat} ul", '#items').append view.render().el


        # Render all items in the given collection
        addAll: (col, cb) =>

            view = window.Settings.view

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

                cb() if cb


        # Create an empty profileView to add an item
        addNewItem: () =>

            @clearSelection()

            @showProfile new window.Item

            window.profileView.form()

            @navigate()


        # Select one item with a normal click. Delete previous selection if
        # present and save selected item as the firstActiveItem
        selectOne: ($e, attr) =>

            @clearSelection()

            @addToSelection $e

            @scrollToSelection $e

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

            eHeight   = if window.Settings.view is 'list' then 39 else 196

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

                error: () =>

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

                    error: () =>

                        @showError()

        # Fetch a collection by facet filter. Sets page back to 0.
        filterByFacet: (cb) =>

            window.collection.page = 0

            @filterByPage cb

        # Updates the facet collection
        updateFacets: (m) =>

            # Re-fetch facets from DB
            @fetchFacet () =>

                # Re-fetch items based on the new filter selection
                @fetchItems

                    data: @getFilterQS()

                    success: (col) =>

                        @genPageIndex()
                        @hideError()
                        @showPaneView()

                        # If the colection isn't empty, we are done
                        return if col.length

                        # Otherwise reset the app by clearing all filters
                        $('#inputSearch').val ''
                        @resetAllFilters()

                    error: () =>

                        @showError()

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

                    error: () =>

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

                    error: () =>
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
                return $('#footer').show()

            $('#content').addClass 'noPages'
            $('#footer').hide()

        # Handle a click on a facet field. Add facet to selection, filter
        # with new selection and activate field
        handleFacetClick: (e) =>

            $e    = $(e.currentTarget)
            cat   = $e.attr 'data-name'
            name  = $e.attr 'data-title'

            if e.ctrlKey or e.altKey
                @filterSelection.toggleMult cat: cat, field:name
            else
                @filterSelection.toggle cat:cat, field:name

            @showLoadingAnimation()

            @filterByFacet () =>

                window.paneView?.close() if @filterSelection.get().length != 1

                $e.toggleClass 'active'

                $('span.amount', $e).toggleClass 'active'

                $('span#reset')
                    .show() unless @filterSelection.get().length is 0

                @showPaneView()

            $('#inputSearch').focus() unless @isTablet()


        # Reset filtes and set app state. User clicked on "reset filters" link.
        onResetFilter: () =>

            @resetFilter () =>

                @navigate()


        # Set facets expanded/folded state
        setFacetState: (s) =>

            @filterSelection.set s

            _.each s, (c) =>

                $f = $(".field[data-title='#{c.field}']",
                  "ul#facet li ul\##{c.cat}")
                $f.addClass 'active'
                $('span.amount', $f).addClass 'active'

                $p = $f.parent()
                $('>span.fold', $p.parents()).addClass('open').html '–'
                $('>ul', $p.parents()).css('display', 'block')

            _.each @facetOpenState.get(), (c) =>

                $f = $("li[data-name='#{c.cat}'][data-title='#{c.field}']")
                $('>span.fold', $f).addClass('open').html '–'
                $('>ul', $f).css('display', 'block')

            @showPaneView()


        # Update facets selection state
        updateFacetState: () =>

            @trigger 'updateFacetState'

            $('#pane').hide() unless window.groupView or window.paneView

            # New filter selection
            nf = []

            # Add remaining selected filters to new filter selection
            _.each @filterSelection.get(), (c) =>
                $e = $("span[data-type='#{c.cat}'][data-title='#{c.field}']")
                $f = $(".field[data-title='#{c.field}']",
                      "ul#facet li ul\##{c.cat}")
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

            _.each window.Settings.Schema.getFacets(), (field) ->
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

            entity = window.Settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            ls.sort = {} unless ls.sort
            ls.sort = window.collection.sort

            window.localStorage[entity] = JSON.stringify ls


        # Get sort criteria from localStorage or default configuration.
        getSort: () =>

            entity = window.Settings.entity

            return window.Settings.sort unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]

            return window.Settings.sort unless ls.sort

            return ls.sort


        # Open/Close a facet section
        toggleFacetNode: (e) =>

            $e = $(e.currentTarget)
            $e = $e.siblings('span') unless $e.hasClass 'fold'
            $ul = $e.siblings('ul')
            cat = $ul.attr 'id'

            if $e.hasClass 'open'

                # Collapse facet node
                $ul.hide()
                @facetOpenState.toggle cat: cat, field: 'facet'
                @saveFacetOpenState()
                return $e.removeClass('open').html '+'

            # Expand facet node
            $ul.css('display', 'block')
            @facetOpenState.push cat: cat, field: 'facet'
            $e.addClass('open').html '–'

            # Save facet state on localStorage
            @saveFacetOpenState()


        # Handles expansion and collapse of facet fields when clicking on '+'
        # or '-' icons next to the facet field label.
        toggleFacetSubfields: (e) =>

            $e  = $(e.currentTarget)
            $p = $e.parent()
            cat = $p.attr 'data-name'
            field = $p.attr 'data-title'

            if $e.hasClass 'open'
                $("ul[data-name='#{cat}'][data-title='#{field}']", $p).hide()
                $e.removeClass 'open'
                @facetOpenState.toggle cat:cat, field:field
                return $e.removeClass('open').html '+'

            @facetOpenState.push cat: cat, field: field
            $("ul[data-name='#{cat}'][data-title='#{field}']", $p).show()
            $e.addClass('open').html '–'


        # Show a detailed view of an item in the rightmost pane
        showProfile: (item) =>

            # Destroy a groupView if any
            window.groupView?.destroy()

            # Create paneView with item data
            window.profileView = new ProfileView model: item

            # Render profile View
            $('#pane').html window.profileView.render().el

            # Shrink table to make space for the profile view
            $('#tableContainer, #thumbnailContainer').addClass 'onProfile'
            $('#footer, #columnsSelectWrapper').addClass 'onProfile'

            # Add extension code to the profileView
            @addProfileExtensions item


        # Show a Group view when many items have been selected
        showGroupView: () =>

            window.profileView?.destroy()

            window.groupView = new GroupView unless window.groupView

            $('#pane').css('display', 'block').html window.groupView.render().el

            @navigate()

        # Show a customazible view on the right pane for a selected facet. This
        # could be understood as a detailed pane for a selected facet.
        showPaneView: () =>

            # profileViews and groupViews have preference over pane views
            return if window.profileView or window.groupView

            # Only show paneView when just 1 facet is selected
            return if @filterSelection.get().length isnt 1

            { field, cat } = @filterSelection.get()[0]

            return window.paneView?.close() unless window.pdata[cat]?[field]

            template = _.template $("#app > #extensions #pane-template").html()

            window.paneView = new PaneView template, t: window.pdata[cat][field]

            $('#pane').css('display', 'block').html window.paneView.render().el

            # Close pane only after successfull reset of facets
            $(window.paneView.el).bind 'close', () =>
                $(window.paneView.el).unbind 'close'
                @resetFacets () =>
                    window.paneView?.close()


        # ProfileClosed event notifies when a profile has been closed
        profileClosed: () =>

            # Catch this in your extension code!
            @trigger 'profileClosed'


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

            c = window.Settings.Schema.getClassifier()

            onProfile = ''
            onProfile = 'onProfile' if window.paneView or window.profileView

            html = "<ul class='thumbnailContainer #{onProfile}'></div>"
            $('#items').html html

            window.facets?.each (facet) =>

                return unless facet.get('name') is c.id

                window.categories = []

                template = _.template $('#category-template').html()

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
                h: window.Settings.Columns
                classes: classes

            cb()


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
            itemType = window.Settings.itemType[1]
            if window.collection.length is 1
                itemType = window.Settings.itemType[0]
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
            return yes if window.Settings.editable is true
            qs = window.location.search.split('?')[1]
            new RegExp('admin=').test qs

        # Check if the entity is editable
        isEditable: () =>
            return yes if window.Settings.editable isnt false
            no

        # Set browsers URL to point to the current application state
        navigate: (attr) =>
            url =  'qs/?' + @navigateURL().join('&')
            @router.navigate url, attr

        # Form QS from current application state
        navigateURL: () =>
            page = window.collection.page
            rows = window.collection.rows
            sort = window.collection.sort
            nav = ["page=#{page}&rows=#{rows}&sort=#{sort}"]
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
            if window.Settings.view isnt "list"
                nav.push "view=#{window.Settings.view}"
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

            if typeof date is typeof [] then date = date[0]

            return '' unless date

            monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
                "Aug", "Sep", "Oct", "Nov", "Dec" ]

            d = new Date date
            d = [ d.getDate(), monthNames[d.getMonth()], d.getFullYear() ]
            d.join ' '


        # Show print view on a new window/ab
        print: () =>

            url = [ "page=#{window.collection.page}" ]

            url.push "rows=#{window.collection.total}"

            url.push "id=#{window.profileView.model.id}" if window.profileView

            url.push "id=#{@groupIds()}" if window.groupView

            url = url.join '&'

            window.open 'print?' + url, '_blank'


        # Export items to json on a new tab
        toJson: () =>

            url = "#{@commonURL(0, window.collection.total)}"

            if @getFilterQS().fs.length
                url += '?'
                _.each @getFilterQS().fs, (f) =>  url += "&fs=#{f}"

            url += "&json=true"

            id = window.profileView?.model.id

            url = "collection/#{id}" if window.profileView

            url = "collection/#{@groupIds()}" if window.groupView

            window.open url, '_blank'


        # Hide facets container on the left
        disableFacets: () ->

            $('#index').hide()

            $('#content').addClass 'noFacets'


        # Create the entities menu
        generateEntitiesMenu: () ->

            entities = window.Settings.entities

            _.each entities, (e) ->

                return if e is window.Settings.entity

                o = "<li id='#{e}'><span>#{e}</span></li>"
                $("#entities ul", "#header").append o

            # Hide entities menu if only one entity available
            $('#entityTitle span').hide() if entities.length is 1


        # Redirect to an entity
        redirectToEntity: (e) ->

            entity = $(e.currentTarget).attr 'id'

            adminKey = if @isAdmin() then "?admin=yes" else ''

            window.location = "/#{entity}/#{adminKey}"


        # Create the columns menu that allows a user to choose visible colums
        # of the table on the list view.
        generateColumnsMenu: () ->

            template = _.template $('#columns-menu-template').html()

            _.each window.Settings.Schema.get(), (field) =>

                $('#columnOptions ul').append template field: field


        # Open/Close entities menu
        toggleEntitiesMenu: (e) ->

            e.stopPropagation()

            return unless window.Settings.entities.length > 1

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


        # Show/hide a column from the table
        toggleColumnVisibility: (e) ->

            e.stopPropagation()

            $e = $(e.currentTarget)
            id = $e.attr 'id'

            if $e.hasClass 'active'
                _.each window.Settings.Schema.get(), (f) =>
                    if f.id is id then f.index = false
                $e.removeClass 'active'
                @saveColumnSelection()
                return @addAll window.collection

            _.each window.Settings.Schema.get(), (f) =>
                if f.id is id then f.index = true

            $e.addClass 'active'

            @saveColumnSelection()

            @addAll window.collection


        # Set the title for the window
        setWindowTitle: (t) ->

            title = window.Settings?.title

            title += " - #{t}" if t

            $('head title').html title


        # Set resizable handler for facet index
        setIndexResizable: () =>

            $('#index').resizable

                handles: 'e'
                resize: @resizeIndex
                stop: @saveFacetWidth


        # Resize facet index
        resizeIndex: (event, ui) =>

            width = $('#index').width()

            $('#content').css 'left', width + 21
            $('#footer').css 'left', width + 21
            $('#innerIndex').width $('#index').width() - 10


        # Save column selection on local storage
        saveColumnSelection: () =>

            entity = window.Settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}

            indexes = []
            _.each window.Settings.Schema.getIndexes(), (s) ->
                indexes.push s.id
            ls.columns = {} unless ls.columns
            ls.columns = indexes

            window.localStorage[entity] = JSON.stringify ls


        # Set column selection from localStorage
        setColumnSelection: () =>

            entity = window.Settings.entity

            ls = window.localStorage[entity]
            return unless ls

            ls = JSON.parse ls
            columns = ls.columns
            return unless ls.columns

            _.each window.Settings.Schema.getIndexes(), (i) ->
                i.index = no

            _.each columns, (c) ->
                window.Settings.Schema.getField c, (f) ->
                    f.index = yes


        # Save width of facet index
        saveFacetWidth: (event, ui) =>

            entity = window.Settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}

            w = $('#index').width()

            ls.css = {} unless ls.css
            ls.css['facet_width'] = w

            window.localStorage[entity] = JSON.stringify ls


        # Set Facet index width from localStorage
        setFacetWidth: () =>

            entity = window.Settings.entity

            return unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]
            w = parseFloat ls.css?.facet_width

            $('#index').width(w) if w

            @resizeIndex()


        # Get an etiquette object with its ID
        getEtiquetteById: (id) =>

            etq = null

            _.each window.Settings.etiquettes, (e) ->
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

            return unless window.Settings.Schema.getTuples().length

            facet = window.App.filterSelection.get()[0]
            tuple = window.Settings.Schema.getTuples()[0].id
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

            entity = window.Settings.entity

            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            ls.facetOpenState = @facetOpenState.get()

            window.localStorage[entity] = JSON.stringify ls


        # Set facet open/closed state of facets on localStorage
        setFacetOpenState: () =>

            entity = window.Settings.entity

            return @initFacetOpenState() unless window.localStorage[entity]

            ls = JSON.parse window.localStorage[entity]
            fs = ls.facetOpenState

            return @initFacetOpenState() unless fs

            @facetOpenState.arr = fs


        # Initialize facet open/close state array
        initFacetOpenState: () =>

            window.facets.each (f) =>

                @facetOpenState.push cat: f.get('name'), field: 'facet'


        # Catch a click anywhere in the app
        documentClick: () =>

            @hideEntitiesMenu()

            $('#columnsMenu').hide().removeClass 'active'

            $('#columnOptions').hide()


        # Get the thumbnail label used in thumbnail views
        getThumbnailLabel: (m) =>

            thumbnails = window.Settings.Schema.getThumbnails()

            label = []

            _.each thumbnails, (f) =>  label.push m[f.id]

            label.join ' '


        # Gets the key name for the img fields, useful for templates.
        getPicKey: () =>

            pictures = window.Settings.Schema.getPictures()

            return pictures[0]['id'] if pictures[0]


        # Checks if id is a valid tuple field
        isTuple: (id) =>

            tuples = window.Settings.Schema.getTuples()

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
