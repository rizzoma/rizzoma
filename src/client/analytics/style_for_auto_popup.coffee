ck = window.CoffeeKup

StyleForAutoPopup = ->
    style '', ->
        text """
        .auto-popup{
          width: 600px !important;
          height: 300px !important;
          background-color: #c2c9cf !important;
          border: 4px solid white !important;
          border-radius: 5px !important;
          }
          .auto-popup .call-to-action{
              position:absolute;
              top:30px;
              font-size: 20px;
              text-align: left;
              margin: 0 20px;
              font-weight: normal;
          }
          .auto-popup .or-glue{
              display: none;
          }
          .auto-popup .google-sign-in-btn, .auto-popup .facebook-sign-in-btn{
              position:absolute;
              top:70px;
              left:30px;
              margin: 0 20px;
          }
          .auto-popup .facebook-sign-in-btn{
              top: 130px;
          }
          .auto-popup .email-field, .auto-popup .password-field, .auto-popup .sign-in-btn, .auto-popup .msg, .auto-popup .show-forgot-password-form-link, .auto-popup .name-field, .auto-popup .sign-up-btn{
              position:absolute;
              margin: 0 20px;
              left:350px;
          }
          .auto-popup #sign-in-form .email-field{
              top:68px;
          }
          .auto-popup #sign-in-form .password-field{
              top:130px;
          }
          .auto-popup #sign-in-form .sign-in-btn{
              top:205px;
          }
          .auto-popup #sign-in-form .msg{
              top:240px;
          }
          .auto-popup #sign-in-form .show-forgot-password-form-link{
              top:290px;
          }
          .auto-popup #sign-up-form .name-field{
              top:68px;
          }
          .auto-popup #sign-up-form .email-field{
              top:120px;
          }
          .auto-popup #sign-up-form .password-field{
              top:170px;
          }
          .auto-popup #sign-up-form .sign-up-btn{
              top:230px;
          }
          .auto-popup #sign-up-form .msg{
              top:275px;
          }
          .auto-popup #sign-in-form{
              height: 280px;
              width: 580px;
              padding: 10px;
          }
          """

HeaderTextForAutoPopup = ->
    div 'call-to-action', ->
        text "Sign in to leave comments or subscribe for updates"

exports.renderStyleForAutoPopup = ck.compile(StyleForAutoPopup)
exports.renderHeaderTextForAutoPopup = ck.compile(HeaderTextForAutoPopup)