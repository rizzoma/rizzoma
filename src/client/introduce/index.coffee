renderIntro = require('./template').renderIntro
renderVideo = require('./template').renderVideo

class Introduce
    ###
    Панель ознакомления с функционалом
    ###

    CALLOUT_SLIDE_CLASS_PREFIX = 'slide'
    SLIDES_COUNT = 4
    MODES = {image: 'image', video: 'video'}

    constructor: ->
        @_createDom()
        @_initEvents()
        _gaq.push(['_trackEvent', 'Introduce page', "Show 1 tip"])
        _gaq.push(['_trackEvent', 'Introduce page', "Show introduce page"])

    _createDom: ->
        $(document.body).append(renderIntro({slidesCount: SLIDES_COUNT}))
        slides = $('.js-slides')
        @_container = $('.js-introduce')
        @_slidesContainer = @_container.find('.js-slides-container')
        @_close = @_container.find('.js-closer')
        @_prev = @_container.find('.js-prev')
        @_next = @_container.find('.js-next')
        @_sliderNav = @_container.find('.js-navigation')
        @_video = @_container.find('.js-video')
        @_slides = @_container.find('.js-slides')
        @_callout = @_container.find('.js-callout')
        lang = window.navigator.userLanguage || window.navigator.language
        if lang.search('ru') == -1
            @_callout.addClass('callout')
        else
            @_callout.addClass('callout-ru')
        @_currentSlideIndex = 0
        @_buttons = @_container.find('button')
        @_progressbarDivs = @_container.find('.js-progressbar').find('div')
        @_switchButton = @_container.find('.js-switch-link')
        @_mode = MODES.image

    _initEvents: ->
        $(window).bind 'click', @_windowClickHandler
        $(window).bind 'keydown', @_windowKeyHandler
        @_close.click =>
            @_closeAndUnbind()
        @_switchButton.click (e) =>
            return if e.which != 1
            switch @_mode
                when MODES.image
                    _gaq.push(['_trackEvent', 'Introduce page', 'Switch to video'])
                    @_video.width(@_slides.outerWidth())
                    @_video.height(@_slides.outerHeight())
                    @_slides.hide()
                    if !@_video.html()
                        @_video.append(renderVideo({videoUrl: "I7whBwsGzM8"}))
                    @_video.show()
                    @_video.find('iframe').show()
                    @_sliderNav.hide()
                    @_switchButton.find('div').text('Show picture')
                    @_mode = MODES.video
                when MODES.video
                    _gaq.push(['_trackEvent', 'Introduce page', 'Switch to picture'])
                    @_video.find('iframe').hide()
                    @_video.hide()
                    @_slides.show()
                    @_sliderNav.show()
                    @_switchButton.find('div').text('Play video')
                    @_mode = MODES.image
        @_next.click (e) =>
            return if e.which != 1 or @_currentSlideIndex == SLIDES_COUNT - 1
            @_changeSlide(@_currentSlideIndex, @_currentSlideIndex+1)
        @_prev.click (e) =>
            return if e.which != 1 or @_currentSlideIndex == 0
            @_changeSlide(@_currentSlideIndex, @_currentSlideIndex-1)
        @_progressbarDivs.click (e) =>
            @_changeSlide(@_currentSlideIndex, @_progressbarDivs.index(e.target))

    _changeSlide: (currentIndex, newIndex) ->
        if newIndex == 0 then @_prev.attr('disabled', 'disabled') else @_prev.removeAttr('disabled')
        if newIndex == SLIDES_COUNT - 1 then @_next.attr('disabled', 'disabled') else @_next.removeAttr('disabled')
        @_callout.removeClass("#{CALLOUT_SLIDE_CLASS_PREFIX}#{currentIndex}")
        @_callout.addClass("#{CALLOUT_SLIDE_CLASS_PREFIX}#{newIndex}")
        @_currentSlideIndex = newIndex
        _gaq.push(['_trackEvent', 'Introduce page', "Show #{@_currentSlideIndex+1} tip"])
        @_progressbarDivs.removeClass('active')
        $(@_progressbarDivs[@_currentSlideIndex]).addClass('active')

    _windowClickHandler: (e) =>
        return if e.which != 1
        if not $.contains(@_slidesContainer[0], e.target)
            @_closeAndUnbind()

    _windowKeyHandler: (e) =>
        return if e.which != 27
        @_closeAndUnbind()

    _closeAndUnbind: =>
        $(window).unbind 'click', @_windowClickHandler
        $(window).unbind 'keydown', @_windowKeyHandler
        @_container.remove()
        delete @

exports.Introduce = Introduce