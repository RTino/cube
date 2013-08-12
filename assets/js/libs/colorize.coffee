class window.Colorize

    constructor: () ->
        @selector = ''
        @selection = {}
        @mixColor =
            r: 255
            g: 255
            b: 255

    set: (properties) ->
        @selector = properties.selector if properties.selector?
        @mixColor = properties.mixWith if properties.mixWith?
        @

    select: () ->
        @selection = $(@selector)
        @

    apply: () ->

        $.each @selection, (key, el) =>


            $el = $(el)

            return if $el.text().trim().length == 0

            content = hex_md5($el.text().trim())

            hex =   content.toString 16
            color = @hex2rgb hex
            color = @mix color

            $el.css 'background-color',
                    'rgb(' + color.r + ', ' + color.g + ', ' + color.b + ')'

    hex2rgb: (hex) ->
        color =
            r: 0
            g: 0
            b: 0

        hex += 'f' for i in [0 ... 6 - hex.length] if hex.length < 6

        for el, i in hex

            if i != 0 and i % 2 == 0
                c = parseInt hex[i - 2].toString() + hex[i - 1].toString(), 16

                switch i
                    when 2 then color.r = c
                    when 4 then color.g = c
                    when 6 then color.b = c

        color

    mix: (color) ->
        mixed = {}
        mixed[c] = Math.floor((color[c] + @mixColor[c]) / 2) + 1 for c of color
        mixed
