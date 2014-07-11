var Steps = require('cucumis').Steps;

var Calculator = function() {
	this._stack = [];
};

Calculator.prototype = {
	enter: function (value) {
		this._stack.push(value);
	},

	get stack() {
		return this._stack;
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
	calc.result().should.eql(parseInt(value));
	ctx.done();
});

Steps.When(/^I press subtract$/, function (ctx) {
	calc.subtract();
	ctx.done();
});

Steps.export(module);
