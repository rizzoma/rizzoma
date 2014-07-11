str = """<span>первая строка</span><div>вторая строка</div><div>третья строка</div><div><br /><br /><br /></div>"""

jsdom  = require("jsdom")
doc = jsdom.jsdom()
global.document = doc.createWindow().document
#htmlParser = new (require('../client/editor/parser').HtmlParser)(0)
{ BlockParsedElementProcessor } = require('../server/blip/email_reply_fetcher/body_parser')
htmlParser = new (require('./parser').HtmlParser)(new BlockParsedElementProcessor(), 0)
span = document.createElement('span')
span.innerHTML = str
document.body.appendChild(span)
content = htmlParser.parse(document.firstChild)
console.log(content)