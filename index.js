$(function() {

    $('#example').css('height', $(example).width() * 9/16 -100)

    $('#fullscreen').click(function() {

        window.open($('iframe').attr('src'), '_blank');

    });

});
