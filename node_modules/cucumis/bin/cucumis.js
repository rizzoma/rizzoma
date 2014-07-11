#!/usr/bin/env node

var cucumis = require('../lib/cucumis'),
    path = require('path'),
	should = require('should'),
    fs = require('fs'),
	_ = require('underscore'),
	globSync = require('glob').sync,
	colorizelib = require('../lib/support/colorize'),
	colorize = colorizelib.colorize,
	indent = require('../lib/support/indent');

// test timeout
var timeout = 5000;

// Prefer mustache style templates
_.templateSettings = {
  interpolate : /\{\{(.+?)\}\}/g
};

// template for undefined steps
var undefinedStepTemplate = _.template(fs.readFileSync(path.join(__dirname, '../lib/templates/stepdef.js.tpl')).toString());

// escapes regexs
RegExp.escape = function(str)
{
  var specials = new RegExp("[.*+?|()\\[\\]{}\\\\]", "g"); // .*+?|()[]{}\
  return str.replace(specials, "\\$&");
}

function processCmdLine() {
	var usage = colorize(''
		+ '[bold]{Usage}: cucumis [options] [path]\n'
		+ '\n'
		+ '[bold]{Exmample}\n'
		+ 'cucumis examples/features\n'
		+ '\n'
		+ '[bold]{Options}:\n'
		+ '  -h, --help             Output help information\n'
	    + '  -f, --format FORMAT    How to format features (Default: pretty). Available formats:\n'
		+ '                           pretty      : Prints the feature as is - in colours\n'
		+ '                           json        : Prints the feature as JSON\n'
        + '  -b, --boring           Suppress ansi-escape colors\n'
		+ '  -t, --timeout MS       Async step timeout in milliseconds, defaults to 5000\n'
	);

	// Parse arguments
	var args = process.argv.slice(2)
	           , path = null;

	while (args.length) {
		var arg = args.shift();
		switch (arg) {
			case '-h':
			case '--help':
				abort(usage);
				break;

			case '-t':
			case '--timeout':
				timeout = parseInt(args.shift());
				break;

			case '-b':
			case '--boring':
				colorizelib.boring = true;
				break;

			case '-f':
			case '--format':
				format = args.shift();
				break;

			default:
				path = arg;
		}
	}

	return path;
}

var format = 'pretty';
var runPath = processCmdLine();

var Formatter = require('../lib/formatters/' + format + '.formatter').Formatter;
var formatter = new Formatter();

// uncaught expception handling
var _stepError = {
	id: 0,
	handler: function(id, err) {
		throw err;
	},
};

process.on('uncaughtException', function (err) {
	if (_stepError.id) {
		_stepError.handler(_stepError.id, err);
	} else if (formatter) {
		formatter.generalUncaughtException(err);
	} else {
		console.error(str);
		process.exit(1);
	}
});

if (runPath === null) {
	runPath = 'features';
}

var runPattern = '\.feature$';

var stat = fs.statSync(path.resolve(process.cwd(), runPath));
if (stat.isFile()) {
	var filePath = path.resolve(process.cwd(), runPath);
	runPattern = RegExp.escape('^' + filePath + '$');
	runPath = path.dirname(filePath);
}

// Load up env.js
globSync(path.resolve(process.cwd(), runPath, '**/env.js')).forEach(function (env) {
	require(env);
});

// Load up step definitions
var stepDefs = [];
try {
	globSync(path.resolve(process.cwd(), runPath, '**/*.js'))
		.filter(function(value) {
			return !value.match(/\/env.js$/);
		})
		.forEach(function(file) {
			var mod = require(file);
			if (mod instanceof Array) {
				var newDefs = mod.filter(function (item) {
					return (item.operator) && (item.pattern instanceof RegExp) && (item.generator instanceof Function);
				});
				stepDefs = stepDefs.concat(newDefs);
			}
		});
} catch (err) {}

runFeatures(runPath, runPattern);

function runFeatures(runPath, runPattern) {
	var paths = [path.resolve(process.cwd(), runPath), path.resolve(process.cwd(), runPath, 'features')];
	var p;

	var features = [];
	var reRunPattern = new RegExp(runPattern);

	while (p = paths.shift()) {

		try {
			var files = fs.readdirSync(p); 
			// find features
			files
				.filter(function(f) { return path.join(p, f).match(reRunPattern) })
				.filter(function(f) { return fs.statSync(path.join(p, f)).isFile() })
				.forEach(function(f) { features.push(path.join(p, f)) });

			// find more directories to traverse
			files
				.filter(function(f) { return fs.statSync(path.join(p, f)).isDirectory() })
				.forEach(function(f) { paths.push(path.join(p, f)) });
		} catch (err) {
			// ignore files that don't exist
		}
	}

	features = _(features).uniq();

	notifyListeners('beforeTest', function() {
		(function next(){
			if (features.length) {
				runFeature(features.shift(), next);
			} else {
				notifyListeners('afterTest', function() {
					formatter.afterTest();
				});
			}
		})();
	});
}

function notifyListeners(eventName, cb, level) {
	level = level || 1;
	var listeners = _.clone(cucumis.Steps.Runner.listeners(eventName));
	(function next() {
		if (listeners.length) {
			var listener = listeners.shift();

			var responseOk = true;

			var id = setTimeout(function() {
				responseOk = false;
				formatter.asyncStepTimeoutError(eventName, level);
				next();
			}, 100);

			_stepError.id = id;
			_stepError.handler = function(id, err) {
				responseOk = false;
				clearTimeout(id);
				formatter.asyncStepTimeoutError(eventName, level, err);

				next();
			};

			listener(function() {
				if (responseOk) {
					clearTimeout(id);
					next();
				}
			});
		} else {
			cb();
		}
	})();
}

function runFeature(featureFile, cb) {
	var data = fs.readFileSync(featureFile);
	var ast = cucumis.parse(data.toString());

	// Feature
	for (var index in ast) {

		if (ast[index]) {
			// Extract background
			var background = function(cb) {
				cb();
			};

			var _background = background;

			if (ast[index].background) {
				ast[index].background.background = true;
				background = function(cb) {
					formatter.beforeBackground(ast[index].background);
					notifyListeners('beforeBackground', function() {
						runScenario(_background, ast[index].background, function () {
							ast[index].background.backgroundPrinted = true;
							formatter.afterBackground(ast[index].background);
							notifyListeners('afterBackground', cb);
						});
					});
				}
			}

			var feature = ast[index];

			formatter.beforeFeature(feature);

			notifyListeners('beforeFeature', function() {
				if (feature.scenarios && feature.scenarios.length) {
					// Scenarios
					var scenarios = feature.scenarios;

					(function next(){
							if (scenarios.length) {
								runScenario(background, scenarios.shift(), next);
							} else {
								notifyListeners('afterFeature', function() {
									formatter.afterFeature(feature);
									cb();
								});
							}
					})();
				}
			});
		}
	}
}

function runScenario(background, scenario, cb) {
	var testState = {
		scenarioState: 'passed',
		scenarioUndefined: false,
		lastStepType: 'GIVEN',
		skip: false,
	};

	if (scenario.outline && !scenario.background) {
		formatter.beforeScenarioOutline(scenario);
	}

	if (scenario.breakdown && scenario.breakdown.length) {
		testState.lastStepType = 'GIVEN';

		var exampleSets = [{}];

		// Parse examples data
		if (scenario.hasExamples) {
			var examples = scenario.examples;
			for (var exampleVar in examples) {
				examples[exampleVar].forEach(function(exampleValue, index) {
					if (!exampleSets[index]) {
						exampleSets[index] = {};
					} 

					exampleSets[index][exampleVar] = exampleValue;
				});
			}
		}

		// Examples
		(function next(){
			testState.skip = false;

			if (exampleSets.length) {
				background(function() {
					if (!scenario.background) {
						formatter.beforeScenario(scenario);
						notifyListeners('beforeScenario', function() {
							runExampleSet(scenario, exampleSets.shift(), testState, next);
						});
					} else {
						runExampleSet(scenario, exampleSets.shift(), testState, next);
					}
				});
			} else {
				if (testState.scenarioUndefined) {
					formatter.undefinedScenarioCount++;
				}

				if (!scenario.background) {
					formatter.afterScenario(scenario);
					notifyListeners('afterScenario', cb);
				} else {
					cb();
				}
			}
		})();
	}
}

function runExampleSet(scenario, exampleSet, testState, cb) {
	testState.scenarioState = 'passed';

	if (!scenario.background) {
		formatter.scenarioCount++;
	}

	// Steps
	var steps = [];
	scenario.breakdown.forEach(function(breakdown) {
		// Step
		for (var i in breakdown) {
			var step = breakdown[i];
			steps.push(step);
		}
	});

	(function next(){
		if (steps.length) {
			var step = steps.shift();
			formatter.beforeStep(step);

			notifyListeners('beforeStep', function() {
				runStep(scenario, step, exampleSet, testState, function() {
					formatter.stepCount++;
					notifyListeners('afterStep', function() {
						formatter.afterStep(step);
						next();
					});
				});
			});
		} else {
			if (!scenario.background) {
				switch (testState.scenarioState) {
					case 'failed':
						formatter.failedScenarioCount++;
						break;

					case 'pending':
						formatter.pendingScenarioCount++;
						break;

					case 'passed':
						formatter.passedScenarioCount++;
						break;
						
				}
			}

			notifyListeners('afterSteps', function() {
				formatter.afterSteps(scenario);
				cb();
			});
		}
	})();
}

function runStep(scenario, step, exampleSet, testState, cb) {
	var stepType = step[0];
	if (step[0] == 'AND' || step[0] == 'BUT') {
		stepType = testState.lastStepType;
	}
	testState.lastStepType = stepType;

	function capitalize(str) {
		return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
	}

	stepType = capitalize(stepType);

	var stepText = step[1];
	for (var exampleVar in exampleSet) {
		stepText = stepText.replace(new RegExp('<' + exampleVar + '>', 'g'), exampleSet[exampleVar]);
	}

	var stepLine = capitalize(step[0]) + ' ' + stepText;

	testState.foundStepDef = false;
	testState.result = 'pass';
	testState.msg = '';
	testState.err = null;

	var myStepDefs = _.clone(stepDefs);

	// Match step definitions against current step
	(function next(){
		if (myStepDefs.length) {
			runStepDef(myStepDefs.shift(), stepType, stepText, testState, next);
		} else {
			if (!testState.foundStepDef) { // Undefined step
				formatter.undefinedStepCount++;
				testState.scenarioUndefined = true;

				testState.result = 'undefined';
				testState.skip = true;

				// smart parametrization of numbers and strings
				var re = RegExp.escape(stepText).replace(/\//g, '\\/');
				var args = [];

				re = re.replace(/(\s|^)(\d+)(\s|$)/, function(str, m1, m2, m3) {
					args.push('arg' + (args.length + 1));
					return m1 + '(\\d+)' + m3;
				});

				re = re.replace(/("[^"]*?")/g, function(str, m1) {
					args.push('arg' + (args.length + 1));
					return '"([^"]*?)"';
				});

				var snippet = undefinedStepTemplate({type: stepType, title: re, args: [''].concat(args).join(', ')});
				formatter.undefinedSteps[snippet] = true;
			}

			formatter.afterStepResult(scenario, stepLine, testState.result, testState.msg, testState.err);

			cb();
		}
	})();
}

function runStepDef(stepDef, stepType, stepText, testState, cb) {
	var matches;
	if (!testState.foundStepDef && stepDef.operator.toUpperCase() == stepType.toUpperCase()) {
		if (matches = stepDef.pattern.exec(stepText)) {
			testState.foundStepDef = true;

			if (!testState.skip) {
				// Run step
				var id;
				var runTest = true;
				try {

					id = setTimeout(function(){
						runTest = false;
						stepError(id, new Error('Test timed out (' + timeout + 'ms)'));
					}, timeout);

					_stepError.handler = stepError;
					_stepError.id = id;

					var ctx = {
						done: function() {
							if (runTest) {
								clearTimeout(id);
								testState.result = 'pass';
								formatter.passedStepCount ++;

								cb();
							}
						},

						pending: function() {
							if (runTest) {
								clearTimeout(id);
								testState.result = 'pending';
								formatter.pendingStepCount ++;

								testState.msg = 'TODO: Pending';
								testState.skip = true;

								testState.scenarioState = 'pending';

								cb();
							}
						},
					};

					stepDef.generator.apply({}, [ctx].concat(matches.slice(1)));
				} catch (err) {
					stepError(id, err);
				}
			} else {
				testState.result = 'skipped';
				formatter.skippedStepCount ++;
				cb();
			}

			return;
		}
	}

	function stepError(id, err) {
		clearTimeout(id);

		testState.err = err;

		testState.result = 'fail';
		formatter.failedStepCount ++;
		testState.scenarioState = 'failed';
		testState.skip = true;

		cb();
	}

	cb();
}

/**
 * Exit with the given `str`.
 *
 * @param {String} str
 */

function abort(str) {
  console.error(str);
  process.exit(1);
}

