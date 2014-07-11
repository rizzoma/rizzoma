
// MIT License
//
// Copyright (c) 2012 AdCloud GmbH
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the
// Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies
// or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"use strict";

var accLangParser = require("lib/parse-acc-lang");

describe("accept-language http header parser", function () {
	describe("for valid headers", function () {
		describe("header:de", function () {
			it("should extract the highest ranked language", function () {
				var acc_lang_header_content = "de";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.language).toEqual("de");
			});

			it("should not return any locale because its missing", function () {
				var acc_lang_header_content = "de";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.locale).toBeUndefined();
			});
		});

		describe("header:de-DE", function () {
			it("should extract the highest ranked language", function () {
				var acc_lang_header_content = "de-DE";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.language).toEqual("de");
			});

			it("should extract the highest ranked locale", function () {
				var acc_lang_header_content = "de-DE";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.locale).toEqual("DE");
			});
		});

		describe("header:DE-DE", function () {
			it("should ensure that the language is in lower case", function () {
				var acc_lang_header_content = "DE-DE";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.language).toEqual("de");
			});
		});

		describe("header:de-de", function () {
			it("should ensure that the locale is in upper case", function () {
				var acc_lang_header_content = "de-de";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.locale).toEqual("DE");
			});
		});

		describe("header:*", function () {
			it("should handle the special any char (*) correctly", function () {
				var acc_lang_header_content = "*";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.language).toEqual("*");
			});

			it("should not have a locale in case of *", function () {
				var acc_lang_header_content = "*";
				var result = accLangParser.extractFirstLang(acc_lang_header_content);
				expect(result.locale).toBeUndefined();
			});
		});

		describe("when multiple languages are of interest accLangParser.extractAllLangs", function () {
			it("should parse multiple languages like: de, en", function () {
				var acc_lang_header_content = "de, en";
				var result = accLangParser.extractAllLangs(acc_lang_header_content);

				expect(result.length).toEqual(2);

				expect(result[0].language).toEqual("de");
				expect(result[1].language).toEqual("en");
			});
			
			it("should parse multiple languages with locale", function () {
				var acc_lang_header_content = "de-DE, en-GB";
				var result = accLangParser.extractAllLangs(acc_lang_header_content);

				expect(result.length).toEqual(2);

				expect(result[0].language).toEqual("de");
				expect(result[0].locale).toEqual("DE");

				expect(result[1].language).toEqual("en");
				expect(result[1].locale).toEqual("GB");
			});
			
			it("should parse multiple languages with locale and priority accLangParser.extractAllLangs (de-DE,de;q=0.8,en-US;q=0.6,en;q=0.4)", function () {
				var acc_lang_header_content = "de-DE,de;q=0.8,en-US;q=0.6,en;q=0.4";
				var result = accLangParser.extractAllLangs(acc_lang_header_content);

				expect(result.length).toEqual(4);

				expect(result[0].language).toEqual("de");
				expect(result[0].locale).toEqual("DE");

				expect(result[1].language).toEqual("de");
				expect(result[1].locale).toBeUndefined();

				expect(result[2].language).toEqual("en");
				expect(result[2].locale).toEqual("US");

				expect(result[3].language).toEqual("en");
				expect(result[3].locale).toBeUndefined();
			});
		});
	});

	describe("in case of missing headers accLangParser.extractAllLangs", function () {
		it("should be resilient to undefined input", function () {
			var acc_lang_header_content;
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});
		
		it("should be resilient to empty headers", function () {
			var acc_lang_header_content = "";
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});
	});

	describe("in case of invalid headers accLangParser.extractAllLangs", function () {
		it("should be resilient to chines jibberisch: 8痂", function () {
			var acc_lang_header_content = "8痂";
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});

		it("should parse the language even if the locale is invalid", function () {
			var acc_lang_header_content = "es-ES_tradnl"; // real life case
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result.length).toEqual(1);

			expect(result[0].language).toEqual("es");
		});

		it("should parse the language even if the locale is a number", function () {
			var acc_lang_header_content = "es-419"; // real life case
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result.length).toEqual(1);

			expect(result[0].language).toEqual("es");
		});

		it("should parse following language ranges normaly even if one is not valid like es-419,es;q=0.8", function () {
			var acc_lang_header_content = "es-419,es;q=0.8"; // real life case
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result.length).toEqual(2);

			expect(result[0].language).toEqual("es");
			expect(result[1].language).toEqual("es");
		});

		it("should be resilient to none 2-ALPHA languages like: ded", function () {
			var acc_lang_header_content = "ded";
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});

		it("should be resilient to jibberisch", function () {
			var acc_lang_header_content = "§$$&de";
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});

		it("should be resilient to -", function () {
			var acc_lang_header_content = "-";
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});
		
		it("should be resilient to numbers", function () {
			var acc_lang_header_content = "12364";
			var result = accLangParser.extractAllLangs(acc_lang_header_content);

			expect(result).toEqual([]);
		});
	});
});