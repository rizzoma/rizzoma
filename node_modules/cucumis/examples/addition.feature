Feature: Addition
	In order to avoid silly mistakes
	As a math idiot
	I want to be able to add up numbers

	Background:
		Given I have a calculator

	Scenario: Add two numbers
		Given I have entered 50 into the calculator
		And I have entered 70 into the calculator
		When I press add
		Then the result should be 120 on the screen

	Scenario: Add three numbers
		Given I have entered 1 into the calculator
		And I have entered 2 into the calculator
		And I have entered 3 into the calculator

		When I press add
		Then the result should be 5 on the screen

		When I press add
		Then the result should be 6 on the screen

	Scenario: Return a single number
		Given I have entered 42 into the calculator
		Then the result should be 42 on the screen

	Scenario Outline: Add some numbers
		Given I have entered <num1> into the calculator
		And I have entered <num2> into the calculator
		When I press add
		Then the result should be <result> on the screen

		Examples:
			| num1 	| num2 	| result 	|
			| 1		| 2		| 3			|
			| 2		| 3		| 5			|
