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


        render: () =>

            @$el.html @template @model.toJSON()

            # Set data-name as the category (i.e. team)
            @$el.attr 'data-name',  @model.get 'name'

            # Set data-title as the id of the facet (i.e. Shop)
            @$el.attr 'data-title', 'facet'

            @
