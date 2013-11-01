#### Tree View
#
# A Tree view displays a collection of items in a hierarchical way.
# Looks exactly like the facet view, but instead of filtering it
# selects an item and opens a detailed view.

$ ->

    class window.TreeView extends Backbone.View


        tagName: 'li'


        template: _.template $('#tree-template').html()


        events:
            "click h4"          : "toggleNode"
            "click span.fold"   : "toggleNode"
            "click .field"      : "onClick"


        initialize: () ->
            @app = window.App

            @app.bind 'paneClosed', @deactivate, @


        deactivate: () =>

            $('.field.active').removeClass 'active'


        render: () =>

            @$el.html @template @model

            @


        # Open/Close a facet section
        toggleNode: (e) =>

            $e = $(e.currentTarget)
            $e = $e.siblings('span') unless $e.hasClass 'fold'
            $ul = $e.siblings('ul')
            id = $ul.attr 'id'

            if $e.hasClass 'open'
                $ul.hide()
                return $e.removeClass('open').html '+'

            # Expand facet node
            $ul.css('display', 'block')
            $e.addClass('open').html '–'


        # Handles expansion and collapse of facet fields when clicking on '+'
        # or '-' icons next to the facet field label.
        toggleSubfields: (e) =>

            $e  = $(e.currentTarget)
            $p = $e.parent()
            id = $e.attr 'id'

            if $e.hasClass 'open'
                $("ul##{id}", $p).hide()
                return $e.removeClass('open').html '+'

            $("ul##{id}", $p).show()
            $e.addClass('open').html '–'


        onClick: (e) =>

            $e  = $(e.currentTarget)
            id  = $e.attr 'id'

            return  window.extendedView.close() if $e.hasClass 'active'

            @app.selectOne $e
