var Steps = require('cucumis').Steps,
	assert = require('assert'),
	should = require('should'),
	soda = require('soda');

var browserType = 'firefox';
var browser;

var baseUrl = 'http://www.google.com.au';

var pageMap = {
	'Google': {
		'Home': '/',
	},
};

var fieldMap = {
	'Google': {
		'Search Query': 'q',
		'Search': 'btnG',
	},
};

var lastSite;

Steps.Runner.on('afterTest', function(done) {
	if (browser) {
		browser
			.chain
			.testComplete()
			.end(function (err) {
				if (err) throw err;
				done();
			});
	} else {
		done();
	}
});

Steps.Given(/^I am using the "([^"]*)" browser$/, function (ctx, bt) {
	browserType = bt;
	browser = soda.createClient({
		host: 'localhost'
	  , port: 4444
	  , url: baseUrl
	  , browser: browserType
	});

	browser
		.chain
		.session()
		.end(function(err) {
			if (err) throw err;
			ctx.done();
		});
});

Steps.Given(/^I am on the "([^"]*?)" "([^"]*?)" page$/, function (ctx, site, page) {
	lastSite = site;
	var url = pageMap[site][page];

	browser
		.chain
		.open(url)
		.end(function(err) {
			if (err) throw err;
			ctx.done();
		});
});

Steps.When(/^I enter "([^"]*?)" into the "([^"]*?)" text field$/, function (ctx, text, field) {
	browser
		.chain
		.type(fieldMap[lastSite][field], text)
		.end(function(err) {
			if (err) throw err;
			ctx.done();
		});
});

Steps.When(/^I click the "([^"]*?)" "([^"]*?)" button$/, function (ctx, site, field) {
	lastSite = site;
	browser
		.chain
		.click(fieldMap[site][field])
		.waitForPageToLoad(2000)
		.end(function(err) {
			if (err) throw err;
			ctx.done();
		});
});

Steps.Then(/^my title should contain "([^"]*?)"$/, function (ctx, needle) {
	browser
		.chain
		.getTitle(function(title){
			title.should.include.string(needle);
		})
		.end(function(err) {
			if (err) throw err;
			ctx.done();
		});
});

Steps.Then(/^my title shouldn't contain "([^"]*?)"$/, function (ctx, needle) {
	browser
		.chain
		.getTitle(function(title){
			title.should.not.include.string(needle);
		})
		.end(function(err) {
			if (err) throw err;
			ctx.done();
		});
});

Steps.export(module);
