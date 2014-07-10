Feature: Run basic features
	As a cucumis user
	I want to run a simple feature
	So that I can reduce defects in my code

	Scenario: Run basic feature
		When I run cucumis against the file "examples/addition.feature"
		Then there should be no executable errors
		And the "Total Errors" should be 0
		And the "Number of Features" should be 1

		And the "Scenario Count" should be 5
		And the "Passed Scenario Count" should be 5
		And the "Failed Scenario Count" should be 0
		And the "Pending Scenario Count" should be 0
		And the "Undefined Scenario Count" should be 0

		And the "Step Count" should be 26
		And the "Passed Step Count" should be 26
		And the "Failed Step Count" should be 0
		And the "Skipped Step Count" should be 0
		And the "Pending Step Count" should be 0
		And the "Undefined Step Count" should be 0

		And the "Elapsed Time" should be greater than 0

		When I select the Feature "Addition"
		Then the feature's "name" should be "Addition"
		And the feature's "description" should be "In order to avoid silly mistakes\nAs a math idiot\nI want to be able to add up numbers\n"
		Then the feature should have a background
		And the feature should have 5 scenarios

		When I select the Scenario "Add three numbers"
		Then the scenario should have 7 steps

		When I select the Step "Then the result should be 5 on the screen"
		Then the step's "result" should be "pass"
