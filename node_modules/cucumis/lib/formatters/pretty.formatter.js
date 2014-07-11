// Format printing object
var colorize = require('../support/colorize').colorize,
	indent = require('../support/indent'),
	_ = require('underscore');

function strJoin() {
	return _.compact(arguments).join(', ');;
}

module.exports.Formatter = function() {
	this.undefinedSteps = {};

	this.scenarioCount = 0;

	this.stepCount = 0;

	this.undefinedStepCount = 0;
	this.undefinedScenarioCount = 0;

	this.passedStepCount = 0;
	this.passedScenarioCount = 0;

	this.pendingStepCount = 0;
	this.pendingScenarioCount = 0;

	this.skippedStepCount = 0;

	this.failedStepCount = 0;
	this.failedScenarioCount = 0;
	this.startTime = Date.now();
}

module.exports.Formatter.prototype = {

	generalUncaughtException: function(err) {
		var errors = [];
		errors.push(err.name ? 'name: ' + err.name : '');
		errors.push(err.message ? 'message: ' + err.message : '');
		errors.push(err.stack ? indent(err.stack, 1) : '');

		console.log(indent(colorize('red', 'Error caught:')));
		console.log(indent(colorize('red', errors.join('\n')), 2));
	},

	asyncStepTimeoutError: function(eventName, level, err) {
		if (err) {
			var errors = [];
			errors.push(err.name ? 'name: ' + err.name : '');
			errors.push(err.message ? 'message: ' + err.message : '');
			errors.push(err.stack ? indent(err.stack, 1) : '');

			console.log(indent(colorize('red', 'Error while processing event: ' + eventName), level));
			console.log(indent(colorize('red', errors.join('\n')), level + 1));
		} else {
			console.log(indent(colorize('red', 'Timeout waiting for response on event: ' + eventName + '\n'), level));
		}
	},

	beforeFeature: function(feature) {
		console.log('Feature: ' + feature.name);
		console.log(indent(feature.description, 1));
	},

	afterFeature: function(feature) {
	},

	beforeScenarioOutline: function(scenarioOutline) {
		console.log(indent('Scenario Outline: ' + scenarioOutline.name, 1));
	},

	afterScenarioOutline: function(scenarioOutline) {
	},

	beforeScenario: function(scenario) {
		if (!scenario.outline) {
			console.log(indent('Scenario: ' + scenario.name, 1));
		}
	},

	afterScenario: function(scenario) {
	},

	beforeBackground: function(scenario) {
		if (!scenario.backgroundPrinted) {
			console.log(indent('Background:', 1));
		}
	},

	afterBackground: function(scenario) {
	},

	beforeStep: function(step) {
	},

	afterStep: function(step) {
	},

	afterSteps: function(scenario) {
		if (!scenario.background || (scenario.background && !scenario.backgroundPrinted)) {
			console.log('');
		}
	},

	afterStepResult: function(scenario, stepLine, result, msg, err) {
		var colorMap = {
			'pass': 'green',
			'fail': 'red',
			'pending': 'yellow',
			'skipped': 'cyan',
			'undefined': 'yellow',
		};

		if (!scenario.background || (scenario.background && !scenario.backgroundPrinted)) {
			console.log(indent(colorize(colorMap[result], stepLine), 2));
		}

		if (msg) {
			console.log(indent(colorize(colorMap[result], msg), 3));
		}

		if (err) {
			var errors = [];
			errors.push(err.name ? 'name: ' + err.name : '');
			errors.push(err.message ? 'message: ' + err.message : '');
			errors.push(err.stack ? indent(err.stack, 2) : '');
			console.log(indent(colorize(colorMap[result], errors.join('\n')), 3));
		}
	},

	afterTest: function() {
		var undefinedScenariosStr = this.undefinedScenarioCount ? colorize('[yellow]{' + this.undefinedScenarioCount + ' undefined}') : '';
		var undefinedStepsStr = this.undefinedStepCount ? colorize('[yellow]{' + this.undefinedStepCount + ' undefined}') : '';

		var passedScenariosStr = this.passedScenarioCount ? colorize('[green]{' + this.passedScenarioCount + ' passed}') : '';
		var passedStepsStr = this.passedStepCount ? colorize('[green]{' + this.passedStepCount + ' passed}') : '';

		var pendingScenariosStr = this.pendingScenarioCount ? colorize('[yellow]{' + this.pendingScenarioCount + ' pending}') : '';
		var pendingStepsStr = this.pendingStepCount ? colorize('[yellow]{' + this.pendingStepCount + ' pending}') : '';

		var skippedStepsStr = this.skippedStepCount ? colorize('[cyan]{' + this.skippedStepCount + ' skipped}') : '';

		var failedScenariosStr = this.failedScenarioCount ? colorize('[red]{' + this.failedScenarioCount + ' failed}') : '';
		var failedStepsStr = this.failedStepCount ? colorize('[red]{' + this.failedStepCount + ' failed}') : '';

		console.log(this.scenarioCount + ' scenarios (' + strJoin(passedScenariosStr, failedScenariosStr, undefinedScenariosStr, pendingScenariosStr) + ')');
		console.log(this.stepCount + ' steps (' + strJoin(passedStepsStr, failedStepsStr, skippedStepsStr, undefinedStepsStr, pendingStepsStr) + ')');

		var timeElapsed = (Date.now() - this.startTime)/1000;

		var minutes = Math.floor(timeElapsed / 60);
		var seconds = timeElapsed - minutes*60;

		console.log(minutes + 'm' + seconds.toFixed(3) + 's');
		console.log();

		if (_.keys(this.undefinedSteps).length) {
			console.log(colorize('[yellow]{You can implement step definitions for undefined steps with these snippets:\n}'));
			console.log(colorize('yellow', 'var Steps = require(\'cucumis\').Steps;\n'));

			for (var undefinedStep in this.undefinedSteps) {
				console.log(colorize('yellow', undefinedStep));
			}

			console.log(colorize('yellow', 'Steps.export(module);\n'));
		}
	},
};
