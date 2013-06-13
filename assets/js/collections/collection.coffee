#### Items Collection

class @Collection extends Backbone.Collection

    # Contains items!
    model: window.Item,

    url: () =>
        url = window.App.commonURL @page, @rows
        url

    parse: (res) ->
        @total = res.response?.numFound
        return res.response?.docs
        return []

    # Paginated results page
    page: 0

    # Total amount of items
    total: 0

    # Amount of results per page
    rows: 10
