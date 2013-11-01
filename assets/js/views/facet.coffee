#### Facet View
#
# A Facet view is a facet category (root level on facet indexes). It has
# has a type name (i.e. Team) and a list of distinct values along a count
# for the amount of items that belong to it. It also allows to filter the
# items collection.

$ ->

    class window.FacetView extends Backbone.View


        tagName: 'li'


        template: _.template $('#facet-template').html()


        events:
            "click h4"                  : "toggleNode"
            "click span.fold"           : "toggleNode"
            "click .field"              : "onClick"


        initialize: () ->
            @app = window.App

        render: () =>

            @$el.html @template @model.toJSON()

            # Set data-name as the category (i.e. team)
            @$el.attr 'data-name',  @model.get 'name'

            # Set data-title as the id of the facet (i.e. Shop)
            @$el.attr 'data-title', 'facet'

            @


        # Handle a click on a facet field. Add facet to selection, filter
        # with new selection and activate field
        onClick: (e) =>

            $e    = $(e.currentTarget)
            cat   = $e.attr 'data-name'
            name  = $e.attr 'data-title'

            if e.ctrlKey or e.altKey
                @app.filterSelection.toggleMult cat: cat, field:name
            else
                @app.filterSelection.toggle cat:cat, field:name

            @app.showLoadingAnimation()

            @app.filterByFacet () =>

                window.paneView?.close() if @app.filterSelection.get().length != 1

                $e.toggleClass 'active'

                $('span.amount', $e).toggleClass 'active'

                $('span#reset')
                    .show() unless @app.filterSelection.get().length is 0

                @app.showPaneView()

            $('#inputSearch').focus() unless @app.isTablet()


        # Open/Close a facet
        toggleNode: (e) =>

            $e = $(e.currentTarget)

            if $e.hasClass 'facetParent'
                $e = $e.siblings 'span' unless $e.hasClass 'fold'
                $s = $e.siblings 'ul'
                cat = $s.attr 'id'
                field = $s.attr 'data-title'
            else
                $p = $e.parent()
                cat = $p.attr 'data-name'
                field = $p.attr 'data-title'
                $s = $("ul[data-name='#{cat}'][data-title='#{field}']", $p)

            if $e.hasClass 'open'
                $s.hide()
                @app.facetOpenState.toggle cat: cat, field: field
                @app.saveFacetOpenState()
                return $e.removeClass('open').html '+'

            # Expand facet node
            $s.css('display', 'block')
            @app.facetOpenState.push cat: cat, field: field
            $e.addClass('open').html '–'

            # Save facet state on localStorage
            @app.saveFacetOpenState()
