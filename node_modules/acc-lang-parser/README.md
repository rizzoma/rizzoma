# acc-lang-parser

A simple parser for http Accept-Language Headers in nodejs.

# usage

To only get the first language of the header:

```
var accLangParser = require("parse-acc-lang");
var result = accLangParser.extractFirstLang("de-DE");

result => {language: "de", locale: "DE"}
```

To get a list of all languages:

```
var accLangParser = require("parse-acc-lang");
var result = accLangParser.extractAllLangs("de-DE, en-GB");

result => [{language: "de", locale: "DE"}
		  ,{language: "en", locale: "GB"}]
```

Take a look into the specs for more details about invalid handlers.

Use accLangParser.extractFirstLang if you only interested in the first language range, because this function will skip on parsing the other ranges.

# testing

To run the test:

```jasmine-node spec/```  
or  
```npm test```

# license

The license can be found in license.md.