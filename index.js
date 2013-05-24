$(function() {

    $('#example').css('height', $(window).height() - 100 + 'px');

    $('a#demo_banner').click(function() {
        if ($('#example').hasClass('visible')) {
            return hideExample();
        }
        showExample();
    });

    $('a#info').click(function() {
        if ($('a#info').hasClass('visible')) {
            $('.info').hide(500);
            return $('a#info').html('more info?').removeClass('visible');
        }
        $('.info').show(1000);
        $('a#info').html('less info').addClass('visible');
    });

    $('#slideshow_right').click(function() {
        stopAnimation();
        nextSlide();
    });

    $('#slideshow_left').click(function() {
        stopAnimation();
        prevSlide();
    });

    $('#indicators li span').click(function(e) {
        var $e = $(e.currentTarget);
        var id = $e.attr('id');
        stopAnimation();
        jump(id);
    });

    startSlider();

});

var slider  = {
    "pic_size": 817,
    "speed": 700,
    "interval": 10000,
    "pid": null,
    "wait": null
}

function nextSlide() {
    var left = $('#slides').css('margin-left').split('px')[0];
    var i = parseInt(Math.abs(left) / slider.pic_size) + 1;
    left = i * slider.pic_size * -1;
    $('#slides').stop(true, true);
    $('#slides').animate({ 'margin-left': left}, slider.speed, function() {
        setPointer(i);
        if (i == 7) { return resetSlider(); }
    });
}

function prevSlide() {
    var left = $('#slides').css('margin-left').split('px')[0];
    var i = parseInt(Math.abs(left) / slider.pic_size) - 1;
    left = i * slider.pic_size * -1;
    $('#slides').stop(true, true);
    if (i == -1) { return setLastSlide(); };
    $('#slides').animate({ 'margin-left': left}, slider.speed, function() {
        setPointer(i);
        if (left >= 0) { return setLastSlide(); }
    });
}

function jump(id) {
    var left = id * slider.pic_size * -1;
    $('#slides').animate({ 'margin-left': left}, slider.speed, function() {
        setPointer(id);
    });

}

function setPointer(i) {
    $('#indicators .active_ind').removeClass('active_ind');
    $('#indicators #'+i).addClass('active_ind');
}

function resetSlider() {
    $('#slides').css('margin-left', slider.pic_size * -1);
    setPointer(1);
}

function setLastSlide() {
    $('#slides').css('margin-left', 6 * slider.pic_size * -1);
    setPointer(6);
}

function showExample() {
    $('#example').addClass('visible');
    $('#demo_banner').addClass('open');
    $('#example').slideDown(500);
    $('html, body').animate({
            scrollTop: $('#example').offset().top
    }, 1000);
    $('#demo_banner').animate({ top: -110 }, 1000);
}

function hideExample() {
    $('#example').removeClass('visible');
    $('#demo_banner').removeClass('open');
    $('#example').slideUp(1000);
    $('html, body').animate({ scrollTop: 0 }, 1000);
    $('#demo_banner').animate({ top: -50 }, 1000);

}

function startSlider() {
    slider.pid = setInterval(function() {
        nextSlide();
    }, slider.interval);
}

function stopAnimation() {
    clearInterval(slider.pid);
    clearTimeout(slider.wait);
    slider.wait = setTimeout(startSlider, 5000);
}
