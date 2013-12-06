#### Item View

# BaseItemView defines the basic view for an item. This will be
# extended to a thumbnail class or a list view class.

$ ->

    class window.BaseItemView extends Backbone.View

        # On click, show a profile view (right panel) for this item.
        events:

            "click" : "showProfile"


        #### Initializes the item view
        # 1. Attach id to HTML element to identify clicked elements easier.
        # 2. Bind model destruction to this view's destruction event.
        # 3. Give the model information about the view in which its being showed
        # 4. If its on the selected members list, select it.
        # 5. Redundantly checks if this item is being displayed in the profile
        # view and selects it if it is.
        initialize: () =>

            @$el.attr 'id', @model.id

            @model.bind 'destroy',  @remove,  @
            @model.view = @

            if window.profileView?.model.id is @model.id
                return window.App.selectOne @$el

            if window.extendedView?.model.id is @model.id
                return window.App.selectOne @$el

        #### Render item
        # Render an item view
        render: () =>

            @$el.html @template m: @model
            @


        #### Show Profile view
        # * If pressing Ctrl, Alt or Shift, use multiple selection.
        # * If not, deactivate all other items and activate this item only.
        # * Update URL to point to new state
        showProfile: (e) =>

            $e = $(e.currentTarget)

            # By pressing Ctrl or Alt keys, uses multiple selection.
            return @ctrlSelect $e if e.ctrlKey or e.altKey

            # Also by pressing Shift key and clicking.
            return @shiftSelect $e if e.shiftKey

            # Deactivate all other active items and close their profileViews.
            if $e.hasClass('active') and window.profileView

                @removeFromSelection $e

                return window.profileView?.close()

            # Mark as selected and show profile view
            window.App.selectOne $e

            # Change URL to point to the new state
            window.App.navigate()


        #### Multiple Selection


        #### Select with Shift
        # * Selects All items between the first clicked item and the current
        # clicked item.
        shiftSelect: ($e) =>

            all = $('ul li, tr.selectable', '#items')

            if !window.firstActiveItem
                window.firstActiveItem = $e.attr 'id'

            first = all.index $("##{window.firstActiveItem}", '#items')
            first = all.index $($('.active', '#items')[0]) if first is -1
            first = 0 if first is -1
            last = all.index $e[0]

            $('.active', '#items').removeClass('active')

            window.App.itemSelection = new window.Collection

            for i in [first..last]
                window.App.addToSelection $(all[i])

            window.App.showGroupView()

            window.App.navigate()


        #### Selects/Deselects with Ctrl or Alt.
        # * If not in the selection, add to selection, otherwise remove it.
        ctrlSelect: ($e) =>

            return @removeFromSelection $e if $e.hasClass 'active'

            window.App.addToSelection $e

            window.App.showGroupView()

            window.App.navigate()


        #### De-select
        # Remove one item from the selected items and update group view
        removeFromSelection: ($e) =>

            id = $e.attr 'id'

            return unless window.App.itemSelection.get id

            window.App.itemSelection.remove id

            $e.removeClass 'active'

            if window.App.itemSelection.length

                window.App.navigate()

                return window.App.showGroupView()

            window.groupView?.close() if window.App.itemSelection.length is 0

            window.profileView?.close()

            window.App.navigate()


        #### Destroy item view
        # Propperly unbind and remove item view from DOM.
        destroy: () =>

            @unbind()

            @model.unbind 'destroy',  @rem,  @

            @model.view = null

            @remove()


        release: () =>

            @unbind()

            @model.unbind 'destroy',  @rem,  @

            @model.view = null


    #### Thumbnail View
    # Extend base item view and define a thumbnail type template
    class window.ItemThumbnailView extends window.BaseItemView


        tagName: 'li',


        template: _.template $('#item-template').html()


        initialize: () =>

            super

            @$el.addClass 'thumbnail'


    #### List View
    # Extend base item view and define a list type template

    class window.ItemListView extends window.BaseItemView


        tagName: 'tr',


        template: _.template $('#item-table-template').html()


        initialize: () =>

            super

            @$el.addClass 'selectable'

            @$el.addClass 'active' if window.App.itemSelection.get @model.get('id')
