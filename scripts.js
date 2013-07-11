zalAppName = "Cube App";
zalDomain = "cubeapp.io";
gaId = "UA-40533395-3";

$(document).ready(function()
{
    if ($("#example").width() > 480) {
        $("#example").css("height", $(example).width() * 9/16 -100)
    }

    $("#fullscreen").click(function() {
        window.open($("iframe").attr("src"), "_blank");
    });
});