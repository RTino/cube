#### Print View
#
# Shows a selected piece of information from the main backbone app for printing

$ =>

    # Actually a stripped down backbone application which uses the collection
    # from the parent window to get items information. It as only two views:
    # list view and profile view.
    class AppView extends Backbone.View


        el: $('#print')


        # Template for list view
        templateList: _.template $('#item-table-template').html()


        # Template for profile view
        templateProfile: _.template $('#details-print-template').html()


        #### Initialize app
        # 1. Get ID from querystring
        # 2. Get profile key from querystring to know if it should show a
        # list view or a profile view.
        # 3. Show profile view or list view accordingly.
        initialize: () =>

            id = @getParameterByName('id').split('|')

            profile = @getParameterByName('profile')

            col = new window.opener.Collection
            col.url = @commonURL(0, window.opener.collection.total)

            # Show profile view if appropriate
            @showProfile id[0] if id.length is 1 and id[0]

            # Fetch collection
            col.fetch success: () =>

                @addTable()

                # Add all items if theres more than 1
                if id.length > 1 then return _.each id, (i) =>
                    return unless i
                    @addOneList col.get i

                col.each (m) =>
                    @addOneList m

                # Append jquery's tablesorter
                @addTablesorter()


        # Show a profile view instead of a list view
        showProfile: (id) =>

            item = window.opener.collection.get id

            @$el.html @templateProfile m: item.parseSubfields()


        # Add table headers
        addTable: () =>

            template = _.template $('#table-template').html()

            @$el.html template {}


        # Show a detailed view of a item in the rightmost pane
        addOneList: (item) =>

            output = @templateList m: item.parseSubfields()

            $('tbody').append '<tr>' + output + '</tr>'


        # Parse querystring and return values
        getParameterByName: (name) ->

            name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]")
            regexS = "[\\?&]" + name + "=([^&#]*)"
            regex = new RegExp(regexS)
            results = regex.exec(window.location.search)
            return "" unless results

            decodeURIComponent results[1].replace(/\+/g, " ")


        # Parses a given Date into a readable formatted string (DD MMMM YYYY)
        formatDate: (date) =>

            monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
                "Aug", "Sep", "Oct", "Nov", "Dec" ]

            d = new Date date
            d = [
                d.getDate(), monthNames[d.getMonth()], d.getFullYear()
            ]
            d.join ' '


        # Attach the tablesorter plugin to the items table
        addTablesorter: () =>

            $('table')

                .tablesorter sortList: window.opener.Settings.ListSort,
                    textExtraction: @tableTextExtraction

                .bind 'sortEnd',

                    (sorter) =>

                        sort = sorter.target.config.sortList

                        window.opener.Settings.ListSort = sort


        # Check of admin in QS
        isAdmin: () =>

            qs = window.location.search.split('?')[1]

            new RegExp('admin=').test qs


        # Form a URL with the basic prefix (i.e. /collection) and appends all
        # filter parameters on the querystring.
        commonURL: (page, rows) =>

            url = "collection/"
            fs = []

            fs.push "page=#{page}" if page isnt undefined
            fs.push "rows=#{rows}" if rows isnt undefined
            fs.push "sort=#{window.opener.collection.sort}"

            _.each window.opener.Settings.Schema.getFacets(), (field) ->

                fs.push 'facet.field=' + field.id

            url += '?' + fs.join '&' if fs.length
            url


    #Lets create our app!
    @App = new AppView
