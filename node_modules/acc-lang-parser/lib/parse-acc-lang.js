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

function parseLangRange(lang_range) {
	var extractPartsReg = /^([\w\*]*)(-(\w*))?.*$/i;

	var match = lang_range.trim().match(extractPartsReg);

	if (!match) {
		return undefined;
	}
	
	// we will store the result in here to be returned later
	var result = {};

	// parse language
	var parseLangReg = /^([a-z]{2}|\*)$/i;
	var lang = match[1];
	if (lang) {
		var langMatch = lang.match(parseLangReg);
		if (langMatch) {
			result.language = langMatch[0].toLowerCase();
		}
	}

	// parse locale
	var parseLocaleReg = /[a-z]{2}/i;
	var locale = match[3];
	if (locale) {
		var localeMatch = locale.match(parseLocaleReg);
		if (localeMatch) {
			result.locale = localeMatch[0].toUpperCase();
		}
	}

	// if we havn't found anything return undefined
	if (result.language || result.locale) {
		return result;
	}

	return undefined;
}

function extractFirstLang(accLangHeader) {
	// return if input is invalid
	if (!accLangHeader) {
		return undefined;
	}
	
	var split = accLangHeader.split(",");
	if (split[0]) {
		return parseLangRange(split[0]);
	} else {
		return undefined;
	}
}


function extractAllLangs(accLangHeader) {
	// return if input is invalid
	if (!accLangHeader) {
		return [];
	}

	var split = accLangHeader.split(",");
	if (split.length > 0) {
		var result = [];
		split.forEach(function (i) {
			var extretion = parseLangRange(i);
			if (extretion) {
				result.push(extretion);
			}
		});

		return result;
	} else {
		return [];
	}
}

exports.extractFirstLang = extractFirstLang;
exports.extractAllLangs = extractAllLangs;
