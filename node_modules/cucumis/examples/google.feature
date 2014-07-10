Feature: Search Google
	As a web searcher
	I want to search google
	So that I can find information about stuff

	Background:
		Given I am using the "safari" browser

	Scenario: Search for basic keyword
		Given I am on the "Google" "Home" page

		When I enter "Hello World" into the "Search Query" text field
		And I click the "Google" "Search" button

		Then my title should contain "Hello World"
		But my title shouldn't contain "Pygmies"
