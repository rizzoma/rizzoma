/**
 * jQuery lightBox plugin
 * This jQuery plugin was inspired and based on Lightbox 2 by Lokesh Dhakar (http://www.huddletogether.com/projects/lightbox2/)
 * and adapted to me for use like a plugin from jQuery.
 * @name jquery-lightbox-0.5.js
 * @author Leandro Vieira Pinho - http://leandrovieira.com
 * @version 0.5
 * @date April 11, 2008
 * @category jQuery plugin
 * @copyright (c) 2008 Leandro Vieira Pinho (leandrovieira.com)
 * @license CCAttribution-ShareAlike 2.5 Brazil - http://creativecommons.org/licenses/by-sa/2.5/br/deed.en_US
 * @example Visit http://leandrovieira.com/projects/jquery/lightbox/ for more informations about this jQuery plugin
 */

// Offering a Custom Alias suport - More info: http://docs.jquery.com/Plugins/Authoring#Custom_Alias
(function($) {
	/**
	 * $ is an alias to jQuery object
	 *
	 */
	$.fn.lightBox = function(settings) {
		// Settings to configure the jQuery lightBox plugin how you like
		settings = jQuery.extend({
			// Configuration related to navigation
			fixedNavigation:		false,		// (boolean) Boolean that informs if the navigation (next and prev button) will be fixed or not in the interface.
			// Configuration related to images
			imageLoading:			'/s/img/jquery-lightbox/lightbox-ico-loading.gif',		// (string) Path and the name of the loading icon
			imageBtnPrev:			'/s/img/jquery-lightbox/lightbox-btn-prev.gif',			// (string) Path and the name of the prev button image
			imageBtnNext:			'/s/img/jquery-lightbox/lightbox-btn-next.gif',			// (string) Path and the name of the next button image
			imageBtnClose:			'/s/img/jquery-lightbox/lightbox-btn-close.gif',		// (string) Path and the name of the close btn
			imageBlank:				'/s/img/jquery-lightbox/lightbox-blank.gif',			// (string) Path and the name of a blank image (one pixel)
			// Configuration related to container image box
			containerBorderSize:	10,			// (integer) If you adjust the padding in the CSS for the container, #lightbox-container-image-box, you will need to update this value
			containerResizeSpeed:	400,		// (integer) Specify the resize duration of container image. These number are miliseconds. 400 is default.
            containerMarginLeftRightSize: 70,
            hideImageDataBox: false,
            topOffset: 10,
			// Configuration related to texts in caption. For example: Image 2 of 8. You can alter either "Image" and "of" texts.
			txtImage:				'Image',	// (string) Specify text "Image"
			txtOf:					'of',		// (string) Specify text "of"
			// Configuration related to keyboard navigation
			keyToClose:				'c',		// (string) (c = close) Letter to close the jQuery lightBox interface. Beyond this letter, the letter X and the SCAPE key is used to.
			keyToPrev:				'p',		// (string) (p = previous) Letter to show the previous image
			keyToNext:				'n',		// (string) (n = next) Letter to show the next image.
			// Don�t alter these variables in any way
			imageArray:				[],
			activeImage:			0
		},settings);
		// Caching the jQuery object with all elements matched
		var jQueryMatchedObj = this; // This, in this context, refer to jQuery object
		/**
		 * Initializing the plugin calling the start function
		 *
		 * @return boolean false
		 */
		function _initialize() {
			_start(this,jQueryMatchedObj); // This, in this context, refer to object (link) which the user have clicked
			return false; // Avoid the browser following the link
		}
		/**
		 * Start the jQuery lightBox plugin
		 *
		 * @param object objClicked The object (link) whick the user have clicked
		 * @param object jQueryMatchedObj The jQuery object with all elements matched
		 */
		function _start(objClicked,jQueryMatchedObj) {
            var sel = window.getSelection();
            if (sel) sel.removeAllRanges();
            if (document.body.tabIndex == null || document.body.tabIndex == undefined || document.body.tabIndex == -1) document.body.tabIndex = 0;
            document.body.focus();
			// Hime some elements to avoid conflict with overlay in IE. These elements appear above the overlay.
			$('embed, object, select').css({ 'visibility' : 'hidden' });
			// Call the function to create the markup structure; style some elements; assign events in some elements.
			_set_interface();
			// Unset total images in imageArray
			settings.imageArray.length = 0;
			// Unset image active information
			settings.activeImage = 0;
			// We have an image set? Or just an image? Let�s see it.
			if ( jQueryMatchedObj.length == 1 ) {
				settings.imageArray.push(new Array(objClicked.getAttribute('href'),objClicked.getAttribute('title')));
			} else {
				// Add an Array (as many as we have), with href and title atributes, inside the Array that storage the images references		
				for ( var i = 0; i < jQueryMatchedObj.length; i++ ) {
					settings.imageArray.push(new Array(jQueryMatchedObj[i].getAttribute('href'),jQueryMatchedObj[i].getAttribute('title')));
				}
			}
			while ( settings.imageArray[settings.activeImage][0] != objClicked.getAttribute('href') ) {
				settings.activeImage++;
			}
			// Call the function that prepares image exibition
			_set_image_to_view();
		}

        function _resizeHandler() {
            // Style overlay and show it
            $('#jquery-overlay').css({
                width:		$(document).width(),
                height:		$(document).height()
            });
            _setContainerToCurrentScroll();
            _resize_container_image_box();
        }

        function _setContainerToCurrentScroll() {
            // Calculate top and left offset for the jquery-lightbox div object and show it
            $('#jquery-lightbox').css({
                top: ($(document.body).scrollTop() || $(document.documentElement).scrollTop() || 0) + settings.topOffset,
                left:	'0'
            });
        }
		/**
		 * Create the jQuery lightBox plugin interface
		 *
		 * The HTML markup will be like that:
			<div id="jquery-overlay"></div>
			<div id="jquery-lightbox">
				<div id="lightbox-container-image-box">
					<div id="lightbox-container-image">
						<img src="../fotos/XX.jpg" id="lightbox-image">
						<div id="lightbox-nav">
							<a href="#" id="lightbox-nav-btnPrev"></a>
							<a href="#" id="lightbox-nav-btnNext"></a>
						</div>
						<div id="lightbox-loading">
							<a href="#" id="lightbox-loading-link">
								<img src="../images/lightbox-ico-loading.gif">
							</a>
						</div>
					</div>
				</div>
				<div id="lightbox-container-image-data-box">
					<div id="lightbox-container-image-data">
						<div id="lightbox-image-details">
							<span id="lightbox-image-details-caption"></span>
							<span id="lightbox-image-details-currentNumber"></span>
						</div>
						<div id="lightbox-secNav">
							<a href="#" id="lightbox-secNav-btnClose">
								<img src="../images/lightbox-btn-close.gif">
							</a>
						</div>
					</div>
				</div>
			</div>
		 *
		 */
		function _set_interface() {
			// Apply the HTML markup into body tag
			$('body').append('<div id="jquery-overlay">' +
                    '<div id="jquery-lightbox">' +
                    '<div id="lightbox-nav"><a href="#" id="lightbox-nav-btnPrev"></a><a href="#" id="lightbox-nav-btnNext"></a></div>' +
                    '<div id="jquery-lightbox-container"><div id="lightbox-container-image-box">' +
                    '<div id="lightbox-container-image"><img id="lightbox-image"><div id="lightbox-loading"><a href="#" id="lightbox-loading-link"><img src="' +
                    settings.imageLoading + '"></a></div></div></div><div id="lightbox-container-image-data-box">' +
                    '<div id="lightbox-container-image-data"><div id="lightbox-image-details">' +
                    '<span id="lightbox-image-details-caption"></span><span id="lightbox-image-details-currentNumber"></span></div>' +
                    '<div id="lightbox-secNav"><a href="#" id="lightbox-secNav-btnClose"><img src="' +
                    settings.imageBtnClose + '"></a></div><div id="lightbox-zoom-box">Zoom: ' +
                    '<span id="lightbox-zoom-info"></span></div></div></div></div></div>' + '</div>'
            );
			// Style overlay and show it
			$('#jquery-overlay').css({
                width:		$(document).width(),
                height:		$(document).height()
			}).fadeIn();
			// Get page scroll
			// Calculate top and left offset for the jquery-lightbox div object and show it
            _setContainerToCurrentScroll();
			$('#jquery-lightbox').show();
			// Assigning click events in elements to close overlay
            $('#lightbox-container-image-box').click(function (e) {
                e.stopPropagation();
                _handleImageClick();
            }).css({padding: settings.containerBorderSize});
			$('#jquery-overlay,#jquery-lightbox').click(function() {
				_finish();									
			});
			// Assign the _finish function to lightbox-loading-link and lightbox-secNav-btnClose objects
			$('#lightbox-loading-link,#lightbox-secNav-btnClose').click(function() {
				_finish();
				return false;
			});
			// If window was resized, calculate the new overlay dimensions
			$(window).bind('resize', _resizeHandler);
            $(window).bind('scroll', _setContainerToCurrentScroll);
		}

        function _handleImageClick() {
            var $img = $('#lightbox-image');
            if (!$img[0] || $img.css('display') == 'none'){
                return;
            }
            var width = $img.css('max-width');
            var $dataBox = $('#lightbox-container-image-data-box');
            var $imgBox = $('#lightbox-container-image');
            if (!$imgBox.hasClass('zoomed')) {
                var nWidth, nHeight;
                var $zoomInfo = $('#lightbox-zoom-info');
                if((nWidth = $img[0].naturalWidth) && (nHeight = $img[0].naturalHeight) && nWidth <=
                        parseInt($img.css('max-width')) && nHeight <= parseInt($img.css('max-height'))) {
                    $img.css({height: nHeight * 2, width: nWidth * 2});
                    $zoomInfo.text('200%');
                }
                else {
                    $zoomInfo.text('100%');
                }
                $img.css({'max-width': 'none', 'max-height': 'none'});
                var offsets = settings.containerBorderSize * 2;
                var dataBoxHeight = 0;
                if(settings.hideImageDataBox) {
                    $dataBox.hide();
                } else {
                    dataBoxHeight = $dataBox.height();
                }
                $imgBox.css({'max-height': window.innerHeight - offsets - dataBoxHeight - settings.topOffset, 'max-width': window.innerWidth - offsets, overflow: 'auto'}).addClass('zoomed');
                $('#jquery-lightbox-container').css({width: 'auto'});
            }
            else {
                _resize_container_image_box();
            }
        }

		/**
		 * Prepares image exibition; doing a image�s preloader to calculate it�s size
		 *
		 */
		function _set_image_to_view() { // show the loading
			// Show the loading
			$('#lightbox-loading').show();
			if ( settings.fixedNavigation ) {
				$('#lightbox-image,#lightbox-container-image-data-box,#lightbox-image-details-currentNumber').hide();
			} else {
				// Hide some elements
				$('#lightbox-image,#lightbox-nav,#lightbox-nav-btnPrev,#lightbox-nav-btnNext,#lightbox-container-image-data-box,#lightbox-image-details-currentNumber').hide();
			}
			// Image preload process
			var objImagePreloader = new Image();
			objImagePreloader.onload = function() {
				$('#lightbox-image').attr('src',settings.imageArray[settings.activeImage][0]);
				// Perfomance an effect in the image container resizing it
				_resize_container_image_box(objImagePreloader.width,objImagePreloader.height);
				//	clear onLoad, IE behaves irratically with animated gifs otherwise
				objImagePreloader.onload=function(){};
			};
			objImagePreloader.src = settings.imageArray[settings.activeImage][0];
		};
		/**
		 * Perfomance an effect in the image container resizing it
		 *
		 * @param integer intImageWidth The image�s width that will be showed
		 * @param integer intImageHeight The image�s height that will be showed
		 */
		function _resize_container_image_box(intImageWidth,intImageHeight) {
			// Get current width and height
            if(!$('#lightbox-image')[0]) return;
            if(!intImageWidth) intImageWidth = $('#lightbox-image')[0].naturalWidth || $('#lightbox-image').width();
            if(!intImageHeight) intImageHeight = $('#lightbox-image')[0].naturalHeight || $('#lightbox-image').height();
            var htmlEl = document.documentElement;
			// Get the width and height of the selected image plus the padding
			var intWidth = Math.min(intImageWidth + (settings.containerBorderSize * 2),
                    htmlEl.clientWidth - (settings.containerMarginLeftRightSize * 2)); // Plus the image�s width and the left and right padding value
			var intHeight = Math.min(intImageHeight + (settings.containerBorderSize * 2),
                    htmlEl.clientHeight - $('#lightbox-container-image-data-box').height() - settings.topOffset); // Plus the image�s height and the left and right padding value
			// Perfomance the effect
            var imgWidth = intWidth - settings.containerBorderSize * 2;
            var imgHeight = intHeight - settings.containerBorderSize * 2;
            $('#lightbox-image').css({
                'max-width': imgWidth,
                'max-height': imgHeight,
                height: 'auto', width: 'auto'
            });
            $('#lightbox-container-image-box').css({'min-width': parseInt($('#jquery-lightbox-container').css('min-width')) - settings.containerBorderSize * 2});
            $('#lightbox-zoom-info').text((Math.min(imgWidth / intImageWidth, imgHeight / intImageHeight) * 100).toFixed(0) + '%');
			$('#lightbox-container-image').css({overflow: 'hidden'}).animate({ 'max-width': imgWidth, 'max-height': imgHeight },
                    settings.containerResizeSpeed,function() { _show_image(); }).removeClass('zoomed');
            $('#jquery-lightbox-container').css({width: intWidth});
		};
		/**
		 * Show the prepared image
		 *
		 */
		function _show_image() {
			$('#lightbox-loading').hide();
			$('#lightbox-image').fadeIn(function() {
				_show_image_data();
				_set_navigation();
			});
			_preload_neighbor_images();
		};
		/**
		 * Show the image information
		 *
		 */
		function _show_image_data() {
			$('#lightbox-container-image-data-box').slideDown('fast');
			$('#lightbox-image-details-caption').hide();
			if ( settings.imageArray[settings.activeImage][1] ) {
				$('#lightbox-image-details-caption').html(settings.imageArray[settings.activeImage][1]).show();
			}
			// If we have a image set, display 'Image X of X'
			if ( settings.imageArray.length > 1 ) {
				$('#lightbox-image-details-currentNumber').html(settings.txtImage + ' ' + ( settings.activeImage + 1 ) + ' ' + settings.txtOf + ' ' + settings.imageArray.length).show();
			}		
		}
		/**
		 * Display the button navigations
		 *
		 */
		function _set_navigation() {
			$('#lightbox-nav').show();

			// Instead to define this configuration in CSS file, we define here. And it�s need to IE. Just.
			$('#lightbox-nav-btnPrev,#lightbox-nav-btnNext').css({ 'background' : 'transparent url(' + settings.imageBlank + ') no-repeat' });
			
			// Show the prev button, if not the first image in set
			if ( settings.activeImage != 0 ) {
				if ( settings.fixedNavigation ) {
					$('#lightbox-nav-btnPrev').css({ 'background' : 'url(' + settings.imageBtnPrev + ') left 15% no-repeat' })
						.unbind()
						.bind('click',function() {
							settings.activeImage = settings.activeImage - 1;
							_set_image_to_view();
							return false;
						});
				} else {
					// Show the images button for Next buttons
					$('#lightbox-nav-btnPrev').unbind().hover(function() {
						$(this).css({ 'background' : 'url(' + settings.imageBtnPrev + ') left 15% no-repeat' });
					},function() {
						$(this).css({ 'background' : 'transparent url(' + settings.imageBlank + ') no-repeat' });
					}).show().bind('click',function() {
						settings.activeImage = settings.activeImage - 1;
						_set_image_to_view();
						return false;
					});
				}
			}
			
			// Show the next button, if not the last image in set
			if ( settings.activeImage != ( settings.imageArray.length -1 ) ) {
				if ( settings.fixedNavigation ) {
					$('#lightbox-nav-btnNext').css({ 'background' : 'url(' + settings.imageBtnNext + ') right 15% no-repeat' })
						.unbind()
						.bind('click',function() {
							settings.activeImage = settings.activeImage + 1;
							_set_image_to_view();
							return false;
						});
				} else {
					// Show the images button for Next buttons
					$('#lightbox-nav-btnNext').unbind().hover(function() {
						$(this).css({ 'background' : 'url(' + settings.imageBtnNext + ') right 15% no-repeat' });
					},function() {
						$(this).css({ 'background' : 'transparent url(' + settings.imageBlank + ') no-repeat' });
					}).show().bind('click',function() {
						settings.activeImage = settings.activeImage + 1;
						_set_image_to_view();
						return false;
					});
				}
			}
			// Enable keyboard navigation
			_enable_keyboard_navigation();
		}
		/**
		 * Enable a support to keyboard navigation
		 *
		 */
		function _enable_keyboard_navigation() {
			$(document).bind('keydown', _keyboard_action);
		}
		/**
		 * Disable the support to keyboard navigation
		 *
		 */
		function _disable_keyboard_navigation() {
			$(document).unbind();
		}
		/**
		 * Perform the keyboard actions
		 *
		 */
		function _keyboard_action(objEvent) {
			// To ie
			if ( objEvent == null ) {
				keycode = event.keyCode;
				escapeKey = 27;
			// To Mozilla
			} else {
				keycode = objEvent.keyCode;
				escapeKey = objEvent.DOM_VK_ESCAPE || 27;
			}
			// Get the key in lower case form
			key = String.fromCharCode(keycode).toLowerCase();
			// Verify the keys to close the ligthBox
			if ( ( key == settings.keyToClose ) || ( key == 'x' ) || ( keycode == escapeKey ) ) {
				_finish();
			}
			// Verify the key to show the previous image
			if ( ( key == settings.keyToPrev ) || ( keycode == 37 ) ) {
				// If we�re not showing the first image, call the previous
				if ( settings.activeImage != 0 ) {
					settings.activeImage = settings.activeImage - 1;
					_set_image_to_view();
					_disable_keyboard_navigation();
				}
			}
			// Verify the key to show the next image
			if ( ( key == settings.keyToNext ) || ( keycode == 39 ) ) {
				// If we�re not showing the last image, call the next
				if ( settings.activeImage != ( settings.imageArray.length - 1 ) ) {
					settings.activeImage = settings.activeImage + 1;
					_set_image_to_view();
					_disable_keyboard_navigation();
				}
			}
		}
		/**
		 * Preload prev and next images being showed
		 *
		 */
		function _preload_neighbor_images() {
			if ( (settings.imageArray.length -1) > settings.activeImage ) {
				var objNext = new Image();
				objNext.src = settings.imageArray[settings.activeImage + 1][0];
			}
			if ( settings.activeImage > 0 ) {
				var objPrev = new Image();
				objPrev.src = settings.imageArray[settings.activeImage -1][0];
			}
		}
		/**
		 * Remove jQuery lightBox plugin HTML markup
		 *
		 */
		function _finish() {
            $(window).unbind('scroll', _setContainerToCurrentScroll);
            $(window).unbind('resize', _resizeHandler);
            $(document).unbind('keydown', _keyboard_action);
			$('#jquery-lightbox').remove();
			$('#jquery-overlay').fadeOut(function() { $('#jquery-overlay').remove(); });
			// Show some elements to avoid conflict with overlay in IE. These elements appear above the overlay.
			$('embed, object, select').css({ 'visibility' : 'visible' });
		}
		// Return the jQuery object for chaining. The unbind method is used to avoid click conflict when the plugin is called more than once
		return this.unbind('click').click(_initialize);
	};
})(jQuery); // Call and execute the function immediately passing the jQuery object