#### Pane View

$ ->

    # Defines a parent class for profile and group views.
    # A pane is located on the right side of the application and contains
    # either a profile view or a group view. It can also be extended to
    # allocate other things such as a Team view for the team app.
    class window.BasePaneView extends Backbone.View

        #### Initialize
        # 1. Point to app
        # 2. Listen for ESC keybinding
        # 3. Re-Set arrow keys movements on app
        initialize: () =>

            #Handy pointer to the app
            @app = window.App

            # Clear all keybindings, then add close on ESC and re-add movement
            # keybindings on content area.
            @setKeybindings()
            @app.setMoveKeybindings()

            # Make some space on the container
            $('.thumbnailContainer, #tableContainer')
                .addClass 'onProfile'

            # Also move the footer to the right
            $('#footer, #columnsSelectWrapper').addClass 'onProfile'

            # Show pane. .show() fails on some browsers.
            $('#pane').css('display', 'block')


        #### Set Model properties
        # Set values on a model for text, date and picture fields, and allow
        # unsetting empty properties if required.
        setModel: (m, unset, cb) ->

            @setModelTextFields m, unset

            @setModelIntFields m, unset

            @setModelDropdownFields m, unset

            @setModelDateFields m, unset

            @setModelPicFields m, unset

            @setModelFacetFields m, unset

            @setModelTupleFields m, unset

            cb() if cb


        # Sets a model's text properties: strings, emails and multilines.
        # All of these fields are stored in the DB as strings.
        setModelTextFields: (m, unset) =>

            _.each $('input, textarea', '#pane'), (i) =>

                $i = $(i)

                id = $i.attr 'id'

                f = window.settings.Schema.getFieldById id.split('_')[0]

                return unless !f.type or f.type is "text" or
                    f.type is "email" or  f.type is "multiline" or
                    f.type is "skype"

                val = $.trim $i.val()

                return m.unset(id, silent: yes) if !val and unset

                return unless val

                p = {}
                p[id] = val
                m.set p, silent: yes


        # Sets a model's numeric field: integer and float. These fields are
        # stored as integer or float respectively.
        setModelIntFields: (m, unset) =>

            _.each $('input', '#pane'), (i) =>

                $i = $(i)

                id = $i.attr 'id'

                f = window.settings.Schema.getFieldById id.split('_')[0]

                return unless !f.type or f.type is "integer" or
                    f.type is "float"

                val = $.trim $i.val()

                return m.unset(id, silent: yes) if !val and unset

                return unless val

                p = {}
                p[id] = val

                m.set p, silent: yes if val


        # Sets a model's dropdown properties. These fields are also
        # stored as strings.
        setModelDropdownFields: (m, unset) =>

            _.each $('select', '#pane'), (i) =>

                $i = $(i)

                id = $i.attr 'id'

                val = $.trim $i.val()

                return m.unset id, silent: yes if unset unless val

                return unless val

                if val and val[0] isnt ""
                    p = {}
                    p[id] = val
                    return m.set p, silent: yes


        # Sets a model's date fields. Stored as javascript ISO date strings.
        setModelDateFields: (m, unset) =>

            _.each $('input[data-type="date"]', '#pane'), (i) ->

                id = $(i).attr 'id'

                dateValue = new Date $(i).val()

                o = {}
                o[id] = dateValue

                return m.set o, silent: yes unless isNaN dateValue

                m.unset id, silent: yes if unset


        # Set a model's picture field from the picture HTML element.
        setModelPicFields: (m, unset) =>

            picFields = window.settings.Schema.getPictures()

            _.each picFields, (pf) ->

                id = pf.id

                $i = $("#picture", '#pane')

                return unless $i.attr 'src'

                o = {}
                o[id] = $i.attr 'src'

                m.set o, silent: yes


        # Set a model's facet fields.
        # Facet fields are multivalue. they will be stored as arrays of strings
        # in the database, along with a sort field which contains a comma
        # separated list of facet names, since Solr is not able to sort on
        # multivalue fields.
        setModelFacetFields: (m, unset) =>

            _.each $('input.facet'), (i) =>

                $i = $(i)

                id = $i.attr 'id'

                val = []

                f = window.settings.Schema.getFieldById id.split('_')[0]

                _.each $i.val().split(','), (v) =>
                    @setUniqueMultivalueField v, val

                return m.unset(id, silent: yes) if !val.length and unset

                return unless val

                p = {}
                p[id] = val

                m.set p, silent: yes if val.length


        # Sets the tuple property and also the related properties. i.e. for
        # tuple team:role it also sets team and role properties.
        setModelTupleFields: (m, unset) =>

            _.each $('.tupleWrapper'), (te) =>

                $te     = $(te)                     # tuple element
                tups    = []                        # list of tuples
                pval1   = []                        # vals for related field 1
                pval2   = []                        # vals for related field 2
                p       = {}                        # property obj to be set
                tid     = $te.attr('id')            # name of tuple (team:role)
                [ pid1, pid2 ] = tid.split(':')     # tuple id part 1 and 2

                _.each $('.tupleField', $te), (i) =>

                    $i = $(i)

                    v1 = $.trim $('input.p1', $i).val()
                    v2 = $.trim $('input.p2', $i).val()

                    # tuple values may contain both parts or just one.
                    tv = "#{v1}:#{v2}" if v1 or v2
                    tups.push tv if tv and tups.indexOf(tv) is -1

                    # Aggregate all values from one part and from the other, to
                    # store in the respective fields. It is important that we
                    # only store unique values like 'team/subteam1/group1'
                    # instead of 'team, team/subteam1, team/subteam1/group1'.
                    @setUniqueMultivalueField v1, pval1
                    @setUniqueMultivalueField v2, pval2

                # Property object contains tuple field and related fields.
                p[tid]  = tups
                p[pid1] = pval1
                p[pid2] = pval2

                if !pval1.length and !pval2.length and unset
                    return m.unset(tid, silent:yes)

                m.set(p, silent: yes) if pval1.length or pval2.length

        # Propperly removes a pane view by unbinding all events, keybindings
        # and resetting css clases before removing the actual html element.
        destroy: () =>

            @unbind()

            @unsetKeybindings()

            $('.onProfile').removeClass 'onProfile'

            @remove()


        # Close the profileView. User clicked on "X" link on top right corner
        close: () =>

            @app.clearSelection()

            @destroy()

            $('#pane').hide()

            @app.navigate()


        # Handle filtering from data values that are part of the facets.
        # i.e. by clicking on an items profile view data field.
        filterByDetail: (e) =>

            $e = $(e.currentTarget)

            cat = $e.attr 'data-name'
            field = $e.attr 'data-title'

            @app.setFacetState [ { cat: cat, field: field } ]

            @app.filterByFacet()

            return unless field.split('/')[1]

            parentFacet = field.split('/')[0]

            @app.facetOpenState.set [ { cat: cat, field: parentFacet } ]


        # Appends unique values to a given array, based on a comma separated
        # list of values. Unique values refer to values such as:
        # 'team/subteam1/group1' instead of
        # 'team, team/subteam1, team/subteam1/group1'
        setUniqueMultivalueField: (list, arr) ->

            _.each @getMultivalueField(list), (v) ->

                arr.push v if arr.indexOf(v) is -1 and v


        # Parse an input field that has multiple values and form an array of
        # unique values useful for Solr.
        # i.e. Novel/Sci-Fi => [ 'Novel', 'Novel/Sci-Fi' ]
        getMultivalueField: (field) =>

            uniqueFields = []

            values = field.split ','

            _.each values, (v, i) =>

                v = v.slice(1) if v[0] is ' '

                _.each @getUniqueValues(v), (v) ->

                    uniqueFields.push(v) if uniqueFields.indexOf(v) is -1

            uniqueFields


        # Given a value like Team/subteam1/group1 returns a list of values like
        # team, team/subteam1, team/subteam1/group1.
        getUniqueValues: (value) =>

            uniqueValues = []

            sep = window.settings.separator
            tokens = value.split sep

            _.each value.split(sep), (v, i) ->

                u = tokens.slice(0, i).join(sep)

                uniqueValues.push u if u

            uniqueValues.push value

            uniqueValues


        # Append another tuple fields after last one
        addTupleField: (e) ->

            $e = $(e.currentTarget)

            return unless $('.p1', $e).val() or $('.p2', $e).val()

            $p = $e.parent()

            tupleId = $e.attr 'id'

            template = _.template $('#tuple-field-template').html()

            $p.append template id: tupleId

            @setAutoComplete $('input.autocomplete')


        # Self explanatory
        removeEmptyTupleFields: (e) ->

            $tf = $('.tupleField')

            _.each $tf, (t, i, tf) ->

                $t = $(t)
                $i1 = $('.p1', $t)
                $i2 = $('.p2', $t)

                $t.remove() unless $i1.val() or $i2.val() or i is tf.length-1


        # Easy validation. Checks for values on any input field and matches
        # for emails on email input fields
        formIsValid: () ->

            validForm = true

            $('.validationFailed', '#pane').removeClass('validationFailed')

            inputFields = window.settings.Schema.getMandatories()

            _.each inputFields, (f, i, fields) =>

                validField = true

                input = $("input##{f.id}", "#pane")

                validField = false if !input.val()

                validField = false if f.type is 'email' and
                    !@emailValid input.val()

                input.addClass('validationFailed') unless validField

                validForm = false unless validField

            validForm


        # Email validation, match against a regexp.
        emailValid: (email) ->

            re = [ '^(([^<>()[\\]\\.,;:\\s@\\"]'
                , '+(\.[^<>()[\\]\\.,;:\\s@\\"]+)*)'
                , '|(\\".+\\"))@((\\[[0-9]{1,3}\\.'
                , '[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\])'
                , '|(([a-zA-Z\\-0-9]+\\.)+[a-zA-Z]{2,}))$' ]

            re = RegExp re.join ''

            re.test email


        # Attach autocomplete plugin to input fields (i.e. team, role).
        # There must be a resource to get an array with the values. The name of
        # the resource should match the id of the html element.
        setAutoComplete: ($elements) ->

            $.get 'ufacets', (fd) =>

                _.each $elements, (e) =>

                    $e = $(e)
                    id = $e.attr 'id'
                    id = id.split(':')[0] if $e.hasClass 'p1'
                    id = id.split(':')[1].split('_')[0] if $e.hasClass 'p2'

                    $e.autocomplete source: fd[id]


        # Attach fileupload plugin to picture input field.
        setFileupload: ($e) ->

            $e.attr 'data-url', "/#{window.entity}/picture/"

            $e.fileupload
                dataType: 'json'
                done: ($e, data) ->
                    $.each data.result, (index, file) ->
                        $('#picture').attr('src', file.url).one 'load', () ->
                            $('#pictureContainer')
                                .removeClass('validationFailed')


        # Attach datepicker plugin to a given input field
        setDatePicker: ($e) ->

            $e.datepicker

                changeYear      : true
                changeMonth     : true
                constrainInput  : true
                showButtonPanel : true
                showOtherMonths : true
                yearRange       : "c-70"
                dateFormat      : "d M yy"


        # Attach keybinding handlers like close on ESC and arrow keys.
        setKeybindings: () =>

            @unsetKeybindings()

            $('body').keyup @closeOnEsc


        # Close profile view when user hits ESC key
        closeOnEsc: (e) =>

            @close() if e.keyCode is 27


        # Dettach all pane keybindings on body
        unsetKeybindings: () =>

            $('body').unbind 'keyup', @closeOnEsc

        ###
        # Stop animation if mouse leaves arrows
        onMouseOut: () =>

            clearTimeout @scrollTimer


        # Stop animation if mouse enters the text container
        onTextContainer: () =>

            clearTimeout @scrollTimer


        # Reset text position to left:0 after the cursor has left for 2 seconds
        onTextContainerOut: (e) =>

            clearTimeout @scrollTimer

            @scrollTimer = setTimeout () =>
                @resetTextPosition e
                , 2000


        # Handle animation to reset the text to left:0.
        resetTextPosition: (e) =>

            $e = $(e.currentTarget)

            clearTimeout @scrollTimeout

            return if parseFloat($e.css('left').split('px')[0]) >= 0

            @scrollTimeout = setTimeout () =>
                @resetTextPosition e
                , 1

            @animateText $e, 'left'


        # Handles animation on text with directions 'left' or 'right'.
        animateText: ($e, dir) =>

            x = parseFloat $e.css('left').split('px')[0]

            return $e.css('left', (x+1)+'px') if dir is 'left'

            $e.css('left', (x-1)+'px')


        # Handles scrolling of long detailed data fields, showing arrows on
        # sides of data fields and taking care of animations.
        onScroll: (e) =>

            $e = $(e.currentTarget)
            $p = $e.siblings('.text-container')
            w = parseFloat $p.css('width').split('px')[0]
            x = parseFloat $p.css('left').split('px')[0]

            clearTimeout @scrollTimer

            @scrollTimer = setTimeout () =>
                @onScroll e
              ,
                10

            id = $e.attr 'id'

            $('span.scroll#left, span.scroll#right', $p.parent()).show()
            $('span.scroll#left', $p.parent()).hide() if x is 0
            $('span.scroll#right', $p.parent()).hide() if x is (w - 188) * -1
            $('span.scroll#right', $p.parent()).hide() if w < 178

            if id is 'left' and x >= 0
                return clearTimeout @scrollTimer
            if id is 'right'and x <= (w - 168) * -1
                return clearTimeout @scrollTimer
            @animateText $p, id
        ###

    #### Profile View
    # A detailed view of an item that shows up on the right pane.
    class window.ProfileView extends window.BasePaneView

        tagName: 'div'


        template: _.template $('#details-template').html()


        events:

            "click a#edit"                  : "form"
            "click a#save"                  : "save"
            "click a#delete"                : "clear"
            "click a.destroy"               : "close"
            "click label.additional"        : "showAdditionalFields"
            #"mouseover span.scroll"         : "onScroll"
            #"mouseout span.scroll"          : "onMouseOut"
            #"mouseover .text-container"     : "onTextContainer"
            #"mouseout .text-container"      : "onTextContainerOut"
            "click a.filter"                : "filterByDetail"
            "keyup .tupleField:last-child"  : "addTupleField"
            "focus .tupleField"             : "removeEmptyTupleFields"
            "keypress"                      : "save"


        # Initialize profile view by destroying previous views, binding to
        # important events and moving the content area to make some space.
        initialize: () ->

            super

            # Destroy all previous profileViews
            window.profileView?.destroy()

            # Bindings for items collection
            window.collection.bind 'reset', @onReset, @

            # Bindings for the changes on the collection after a search
            @app.bind 'filter', @close, @

            # Move right border of content area to make some space for
            # the profile.
            $('.thumbnailContainer').addClass 'onProfile'


        # Render profile inside #pane
        render: () =>

            @$el.html @template m: @model
            @


        # Delete an item
        clear: () ->

            return unless confirm('Do you want to delete?')

            @destroy()
            @model.clear()

        # Close a profile view. Unbind, destroy, remove element and bring
        # content area back to right 0.
        close: () ->
            super
            @app.profileClosed()
            @app.showPaneView()

        # Propperly unbind and remove a profileView without removing the
        # html element.
        destroy: () =>
            super
            window.collection.unbind 'reset', @onReset, @
            @app.unbind 'filter', @destroy, @
            window.profileView = null

        # When the Items collection fires a reset (usually after a refetch),
        # hide the profileView if the item is not anymore in the collection.
        onReset: () =>

            @destroy() unless window.collection.get @model.id


        # Initialize form elements to create/update an item
        form: (element) =>

            # Enable editing for additional fields, picture or all fields if
            # admin key is present
            if @app.isAdmin()

                $('a.text-overlay', '#pane').hide()
                $('input.hidden', '#pane').removeClass 'hidden'
                $('.multiline').addClass('edit').removeAttr 'style'
                $('select').addClass('edit').removeAttr 'disabled'
                $('.text-container').hide()
                $('.multilineWrapp p').hide()
                $('textarea', '#pane')
                  .removeAttr('disabled')
                  .addClass('edit')
                $('.tupleWrapper').removeClass('hidden')
                $('a.link').hide()

            # Enable additional fields. No admin key required.
            $a = $('#pane li.additional')
            $('a.text-overlay', $a).hide()
            $('input.hidden', $a).removeClass 'hidden'
            $('select', $a).addClass('edit').removeAttr 'disabled'
            $('.multilineWrapp p', $a).hide()
            $('textarea', $a).removeAttr('disabled').addClass('edit')
            $('a.link', $a).hide()

            # Enable picture field
            $('input#pic', '#pane')
                .addClass('editing')
                .removeAttr('disabled')
            $('#pictureContainer p', '#pane').show()

            # Show additional fields
            $('ul', '#pane li.additional').addClass('open')
            $('span#arrow', '#pane li').addClass('active')

            # Make invisible picture input field clickable
            $('#pane input#pic').show()

            # Highlight mandatory fields
            @setMandatoryLabels() if @app.isAdmin()

            # Set useful jquery plugins
            @setAutoComplete $('input.autocomplete')
            @setFileupload $('input#pic')
            @setDatePicker $('input[data-type="date"]')

            # Unset keybindings to avoid closing profile on arrow-keys.
            @app.unsetMoveKeybindings()

            # Set height of multiline fields.
            @setMultilineHeight()

            # Prepare buttons for edit state (show Save).
            $('#buttons a', '#pane').hide()
            $('a#save').css('display', 'inline-block')


        # Saves a new item or updates an older item if data is valid
        save: (e) =>

            if e.charCode or e.charCode is 0 then return unless e.which is 13

            return unless @formIsValid()

            return @create() unless @model.id

            @update()


        # Creates a new item in the items collection avoiding several clicks
        # to trigger a create() many times.
        create: _.debounce(() ->

            unset = yes

            @setModel @model, unset

            window.collection.create @model, wait: yes,
                success: () =>
                    @app.hideError()
                    @app.navigate()
                ,
                error: () =>
                    @app.showError()
        , 1000, true)


        # Update an item with the new changes on the input fields. If an input
        # field is empty, the property gets removed from the item object.
        # Only the optional fields are changable without an admin key!
        update: (e) =>

            unset = yes

            @setModel @model, unset

            @model.save {}, wait: yes, error: () ->
                window.App.showError()

            @app.navigate()


        # Addition fields section of the profile view, expand and collapse!
        showAdditionalFields: () ->

            $('ul', '#pane li.additional').toggleClass('open')

            $('span#arrow', '#pane li').toggleClass('active')

            return window.additionalOpen = yes if window.additionalOpen is no

            window.additionalOpen = no


        # Add class mandatory to respective fields
        setMandatoryLabels: () =>

            mandatoryFields = window.settings.Schema.getMandatories()

            _.each mandatoryFields, (l) =>
                $("label[for='#{l.id}']").addClass 'mandatory'


        # Sets the height for the textareas on the profile view.
        setMultilineHeight: (item) =>

            item = @model

            _.each window.settings.Schema.getMultilines(), (m) ->

                value = item.get m.id
                return unless value

                cols = $("textarea##{m.id}", '#pane').attr 'cols'
                lc = 0

                _.each value.split('\n'), (l) ->
                    lc += Math.ceil l.length/cols

                h = $("textarea##{m.id}", '#pane').prop 'scrollHeight'
                $("textarea##{m.id}", '#pane').height h


    #### Group view
    # Shows a selection of items. Allows for edition of multiple items at once,
    # export to CSV, create calendar, conference in Skype, etc
    class window.GroupView extends window.BasePaneView

        events:

            "click a.destroy"                         : "close"
            "click a.minidestroy"                     : "removeSelected"
            "click #groupActions a#csv.btn"           : "linkToCSV"
            "click #groupActions a#edit.btn"          : "multipleEdit"
            "click #multipleEditActions a#cancel.btn" : "closeEdit"
            "click #multipleEditActions a#save.btn"   : "save"
            "keypress"                                : "save"
            "keyup .tupleField:last-child"            : "addTupleField"
            "focus .tupleField"                       : "removeEmptyTupleFields"


        template: _.template $('#group-template').html()


        # Render view by passing an array of ids and an array of emails for
        # the calendar function
        render: () =>

            @$el.html @template m: @app.itemSelection, calendar: @gCalendarURL()
            @


        # Close group view. Unbind and destroys html element.
        close: () ->

            super

            @app.showPaneView()


        # Destroy and navigate to new state without group view
        destroy: () =>

            super

            window.groupView = null

            @app.navigate()


        #### Multiple edition
        # 1. Show multiple edition form
        # 2. Hide other action buttons
        # 3. Set autocomplete on input fields
        # 4. Set date pickers
        # 5. Unset arrow key movement bindings
        multipleEdit: () =>

            $('#itemsContainer').addClass 'onEdit'
            $('#multipleEditFields, #multipleEditActions').show()
            $('#groupActions').hide()

            @setAutoComplete $('input.autocomplete')
            @setDatePicker $('input[data-type="date"]')
            @app.unsetMoveKeybindings()


        #### Save multiple items
        # 1.- Unbinds 'sync' events from models until all models are changed.
        # 2.- Show a warning before applying changes
        # 3.- Set model properties for each item
        # 4.- Rebind 'sync' events
        # 5.- Refetch colection
        save: (e) =>

            if e.charCode or e.charCode is 0 then return unless e.which is 13

            amount = @app.itemSelection.length
            warning = "Proceed to apply changes to #{amount} "
            warning += window.App.getItemType()
            return unless confirm warning

            cb = _.after @app.itemSelection.length, () =>
                @app.fetchFacet () =>
                    @app.fetchItems
                        data: @app.getFilterQS()

            @app.itemSelection.each (m) =>
                m.unbind 'sync', @app.updateFacets

                @setModel m, no, () =>
                    m.save {},
                      wait: yes,
                      url: m.url() + '?admin=yes',
                      success: () =>
                          @app.hideError()
                          m.bind 'sync', @app.updateFacets
                          cb()

            @closeEdit()

        # Hide multiple edition fields
        closeEdit: () =>

            $('input', '#multipleEditFields').val ''
            $('#itemsContainer').removeClass 'onEdit'
            $('#multipleEditFields, #multipleEditActions').hide()
            $('#groupActions').show()


        # Deselects 1 item and takes it out from selection array
        removeSelected: (e) =>

            $e = $(e.currentTarget).parent('li')
            id = $e.attr 'id'

            return unless @app.itemSelection.get id

            @app.itemSelection.remove id

            $("##{id}", "#items").removeClass 'active'

            $e.remove()

            @app.navigate()


        # Export selected items to CSV txt file in new window/tab
        linkToCSV: () =>

            url = 'collection?&csv=true&'
            qs = []

            window.App.itemSelection.each (m) ->
                qs.push "fs=id:#{m.id}"

            window.open url + qs.join '&'


        # Forms the URL for the Calendar button.
        # ';' concatenated list of emails from selected items
        gCalendarURL: () =>

            emails = []
            @app.itemSelection.each (m) =>
                emails.push m.get 'email'

            now = new Date()
            year = now.getFullYear()
            month = now.getMonth() + 1
            if month < 10 then month = '0' + month
            day = now.getDate()
            if day < 10 then day = '0' + day
            defaultDate = year + month + day

            fromHour = now.getHours() + 1
            toHour = now.getHours() + 2
            offset = now.getTimezoneOffset()/60

            fromHour += offset
            toHour += offset
            if fromHour < 10 then fromHour = '0' + fromHour
            if toHour < 10 then toHour = '0' + toHour

            fromDate = defaultDate + 'T' + fromHour + '0000Z'
            toDate = defaultDate + 'T' + toHour + '0000Z'

            baseURL = "http://www.google.com/calendar/event?action=TEMPLATE"
            baseURL += "&text=Please%20add%20a%20title%20for%20this%20event..."
            baseURL += "&dates=#{fromDate}/#{toDate}&details=&location="
            baseURL += "&add=#{emails.toString()}&trp=false&sprop=&sprop=name:"
            baseURL


    #### Pane view
    # Shows a detailed view of a facet field. Allows for different templates
    # based on entity.
    class window.PaneView extends window.BasePaneView

        events:
            "click a.destroy"     : "reset"

        template: () ->
            _.template $("#extensions #pane-template").html()

        initialize: (@template, @field) =>
            super

        reset: () =>
            $(@el).trigger 'close'

        render: () =>
            @$el.html @template @field
            @

        destroy: () =>
            window.paneView = null
            super
