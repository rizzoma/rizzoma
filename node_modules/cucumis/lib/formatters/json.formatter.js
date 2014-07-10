// Format printing object
var _ = require('underscore');

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

	this.results = {
		allErrors: [],
		features: [],
		stats: {
			undefinedSteps: [],
			scenarioCount: 0,
			stepCount: 0,
			undefinedStepCount: 0,
			undefinedScenarioCount: 0,
			passedStepCount: 0,
			passedScenarioCount: 0,
			pendingStepCount: 0,
			pendingScenarioCount: 0,
			failedStepCount: 0,
			failedScenarioCount: 0,
			elapsedTime: 0,
		},
	};
}

module.exports.Formatter.prototype = {

	lastFeature: function() {
		return this.results.features[this.results.features.length-1];
	},

	lastScenario: function() {
		var feature = this.lastFeature();
		return feature.scenarios[feature.scenarios.length-1];
	},

	background: function() {
		var feature = this.lastFeature();
		return feature.background;
	},

	lastStep: function() {
		var scenario = this.lastScenario();
		return scenario.steps[scenario.steps.length-1];
	},

	generalUncaughtException: function(err) {
		this.results.allErrors.push(err);
	},

	asyncStepTimeoutError: function(eventName, level, err) {
		if (err) {
			this.results.allErrors.push(err);
		}

		var step = this.lastStep();
		if (err) {
			step.err = err;
		} else {
			step.err = new Error('Timeout waiting for response on event: ' + eventName);
		}
	},

	beforeFeature: function(feature) {
		this.results.features.push({name: feature.name, description: feature.description, background: null, scenarios: []});
	},

	afterFeature: function(feature) {
	},

	beforeScenarioOutline: function(scenarioOutline) {
	},

	afterScenarioOutline: function(scenarioOutline) {
	},

	beforeScenario: function(scenario) {
		var feature = this.lastFeature();
		feature.scenarios.push({name: scenario.name, outline: scenario.outline, steps: []});
	},

	afterScenario: function(scenario) {
	},

	beforeBackground: function(scenario) {
		var feature = this.lastFeature();
		feature.background = {steps: []};
	},

	afterBackground: function(scenario) {
	},

	beforeStep: function(step) {
	},

	afterStep: function(step) {
	},

	afterSteps: function(scenario) {
	},

	afterStepResult: function(scenario, stepLine, result, msg, err) {
		if (err) {
			this.results.allErrors.push(err);
		}

		var _scenario;
		if (!scenario.background) {
			_scenario = this.lastScenario();
		}

		if (scenario.background && !scenario.backgroundPrinted) {
			_scenario = this.background();
		}

		if (_scenario) {
			_scenario.steps.push({
				line: stepLine,
				result: result,
				err: err,
				msg: msg,
			});
		}
	},

	afterTest: function() {
		for (var undefinedStep in this.undefinedSteps) {
			this.results.stats.undefinedSteps.push(undefinedStep);
		}
		this.results.stats.scenarioCount = this.scenarioCount;

		this.results.stats.stepCount = this.stepCount;

		this.results.stats.undefinedStepCount = this.undefinedStepCount;
		this.results.stats.undefinedScenarioCount = this.undefinedScenarioCount;

		this.results.stats.passedStepCount = this.passedStepCount;
		this.results.stats.passedScenarioCount = this.passedScenarioCount;

		this.results.stats.pendingStepCount = this.pendingStepCount;
		this.results.stats.pendingScenarioCount = this.pendingScenarioCount;

		this.results.stats.skippedStepCount = this.skippedStepCount;

		this.results.stats.failedStepCount = this.failedStepCount;
		this.results.stats.failedScenarioCount = this.failedScenarioCount;

		this.results.stats.elapsedTime = (Date.now() - this.startTime)/1000;

		console.log(JSON.stringify(this.results, null, '  '));
	},
};
