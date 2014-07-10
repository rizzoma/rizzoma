testCase = require('nodeunit').testCase
sinon = require('sinon-plus')
dataprovider = require('dataprovider')
{EmailBodyParser} = require('../../../../server/blip/email_reply_fetcher/body_parser')
{GmailBodyParser} = require('../../../../server/blip/email_reply_fetcher/body_parser')
{ThunderbirdBodyParser} = require('../../../../server/blip/email_reply_fetcher/body_parser')
{AppleMailBodyParser} = require('../../../../server/blip/email_reply_fetcher/body_parser')
{DefaultMailBodyParser} = require('../../../../server/blip/email_reply_fetcher/body_parser')
{BaseEmailBodyParser} = require('../../../../server/blip/email_reply_fetcher/body_parser')

module.exports =
    EmailBodyParserTest: testCase
        setUp: (callback) ->
            @_random = Math.random
            Math.random = () ->
                return 'random'
            callback()

        tearDown: (callback) ->
            Math.random = @_random
            callback()

        test_factory: (test) ->
            code = (done, exp, mail) ->
                parser = EmailBodyParser._factory(mail)
                test.ok(parser instanceof exp)
                done()

            dataprovider(test,[
                [GmailBodyParser, {headers: {'message-id': "safertgfertert@mail.gmail.com"}}]
                [ThunderbirdBodyParser, {headers: {'user-agent': "Mozilla/5.0 (X11; Linux i686; rv:15.0) Gecko/20120912 Thunderbird/15.0.1"}}]
                [AppleMailBodyParser, {headers: {'x-mailer': "dfgdfgg ddfg Apple Mail"}}]
                [DefaultMailBodyParser, {headers: {'x-mailer': "dfgdfgg ddfg Microsoft Outlook"}}]
                [DefaultMailBodyParser, {headers: {'x-mailer': "dfgdfgg ddfg Microsoft Outlook Express"}}]
                [DefaultMailBodyParser, {headers: {'x-mailer': "dfgdfgg ddfg YahooMailService"}}]
                [DefaultMailBodyParser, {headers: {'x-mailer': "dfgdfgg ddfg iPhone Mail"}}]
            ], code)

        test_cutCiteFromText: (test) ->
            code = (done, exp, text) ->
                res = new DefaultMailBodyParser()._cutCiteFromText(text)
                test.equal(exp, res)
                done()
            dataprovider(test, [
                [
                    'Это ответ из андроид gmail\n26.09.2012 19:47 пользователь "Yury Iliinkh" <yuryilinikh@gmail.com>\nнаписал:'
                    'Это ответ из андроид gmail\n26.09.2012 19:47 пользователь "Yury Iliinkh" <yuryilinikh@gmail.com>\nнаписал:\n>\n> 26.09.2012 19:45, Yury Iliinkh пишет:\n>>\n>> Это\n>\n> Comment1\n>>\n>>\n>> многострочное\n>\n> Comment2\n>>\n>> письмо\n>> из Thunderbird\n>\n> Это письмо с комментариями\n'
                ],
                [
                    'Это\nмногоастрочное\nписьмо\nиз\nOutlook'
                    'Это\r\nмногоастрочное\r\nписьмо\r\nиз\r\nOutlook\r\n'
                ],
                [
                    'Это письмо с комментариями из Outlook'
                    'Это письмо с комментариями из Outlook\r\n\r\n-----Original Message-----\r\nFrom: yuryilinikh@gmail.com [mailto:yuryilinikh@gmail.com] \r\nSent: Wednesday, September 26, 2012 2:18 PM\r\nTo:\r\nyuryilinikh+5869e58e5b6eab6fac5455e7b1002511/0_b_2_12/sdfc43325sdvfsd@gmail.\r\ncom\r\nSubject: Это многострочное письмо из Outlook\r\n\r\nЭто\r\ncomment1\r\nмногоастрочное\r\ncomment2\r\nписьмо\r\ncomment3\r\nиз\r\nOutlook\r\n'
                ],
                [
                    'Этописьмо с комментариями из Outlook Express\n  ----- Original Message ----- \n  From: yuryilinikh@gmail.com\n  To: Юрий Ильиных\n  Sent: Wednesday, September 26, 2012 2:23 PM\n  Subject: Это многострочноесписьмо из Outlook Express\n\n\n  Это\n\n  comment1\n\n  многострочноес\n\n  comment2\n\n  письмо\n\n   из\n\n  Outlook Express'
                    'Этописьмо с комментариями из Outlook Express\n  ----- Original Message ----- \n  From: yuryilinikh@gmail.com \n  To: Юрий Ильиных \n  Sent: Wednesday, September 26, 2012 2:23 PM\n  Subject: Это многострочноесписьмо из Outlook Express\n\n\n  Это \n\n  comment1\n\n  многострочноес \n\n  comment2\n\n  письмо\n\n   из \n\n  Outlook Express\n'
                ],
                [
                    'Это ответ из Outlook Express'
                    'Это ответ из Outlook Express\n\n  ----- Original Message ----- \n  From: yuryilinikh@gmail.com \n  To: Юрий Ильиных \n  Sent: Tuesday, September 25, 2012 9:44 PM\n  Subject: Это письмо из Outlook Express\n\n\n  Это письмо из Outlook Express\n'
                ],
                [
                    '\nЭто ответ из HOTMAIL\n\nDate: Tue, 25 Sep 2012 19:57:52 +0300\nSubject: Письмо в hotmail чтобы ответить\nFrom: yuryilinikh@gmail.com\nTo: yuryilinikh@hotmail.com\n\nПисьмо в hotmail чтобы ответить'
                    '\nЭто ответ из HOTMAIL\n\nDate: Tue, 25 Sep 2012 19:57:52 +0300\nSubject: Письмо в hotmail чтобы ответить\nFrom: yuryilinikh@gmail.com\nTo: yuryilinikh@hotmail.com\n\nПисьмо в hotmail чтобы ответить'
                ],
                [
                    'Это письмо с комментариями к ответу'
                    'Это письмо с комментариями к ответу\n\n\n________________________________\n From: Юрий Ильиных <yuryilinikh@gmail.com>\nTo: yuryilinikh@yahoo.com \nSent: Tuesday, September 25, 2012 2:19 PM\nSubject: Письмо в Yahoo\n \n\nЭто письмо в яху  чтобы \n123\n\nпотом на него ответить \n345'
                ],
                [
                    'this another response from yahoo'
                    'this another response from yahoo\n\n\n________________________________\n From: Юрий Ильиных <yuryilinikh@gmail.com>\nTo: yuryilinikh@yahoo.com \nSent: Tuesday, September 25, 2012 2:19 PM\nSubject: Письмо в Yahoo\n \n\nЭто письмо в яху  чтобы потом на него ответить '
                ]
            ], code)

        test_parseText: (test) ->
            code = (done, exp, text) ->
                res = new DefaultMailBodyParser()._parseText(text)
                test.deepEqual(exp, res)
                done()

            dataprovider(test, [
                [
                    [
                        { t: 'Хм', params: { __TYPE: 'TEXT' } }
                    ]
                    '\n\r\tХм'
                ]
                [
                    [
                        { t: 'Хм', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: '    хм', params: { __TYPE: 'TEXT' } }
                    ]
                    'Хм\n\r\tхм'
                ]
            ], code)

        testGmailGetBlipContent: (test) ->
            code = (done, exp, mail) ->
                parser = new GmailBodyParser()
                content = parser.getBlipContent(mail)
                test.deepEqual(exp, content)
                done()
            dataprovider(test, [
                [
                    [
                        { t: 'Это письмо с комментариями из Gmail', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: '26 сентября 2012 г., 17:00 пользователь Юрий Ильиных ', params: { __TYPE: 'TEXT' } },
                        { t: '<', params: { __TYPE: 'TEXT' } },
                        { t: 'yuryilinikh@gmail.com', params: { T_URL: 'mailto:yuryilinikh@gmail.com', __TYPE: 'TEXT' } },
                        { t: '>', params: { __TYPE: 'TEXT' } },
                        { t: ' написал:', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: 'Это', params: { T_BOLD: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: 'Comment1 ', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: 'многострочное', params: { T_ITALIC: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: 'Comment2 ', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: 'письмо', params: { T_UNDERLINED: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: "random" } },
                        { t: 'из ', params: { __TYPE: 'TEXT' } },
                        { t: 'Gmail', params: { T_URL: 'http://mail.google.com', __TYPE: 'TEXT' } }
                    ],
                    { html: 'Это письмо с комментариями из Gmail<br><br><div class="gmail_quote">26 сентября 2012 г., 17:00 пользователь Юрий Ильиных <span dir="ltr">&lt;<a href="mailto:yuryilinikh@gmail.com" target="_blank">yuryilinikh@gmail.com</a>&gt;</span> написал:<br>\n<blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex"><b>Это</b> </blockquote><div>Comment1 </div><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex">\n<div><i>многострочное</i> </div></blockquote><div>Comment2 </div><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex"><div><u>письмо</u> </div><div>из <a href="http://mail.google.com" target="_blank">Gmail</a></div>\n\n</blockquote></div><br>\n' }
                ],
                [
                    [
                        { t: 'Это', params: { T_BOLD: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'TEXT' } },
                        { t: 'ответ', params: { T_ITALIC: true, __TYPE: 'TEXT' } },
                        { t: ' из ', params: { __TYPE: 'TEXT' } },
                        { t: 'Gmail', params: { T_URL: 'http://mail.google.com/', __TYPE: 'TEXT' } }
                    ],
                    { html: '<b>Это</b> <i>ответ</i> из <a href="http://mail.google.com/" target="_blank">Gmail</a><br><br><div class="gmail_quote">26 сентября 2012 г., 17:00 пользователь Юрий Ильиных <span dir="ltr">&lt;<a href="mailto:yuryilinikh@gmail.com" target="_blank">yuryilinikh@gmail.com</a>&gt;</span> написал:<br>\n<blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex"><b>Это</b> <div><i>многострочное</i> </div><div><u>письмо</u> </div><div>из <a href="http://mail.google.com" target="_blank">Gmail</a></div>\n\n</blockquote></div><br>\n' }
                ]
            ], code)

        testThunderbirdGetBlipContent: (test) ->
            code = (done, exp, mail) ->
                parser = new ThunderbirdBodyParser()
                content = parser.getBlipContent(mail)
#                console.log(content)
                test.deepEqual(exp, content)
                done()
            dataprovider(test, [
                [
                    [
                        { t: 'Это', params: { T_BOLD: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'ответ', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'из ', params: { __TYPE: 'TEXT' } },
                        { t: 'Thunderbird', params: { T_URL: 'http://mozilla.org', __TYPE: 'TEXT' } }
                    ],
                    { html: '<html>\n  <head>\n    <meta http-equiv="content-type" content="text/html; charset=utf-8" />\n  </head>\n  <body bgcolor="#FFFFFF" text="#000000">\n    <div class="moz-cite-prefix">26.09.2012 19:45, Yury Iliinkh пишет:<br>\n    </div>\n    <blockquote cite="mid:5063312A.90104@gmail.com" type="cite">\n      <meta http-equiv="content-type" content="text/html; charset=utf-8" />\n      <b>Это</b> <br>\n      <i>многострочное</i> <br>\n      <u>письмо</u> <br>\n      из <a moz-do-not-send="true" href="http://mozilla.org">Thunderbird</a>\n    </blockquote>\n    <b>Это</b> <br>\n    ответ<br>\n    из <a moz-do-not-send="true" href="http://mozilla.org">Thunderbird</a>\n  </body>\n</html>\n' }
                ]
                [
                    [
                        { t: '26.09.2012 19:45, Yury Iliinkh пишет:', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'Это', params: { T_BOLD: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'Comment1', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'многострочное', params: { T_ITALIC: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'Comment2', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'письмо', params: { T_UNDERLINED: true, __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'из ', params: { __TYPE: 'TEXT' } },
                        { t: 'Thunderbird', params: { T_URL: 'http://mozilla.org', __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'Это письмо с комментариями', params: { __TYPE: 'TEXT' } }
                    ],
                    { html: '<html>\n  <head>\n    <meta http-equiv="content-type" content="text/html; charset=utf-8" />\n  </head>\n  <body bgcolor="#FFFFFF" text="#000000">\n    <div class="moz-cite-prefix">26.09.2012 19:45, Yury Iliinkh пишет:<br>\n    </div>\n    <blockquote cite="mid:5063312A.90104@gmail.com" type="cite">\n      <meta http-equiv="content-type" content="text/html; charset=utf-8" />\n      <b>Это</b></blockquote>\n    Comment1<br>\n    <blockquote cite="mid:5063312A.90104@gmail.com" type="cite"> <br>\n      <i>многострочное</i> <br>\n    </blockquote>\n    Comment2\n    <blockquote cite="mid:5063312A.90104@gmail.com" type="cite"> <u>письмо</u>\n      <br>\n      из <a moz-do-not-send="true" href="http://mozilla.org">Thunderbird</a>\n    </blockquote>\n    Это письмо с комментариями<br>\n  </body>\n</html>\n' }
                ]
            ], code)

        testAppleMailGetBlipContent: (test) ->
            code = (done, exp, mail) ->
                parser = new AppleMailBodyParser()
                content = parser.getBlipContent(mail)
#                console.log(content)
                test.deepEqual(exp, content)
                done()
            dataprovider(test, [
                [
                    [
                        { t: 'test', params: { __TYPE: 'TEXT' } }
                    ],
                    { html: '<html><head></head><body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space; ">test<br><div><div>On 24.09.2012, at 23:30, Facebook wrote:</div><br class="Apple-interchange-newline"><blockquote type="cite">\n<meta http-equiv="content-type" content="text/html; charset=utf-8" /><title>Facebook</title><div style="margin: 0; padding: 0;" dir="ltr"><table width="98%" border="0" cellspacing="0" cellpadding="40"><tbody><tr><td bgcolor="#f7f7f7" width="100%" style="font-family:\'lucida grande\',tahoma,verdana,arial,sans-serif;"><table cellpadding="0" cellspacing="0" border="0" width="620"><tbody><tr><td style="background:#3b5998;color:#FFFFFF;font-weight:bold;font-family:\'lucida grande\',tahoma,verdana,arial,sans-serif;vertical-align:middle;padding:4px 8px; font-size: 16px; letter-spacing: -0.03em; text-align: left;"><a style="color:#FFFFFF; text-decoration: none;" href="http://www.facebook.com/n/?photo.php&amp;fbid=509383659090244&amp;set=a.349859858375959.98417.317394914955787&amp;type=1&amp;comment_id=1671329&amp;mid=6cac00fG5af3bff2d1c7G1f4f5d5G9&amp;bcode=NFpTvFAS_1.1348518626.AaTZJHYZp-pKDxgs&amp;n_m=volnaman%40gmail.com"><span style="color:#FFFFFF">facebook</span></a></td><td style="background:#3b5998;color:#FFFFFF;font-weight:bold;font-family:\'lucida grande\',tahoma,verdana,arial,sans-serif;vertical-align:middle;padding:4px 8px;font-size: 11px; text-align: right;"></td></tr><tr><td colspan="2" style="background-color: #FFFFFF; border-bottom: 1px solid #3b5998; border-left: 1px solid #CCCCCC; border-right: 1px solid #CCCCCC; padding: 15px;font-family:\'lucida grande\',tahoma,verdana,arial,sans-serif;" valign="top"><table width="100%" cellpadding="0" cellspacing="0"><tbody><tr><td width="470px" style="font-size:12px;" valign="top" align="left"><div style="margin-bottom:15px; font-size:12px;font-family:\'lucida grande\',tahoma,verdana,arial,sans-serif;">Здравствуйте, Волна!</div><div style="margin-bottom:15px;">Владимир Кобзев прокомментировал фотографию <a href="http://Rizzoma.com">Rizzoma.com</a></div><div style="margin-bottom:15px;"><span style="">Владимир написали: Cool! Cool! and Cool!</span><br><br><table cellspacing="0" cellpadding="0" style="border-collapse:collapse;"><tbody><tr><td style="font-size:11px;font-family:LucidaGrande,tahoma,verdana,arial,sans-serif;padding:10px;background-color:#fff9d7;border-left:1px solid #e2c822;border-right:1px solid #e2c822;border-top:1px solid #e2c822;border-bottom:1px solid #e2c822;"><a href="http://www.facebook.com/n/?photo.php&amp;fbid=509383659090244&amp;set=a.349859858375959.98417.317394914955787&amp;type=1&amp;comment_id=1671329&amp;mid=6cac00fG5af3bff2d1c7G1f4f5d5G9&amp;bcode=NFpTvFAS_1.1348518626.AaTZJHYZp-pKDxgs&amp;n_m=volnaman%40gmail.com" style="color:#3b5998;text-decoration:none;">Перейти к комментариям</a></td></tr></tbody></table><br>Ответьте на это письмо, чтобы оставить комментарий к этой фотографии.\n\n<br></div></td><td valign="top" width="150" style="padding-left: 15px;" align="left"><table cellspacing="0" cellpadding="0" style="border-collapse:collapse;"><tbody><tr><td style="font-size:11px;font-family:LucidaGrande,tahoma,verdana,arial,sans-serif;padding:10px;background-color:#fff9d7;border-left:1px solid #e2c822;border-right:1px solid #e2c822;border-top:1px solid #e2c822;border-bottom:1px solid #e2c822;"><table cellspacing="0" cellpadding="0" style="border-collapse:collapse;"><tbody><tr><td style="border-width: 1px;border-style: solid;border-color: #3b6e22 #3b6e22 #2c5115;background-color: #69a74e;"><table cellspacing="0" cellpadding="0" style="border-collapse:collapse;"><tbody><tr><td style="font-size:11px;font-family:LucidaGrande,tahoma,verdana,arial,sans-serif;padding:2px 6px 4px;border-top:1px solid #95bf82;"><a href="http://www.facebook.com/n/?photo.php&amp;fbid=509383659090244&amp;set=a.349859858375959.98417.317394914955787&amp;type=1&amp;comment_id=1671329&amp;mid=6cac00fG5af3bff2d1c7G1f4f5d5G9&amp;bcode=NFpTvFAS_1.1348518626.AaTZJHYZp-pKDxgs&amp;n_m=volnaman%40gmail.com" style="color:#3b5998;text-decoration:none;"><span style="font-weight:bold;white-space:nowrap;color: #fff;font-size: 13px;">См. Комментарий</span></a></td></tr></tbody></table></td></tr></tbody></table></td></tr></tbody></table></td></tr></tbody></table></td></tr><tr><td colspan="2" style="color:#999999;padding:10px;font-size:12px; font-family:\'lucida grande\',tahoma,verdana,arial,sans-serif;">Сообщение было отправлено на <a href="mailto:volnaman@gmail.com" style="color:#3b5998;text-decoration:none;">volnaman@gmail.com</a>. Если вы не хотите в дальнейшем получать такие сообщения от Facebook, пожалуйста нажмите <a href="http://www.facebook.com/o.php?k=AS2VEGpmR1mozeW9&amp;u=100002943914439&amp;mid=6cac00fG5af3bff2d1c7G1f4f5d5G9" style="color:#3b5998;text-decoration:none;">отказаться от подписки</a>.<br> Facebook, Inc. Attention: Department 415 P.O Box 10005 Palo Alto CA 94303 </td></tr></tbody></table></td></tr></tbody></table></div><span style=""><img src="http://www.facebook.com/email_open_log_pic.php?c=595154956&amp;mid=6cac00fG5af3bff2d1c7G1f4f5d5G9" style="border:0;width:1px;height:1px;"></span>\n\n\n</blockquote></div><br></body></html>' }
                ]
                [
                    [
                        { t: 'test', params: { __TYPE: 'TEXT' } }
                    ]
                    { text: 'test\r\nOn 24.09.2012, at 23:30, Facebook wrote:\r\n\r\n> \r\n> facebook\t\r\n> Здравствуйте, Волна!\r\n> Владимир Кобзев прокомментировал фотографию Rizzoma.com\r\n> Владимир написали: Cool! Cool! and Cool!\r\n> \r\n> Перейти к комментариям\r\n> \r\n> Ответьте на это письмо, чтобы оставить комментарий к этой фотографии. \r\n> См. Комментарий\r\n> Сообщение было отправлено на volnaman@gmail.com. Если вы не хотите в дальнейшем получать такие сообщения от Facebook, пожалуйста нажмите отказаться от подписки.\r\n> Facebook, Inc. Attention: Department 415 P.O Box 10005 Palo Alto CA 94303\r\n> \r\n\r\n'}
                ]
                [
                    [
                        { t: 'test', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'On 24.09.2012, at 23:30, Facebook wrote:',
                        params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'cite1', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'comment1', params: { __TYPE: 'TEXT' } },
                        { t: ' ', params: { __TYPE: 'LINE', RANDOM: 'random' } },
                        { t: 'cite2', params: { __TYPE: 'TEXT' } },
                    ],
                    { html: '<html><head></head><body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space; ">test<br><div><div>On 24.09.2012, at 23:30, Facebook wrote:</div><br class="Apple-interchange-newline"><blockquote type="cite">cite1</blockquote>comment1<blockquote type="cite">\ncite2</blockquote></div><br></body></html>' }
                ]
            ], code)

        test_trimContent: (test) ->
            code = (done, exp, content) ->
                parser = new BaseEmailBodyParser()
                content = parser._trimContent(content)
                test.deepEqual(exp, content)
                done()
            dataprovider(test, [
                [
                    [
                        { t: 'kkjhkj', params: {__TYPE: 'TEXT'}}
                    ]
                    [
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' kkjhkj ', params: {__TYPE: 'TEXT'}}
                    ]
                ]
                [
                    [
                        { t: 'kkjhkj', params: {__TYPE: 'TEXT'}}
                    ]
                    [
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' kkjhkj ', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                    ]
                ]
                [
                    [
                        { t: 'bbbb ', params: {__TYPE: 'TEXT'}}
                        { t: 'kkjhkj', params: {__TYPE: 'TEXT'}}
                        { t: ' ssss', params: {__TYPE: 'TEXT'}}
                    ]
                    [
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: '  bbbb ', params: {__TYPE: 'TEXT'}}
                        { t: 'kkjhkj', params: {__TYPE: 'TEXT'}}
                        { t: ' ssss   ', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                    ]
                ]
                [
                    [
                        { t: 'bbbb ', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: 'kkjhkj', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ssss', params: {__TYPE: 'TEXT'}}
                    ]
                    [
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: '  bbbb ', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: 'kkjhkj', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ssss   ', params: {__TYPE: 'TEXT'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                        { t: ' ', params: {__TYPE: 'LINE'}}
                    ]
                ]
            ], code)

        test_replaceNotificationHrefs: (test) ->
            code = (done, exp, text) ->
                parser = new BaseEmailBodyParser()
                content = parser._replaceNotificationHrefs(text)
                test.deepEqual(exp, content)
                done()
            dataprovider(test, [
                [
                    'http://localhost:8000/notification/settings/?email=xxx&hash=xxx&from=message'
                    'http://localhost:8000/notification/settings/?email=yuryilinikh%40gmail.com&hash=12343245dfsj&from=message'
                ]
                [
                    'http://localhost:8000/notification/settings/?email=xxx&hash=xxx&amp;from=message'
                    'http://localhost:8000/notification/settings/?email=yuryilinikh%40gmail.com&amp;hash=2e61ef401eeb99b8&amp;from=message'
                ]
            ], code)
        testDefaultGetBlipContent: (test) ->
            code = (done, exp, mail) ->
                parser = new DefaultMailBodyParser()
                content = parser.getBlipContent(mail)
                test.deepEqual(exp, content)
                done()
            dataprovider(test, [
                [
                    "",
                    {getId: ()-> return 123 }
                ],
            ], code)
