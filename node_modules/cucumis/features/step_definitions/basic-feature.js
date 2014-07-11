var Steps = require('cucumis').Steps,
    spawn = require('child_process').spawn,
	_ = require('underscore');

function runCucumis(file, cb) {
	var ret = {
		returnCode: 0,
		stdOut: '',
		stdErr: '',
	};

	var ls = spawn('cucumis', ['-f', 'json', file]);

	ls.stdout.on('data', function (data) {
		ret.stdOut = data;
	});

	ls.stderr.on('data', function (data) {
		ret.stdErr = data;
	});

	ls.on('exit', function (code) {
		ret.returnCode = code;
		cb(ret);
	});
}

var executableResults;
var testResults;
var currentFeature;
var currentScenario;
var currentStep;

var testMap = {
	'Total Errors': function() {
		return testResults.allErrors.length;
	},
	'Number of Features': function() {
		return testResults.features.length;
	},
	'Scenario Count': function() {
		return testResults.stats.scenarioCount;
	},
	'Passed Scenario Count': function() {
		return testResults.stats.passedScenarioCount;
	},
	'Failed Scenario Count': function() {
		return testResults.stats.failedScenarioCount;
	},
	'Undefined Scenario Count': function() {
		return testResults.stats.undefinedScenarioCount;
	},
	'Pending Scenario Count': function() {
		return testResults.stats.pendingScenarioCount;
	},
	'Step Count': function() {
		return testResults.stats.stepCount;
	},
	'Passed Step Count': function() {
		return testResults.stats.passedStepCount;
	},
	'Failed Step Count': function() {
		return testResults.stats.failedStepCount;
	},
	'Skipped Step Count': function() {
		return testResults.stats.skippedStepCount;
	},
	'Pending Step Count': function() {
		return testResults.stats.pendingStepCount;
	},
	'Undefined Step Count': function() {
		return testResults.stats.undefinedStepCount;
	},
	'Elapsed Time': function() {
		return testResults.stats.elapsedTime;
	},
};

var featureMap = {
	'a background': function() {
		return currentFeature.background;
	},
	'scenarios': function() {
		return currentFeature.scenarios;
	},
	'name': function() {
		return currentFeature.name;
	},
	'description': function() {
		return currentFeature.description;
	},
};

var scenarioMap = {
	'steps': function() {
		return currentScenario.steps;
	},
};

var stepMap = {
	'result': function() {
		return currentStep.result;
	},
};

var opMap = {
	'greater than': function() {
		return Object.prototype.should.above;
	},
	'less than': function() {
		return Object.prototype.should.below;
	},
	'equal to': function() {
		return Object.prototype.should.eql;
	},
};

Steps.When(/^I run cucumis against the file "([^"]*?)"$/, function (ctx, file) {
	runCucumis(file, function(results) {
		executableResults = results;
		testResults = JSON.parse(executableResults.stdOut);
		ctx.done();
	});
});

Steps.Then(/^the "([^"]*?)" should be (\d+)$/, function (ctx, attr, value) {
	testMap[attr]().should.eql(parseInt(value));
	ctx.done();
});

Steps.Then(/^the "([^"]*?)" should be (greater than|less than|equal to) (\d+)$/, function (ctx, attr, op, value) {
	var fn = opMap[op]();
	var subject = testMap[attr]().should;
	fn.call(subject, parseInt(value));
	ctx.done();
});

Steps.Then(/^there should be no executable errors$/, function (ctx) {
	executableResults.returnCode.should.eql(0);
	executableResults.stdErr.should.eql('');
	ctx.done();
});

Steps.When(/^I select the Feature "([^"]*?)"$/, function (ctx, name) {
	var feature = testResults.features
	                .filter(function(feature) {
						return feature.name == name;
	                });	

	feature.length.should.eql(1);

	currentFeature = feature[0];

	ctx.done();
});

Steps.Then(/^the feature should have (\d+) (.*)$/, function (ctx, count, attr) {
	featureMap[attr]().length.should.eql(parseInt(count));

	ctx.done();
});

Steps.Then(/^the feature should have (.*)$/, function (ctx, attr) {
	featureMap[attr]().should.be.ok;

	ctx.done();
});

Steps.Then(/^the feature's "([^"]*?)" should be "([^"]*?)"$/, function (ctx, attr, value) {
	featureMap[attr]().should.eql(_(value).isString() ? value.replace(/\\n/g, '\n') : value);
	ctx.done();
});

Steps.When(/^I select the Scenario "([^"]*?)"$/, function (ctx, name) {
	var scenario = currentFeature.scenarios
	                .filter(function(scenario) {
						return scenario.name == name;
	                });	

	scenario.length.should.eql(1);

	currentScenario = scenario[0];

	ctx.done();
});

Steps.Then(/^the scenario should have (\d+) (.*)$/, function (ctx, count, attr) {
	scenarioMap[attr]().length.should.eql(parseInt(count));

	ctx.done();
});

Steps.When(/^I select the Step "([^"]*?)"$/, function (ctx, name) {
	var step = currentScenario.steps
	                .filter(function(step) {
						return step.line == name;
	                });	

	step.length.should.eql(1);

	currentStep = step[0];

	ctx.done();
});


Steps.Then(/^the step's "([^"]*?)" should be "([^"]*?)"$/, function (ctx, attr, value) {
	stepMap[attr]().should.eql(value);
	ctx.done();
});

Steps.export(module);
