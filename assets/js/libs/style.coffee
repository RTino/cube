#### Style class
#
# Style class provide possibilities for visual improvements of Cube App



class window.Style

    constructor: () ->

        # Override fn addClass and removeClass to trigger custom event
        @overrideAddClassMethod()
        @overrideRemoveClassMethod()
        @overrideAppendMethod()

        # Import entity settings
        @settings = window.settings

        # Import Schema
        @schema = @settings.Schema

        # Load style config
        @configuration = @loadConfiguration()

    apply: () ->
        @layout()
        @content()

    # Apply style to App layout
    layout: () ->

        return unless @settings.theme?

        # Load default theme
        defaultTheme =  @configuration.layout.theme.default

        # Load theme
        theme = @configuration.layout.theme[@settings.theme] || @configuration.layout.theme.custom || @configuration.layout.theme.default

        # If theme exist...
        if theme?
            # On each element of layout
            _.each @configuration.layout.structure, (element) =>

                # New Style object which contains properties from structure and values from theme
                style = {}

                _.each element.style, (el, property) =>
                    style[property] = theme[el] || defaultTheme[el]

                # If element require additional action
                if element.action?

                    # And actions is hover
                    if element.action.type == 'hover'

                        # Store style of base and child element (if needed) before applying (avoid elements where collision exist)
                        collision = if typeof element.action.collision != 'undefined' then ':not(' + element.action.collision + ')' else ''
                        selectorStyle = @getStyle(element.selector + collision, style)
                        childStyle = @getStyle(element.action.child + collision, style) if typeof element.action.child != 'undefined'
                        isInCollision = @isInCollision
                        # Apply hover action on layout element
                        $(element.selector).hover (
                            () ->
                                # Don't apply action if it is in collision with other action
                                return if element.action.collision and isInCollision(this, element.action.collision)

                                $(this).css(style)

                                if typeof element.action.child != 'undefined'
                                    # Don't apply action if it is in collision with other action
                                    return if element.action.collision and isInCollision($(this).find(element.action.child), element.action.collision)

                                    $(this).find(element.action.child).css(style)
                        ),  () ->
                                # Don't apply action if it is in collision with other action
                                return if element.action.collision and isInCollision(this, element.action.collision)

                                $(this).css(selectorStyle)

                                if typeof element.action.child != 'undefined'
                                    # Don't apply action if it is in collision with other action
                                    return if element.action.collision and isInCollision($(this).find(element.action.child), element.action.collision)

                                    $(this).find(element.action.child).css(childStyle)

                    # If action is classListener
                    if element.action.type == 'classListener'

                        # Get style object with empty string values for CSS properties
                        collision = if typeof element.action.collision != 'undefined' then ':not(' + element.action.collision + ')' else ''
                        revertStyle = @getStyle(element.action.revert + collision, style)

                        # On addClass event apply style
                        $(element.selector).on 'addClass', () ->
                            $(element.action.target).css style

                        # On removeClass event return to "old" style
                        $(element.selector).on 'removeClass', (e) ->
                            $(element.selector).css revertStyle

                    # And if action is classListener
                    if element.action.type == 'appendListener'

                        # Remove append listener if previously added
                        $(element.selector).unbind 'append'

                        # On append event apply style
                        $(element.selector).on 'append', () ->
                            $(element.action.target).css style

                else
                    # If element don't require additional action just apply style on selector
                    @applyStyle(element.selector, style)

    # Apply style to App content
    content: () ->

        last = @lastVisibleItem()

        _.each @schema.get(), (item) =>
            id = item.id.replace(new RegExp(':', 'g'), '\\:')
            section =
                header: $("table ##{id}") # <th> element of content table
                body:   $("table .#{id}") # <td> element of content table

            restricted = JSON.stringify(last) == JSON.stringify(item)

            # Get CSS attributes
            style = @createContentStyle item, restricted

            # Apply style to header
            section.header.css(style.header) if style.header?

            # Apply style to body
            section.body.css(style.body) if style.body?

            # Apply special style to header child element
            if style.special? and style.special.header?
                _.each style.special.header, (style, target) =>
                    section.header.find(target).css style

            # Apply special style to body child element
            if style.special? and style.special.body?
                _.each style.special.body, (style, target) =>
                    section.body.find(target).css style


    # Override JQuery addClass to fire "addClass" event
    overrideAddClassMethod: () =>
        addClass = $.fn.addClass

        $.fn.addClass = () ->
            addClass.apply(this, arguments).trigger('addClass')

    # Override JQuery removeClass to fire "removeClass" event
    overrideRemoveClassMethod: () =>
        removeClass = $.fn.removeClass

        $.fn.removeClass = () ->
            removeClass.apply(this, arguments).trigger('removeClass')

    # Create configuration object which contains information about layout and content part of App
    loadConfiguration: () =>
        configuration =
            layout:
                theme: @loadLayoutThemes()
                structure: @loadLayoutStructure()

            content:
                properties: @loadContentStyleProperties()
                special: @loadContentSpecialStyleProperties()
                restricted: @loadContentRestrictedStyleProperties()

    # Override JQuery Append to fire "append" event
    overrideAppendMethod: () =>
        append = $.fn.append

        $.fn.append = () ->
            append.apply(this, arguments).trigger('append')

    # Load theme object (custom or predefined) which contains all layout themes
    loadLayoutThemes: () ->
        # Set custom theme if it is defined
        custom = {custom: @settings.theme} if typeof @settings.theme == 'object'

        # Set theme
        themes = custom || window.themes

        # Add default theme to themes object

        Object.defineProperty themes, 'default', {value: {text: '#000', backgroundColor: '#EEE', secondaryBackgroundColor: '#FFF', baseColor: '#1E90FF', hoverColor: '#cfe8ff', selected: '#CCC', disabled: 'transparent', disabledBorder: '#CCC'}, writable : true, enumerable : true, configurable : true}

        themes

    # Load structure object which contains layout structure
    loadLayoutStructure: () ->
        [
                selector: '#header'
                style:
                    'border-color': 'baseColor'
                    'background-color': 'backgroundColor'
            ,
                selector: '#header #search'
                style:
                    'background-color': 'backgroundColor'
            ,
                selector: '#header #search #searchInfo'
                style:
                    'background-color': 'backgroundColor'
            ,
                selector: '#header #search span#total'
                style:
                    'color': 'baseColor'
            ,
                selector: '#header #search span#reset'
                style:
                    'color': 'baseColor'
            ,
                selector: '#header #search span#reset a'
                style:
                    'color': 'baseColor'
            ,
                selector: '#header #search label'
                style:
                    'color': 'baseColor'
            ,
                selector: '#header #entityTitle'
                style:
                    'background-color': 'backgroundColor'
            ,
                selector: '#header #entityTitle.selectable'
                style:
                    'border-color': 'baseColor'
                    'background-color': 'secondaryBackgroundColor'
                action:
                    type: 'classListener'
                    target: '#header #entityTitle.selectable.active'
                    revert: '#header #entityTitle.selectable'
            ,
                selector: '#header #entities ul li'
                style:
                    'background-color': 'hoverColor'
                action:
                    type: 'hover'
                    collision: '.active'
            ,
                selector: '#entityTitle'
                style:
                    'color': 'baseColor'
            ,
                selector: '#header #controls'
                style:
                    'background-color': 'backgroundColor'
            ,
                selector: '#index'
                style:
                    'border-color': 'baseColor'
            ,
                selector: '#index ul li .field'
                style:
                    'background-color': 'hoverColor'
                action:
                    type: 'hover'
                    collision: '.active'
            ,
                selector: '#index ul li .field'
                style:
                    'background-color': 'hoverColor'
                action:
                    type: 'hover'
                    child: 'span.amount'
                    collision: '.active'
            ,
                selector: '#facet'
                style:
                    'background-color': 'selected'
                action:
                    type: 'appendListener'
                    target: '#index ul li .field span.amount.active'
            ,

                selector: '#innerIndex'
                style:
                    'background-color': 'selected'
                action:
                    type: 'appendListener'
                    target: '#index ul li .field.active'
            ,

                selector: '#index ul li .field'
                style:
                    'background-color': 'selected'
                action:
                    type: 'classListener'
                    target: '#index ul li .field.active'
                    revert: '#index ul li .field'
                    collision: '.active'
            ,

                selector: '#index ul li .field'
                style:
                    'background-color': 'selected'
                action:
                    type: 'classListener'
                    target: 'span.amount.active'
                    revert: '#index ul li .field'
                    collision: '.active'

            ,
                selector: '#items table tbody tr'
                style:
                    'background-color': 'selected'
                action:
                    type: 'classListener'
                    target: '#items table tbody tr.active'
                    revert: '#items table tbody tr'
                    collision: '.active'
            ,
                selector: '.menu'
                style:
                    'border-color': 'baseColor'
            ,
                selector: '.menu ul li'
                style:
                    'border-color': 'baseColor'
                action:
                    type: 'hover'
            ,
                selector: '.nonHoverMenu'
                style:
                    'border-color': 'baseColor'
            ,
                selector: 'span#columnsMenu'
                style:
                    'border-color': 'baseColor'
                action:
                    type: 'classListener'
                    target: 'span#columnsMenu.active'
                    revert: 'span#columnsMenu'
                    collision: '.active'
            ,

                selector: '#items table tbody tr'
                style:
                    'background-color': 'hoverColor'
                action:
                    type: 'hover'
                    collision: '.active'
            ,

                selector: '#items table tr'
                style:
                    'background-color': 'selected'
                action:
                    type: 'classListener'
                    target: '#items table tbody tr.active'
                    revert: '#items table tbody tr'
                    collision: '.active'
            ,
                selector: '#items'
                style:
                    'background-color': 'selected'
                action:
                    type: 'appendListener'
                    target: '#items table tbody tr.active'
            ,

                selector: '.pane'
                style:
                    'border-color': 'baseColor'
            ,

                selector: '#pageStatus'
                style:
                    'color': 'baseColor'
            ,

                selector: '.btn'
                style:
                    'background-color': 'baseColor'
            ,

                selector: '#footer'
                style:
                    'border-color': 'baseColor'
                    'background-color': 'backgroundColor'
            ,

                selector:'#footer #wrapper span.btn'
                style:
                    'background-color': 'baseColor'
                    'border-color': 'hoverColor'
            ,

                selector: '#footer #wrapper span.btn.disabled'
                style:
                    'background-color': 'disabled'
                    'border-color': 'disabledBorder'
        ]
    # Check if action is in collision with other action
    isInCollision: (selector, target) =>
        coi = target[0]
        if coi == '.'
            collision = if $(selector).hasClass(target.substr(1)) then true else false
        if coi == '#'
            collision = if $(selector).attr('id') == target.substr(1) then true else false
        collision

    # Create style object which contains predefined CSS properties for each data type
    createContentStyle: (item, restricted = false) =>

        style = {}

        # For each visual section of schema...
        _.each item.style, (attributes, section) =>
            style[section] = {}

            # and for each style property of section...
            _.each attributes, (value, key) =>
                # skip value of property if property is in restricted group and the items is last visible
                value = '' if restricted and @configuration.content.restricted.indexOf(key) != -1

                # format properly input value...
                value = if typeof value == 'number' then value + 'px' else value

                # if applying of style requires additional actions on child HTML entities...
                if @configuration.content.special[item.type]? and @configuration.content.special[item.type][section]?

                     style.special = {} unless style.special?
                     style.special[section] = {} unless style.special[section]?

                     # Check if current property is one of special properties...
                     # (as result we get NULL or target on whom will be applied style)
                     special = @isSpecialContentProperty item, section, key

                     if special?
                        # If the property is special store it into style as special (style property of child item)
                        style.special[section][special] = {} unless style.special[section][special]?
                        style.special[section][special][@configuration.content.properties[key]] = value if @configuration.content.properties[key]?
                     else
                        # else store into style as property of base item
                        style[section][@configuration.content.properties[key]] = value if @configuration.content.properties[key]?

                else
                    # if not just add style property as property of base item
                    style[section][@configuration.content.properties[key]] = value if @configuration.content.properties[key]?

        style

    # Load available CSS properties
    loadContentStyleProperties: () ->
        properties =
            width:       'width'
            minWidth:    'min-width'
            maxWidth:    'max-width'
            height:      'height'
            fColor:      'color'
            bgColor:     'background-color'
            cellColor:   'background-color'
            border:      'border'

    # Load content style "helper" which contains information about each content entity which require
    # addition action for applying desired style to HTML element
    loadContentSpecialStyleProperties: () ->
        properties =
            string:
                header:
                    '.th-inner':  ['bgColor']
            integer:
                header:
                    '.th-inner':  ['bgColor']
            float:
                header:
                    '.th-inner':  ['bgColor']
            date:
                header:
                    '.th-inner':  ['bgColor']
            tuple:
                header:
                    '.th-inner':  ['bgColor']
            multiline:
                header:
                    '.th-inner':  ['bgColor']
            facet:
                header:
                    '.th-inner':  ['bgColor']
            dropdown:
                header:
                    '.th-inner':  ['bgColor']
            img:
                header:
                    '.th-inner':  ['bgColor']
            link:
                header:
                    '.th-inner':  ['bgColor']
            email:
                header:
                    '.th-inner':  ['bgColor']
            skype:
                header:
                    '.th-inner':  ['bgColor']
            gantt:
                header:
                    '.th-inner':  ['bgColor']
                body:
                    '.ganttCell': ['cellColor']

    loadContentRestrictedStyleProperties: () ->
        properties = ['width', 'minWidth', 'maxWidth']

    # Check if property is in group of special properties
    isSpecialContentProperty: (item, section, property) =>
        special = null

        _.each @configuration.content.special[item.type][section], (values, target) =>
            if values.indexOf(property) != -1
                special = target
        special
    # Get last visible element from schema
    lastVisibleItem: () =>
        last = {}

        _.each @schema.get(), (item) =>
            last = item if item.index == true

        last

    # Get empty or with values style of required entity
    getStyle: (selector, s, empty = false) =>
        style = {}
        item = $(selector)

        _.each s , (value, property) =>
            style[property] = if not empty then item.css property else ''

        style
    # Apply style to entity
    applyStyle: (selector, style) =>
        $(selector).css style

