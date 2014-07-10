# cucumis

Cucumis is a basic implementation of [cucumber's](http://cukes.info) [gherkin](https://github.com/aslakhellesoy/cucumber/wiki/gherkin) BDD plain-english testing language in node.js. 

It was designed to meet the following criteria:

- Run in node.js (cucumber only supports v8 currently and not the node.js commonjs package system)
- Support asynchronous tests (cucumber only supports a synchronous system currently)

It was built upon the gherkin parser [kyuri](https://github.com/nodejitsu/kyuri).

## Installation

The easiest way to install cucumis is via the npm package manager:

	npm install cucumis

## Screencasts

- see cucumis in action with some [web browser testing](http://screencast.com/t/AepofsIZ)

## Writing tests

Tests are written in cucumber's [gherkin](https://github.com/aslakhellesoy/cucumber/wiki/gherkin) language.

Create a folder called 'features' under your current directory which contains your .feature files.

For example (addition.feature):

	Feature: Addition
		In order to avoid silly mistakes
		As a math idiot
		I want to be able to add up numbers

		Scenario: Add two numbers
			Given I have a calculator
			And I have entered 50 into the calculator
			And I have entered 70 into the calculator
			When I press add
			Then the result should be 120 on the screen

Then run cucumis:

	$ cucumis

You'll get the test results and a list of code snippets you'll need to implement to make the tests actually pass:

	Feature: Addition
	  In order to avoid silly mistakes
	  As a math idiot
	  I want to be able to add up numbers
	  
	Scenario: Add two numbers
	  Given I have a calculator
	  And I have entered 50 into the calculator
	  And I have entered 70 into the calculator
	  When I press add
	  Then the result should be 120 on the screen

	1 scenarios (1 passed, 1 undefined)
	5 steps (5 undefined)
	0m0.005s

	You can implement step definitions for undefined steps with these snippets:

	var Steps = require('cucumis').Steps;

	Steps.Given(/^I have a calculator$/, function (ctx) {
	  ctx.pending();
	});

	Steps.Given(/^I have entered (\d+) into the calculator$/, function (ctx, arg1) {
	  ctx.pending();
	});

	Steps.When(/^I press add$/, function (ctx) {
	  ctx.pending();
	});

	Steps.Then(/^the result should be (\d+) on the screen$/, function (ctx, arg1) {
	  ctx.pending();
	});

	Steps.export(module);

Simply add the code snippets to a .js file (eg. addition.js) in the step_definitions folder beneath the features folder. For example:

	var Steps = require('kyuri').Steps;
	var assert = require('assert');

	var Calculator = function() {
		this._stack = [];
	};

	Calculator.prototype = {
		enter: function (value) {
			this._stack.push(value);
		},

		add: function() {
			this._stack.push(this._stack.pop() + this._stack.pop());
		},

		subtract: function() {
			this._stack.push(-(this._stack.pop() - this._stack.pop()));
		},

		result: function() {
			return this._stack[this._stack.length - 1];
		},
	};

	var calc;

	Steps.Given(/^I have a calculator$/, function(ctx) {
		calc = new Calculator();
		setTimeout(function() {
			ctx.done();
		}, 10);
	});

	Steps.Given(/^I have entered (\d+) into the calculator$/, function (ctx, value) {
		calc.enter(parseInt(value));
		ctx.done();
	});

	Steps.When(/^I press add$/, function (ctx) {
		calc.add();
		ctx.done();
	});

	Steps.Then(/^the result should be (\d+) on the screen$/, function (ctx, value) {
		assert.equal(calc.result(), parseInt(value));
		ctx.done();
	});

	Steps.export(module);

Then run cucumis again:

	Feature: Addition
	  In order to avoid silly mistakes
	  As a math idiot
	  I want to be able to add up numbers
	  
	Scenario: Add two numbers
	  Given I have a calculator
	  And I have entered 50 into the calculator
	  And I have entered 70 into the calculator
	  When I press add
	  Then the result should be 120 on the screen

	1 scenarios (1 passed)
	5 steps (5 passed)
	0m0.017s

You can perform asynchronous tests like:

	Steps.Given(/^I have a calculator$/, function(ctx) {
		calc = new Calculator();
		setTimeout(function() {
			ctx.done();
		}, 10);
	});

And by default, each step will need to complete in under 2 seconds otherwise a timeout error will be thrown.

## contributors
 - [Eugene Ware](http://eugeneware.com)
 - [kyuri](https://github.com/nodejitsu/kyuri)
 - You?

## license

Copyright 2010-2011 Noble Samurai

cucumis is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

cucumis is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with cucumis.  If not, see http://www.gnu.org/licenses/.

