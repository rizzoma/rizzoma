Feature: Transformations of text delete operation
	Text delete operations should be transformed properly
	Scenario: td vs td, different places
		Given server with [{"t": "First", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 0, "td": "F", "params": {}}]
		And client2 submits [{"p": 4, "td": "t", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "td": "F", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 3, "td": "t", "params": {}}] to client1
		And everyone should have [{"t": "irs", "params": {}}]

	Scenario: td vs td, partially overlap from start
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "td": "bc", "params": {}}]
		And client2 submits [{"p": 2, "td": "cd", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "td": "bc", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "td": "d", "params": {}}] to client1
		And everyone should have [{"t": "aefg", "params": {}}]

	Scenario: td vs td, partially overlap from end
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "td": "cd", "params": {}}]
		And client2 submits [{"p": 1, "td": "bc", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "td": "cd", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "td": "b", "params": {}}] to client1
		And everyone should have [{"t": "aefg", "params": {}}]

	Scenario: td vs td, includes
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "td": "c", "params": {}}]
		And client2 submits [{"p": 1, "td": "bcd", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "td": "c", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "td": "bd", "params": {}}] to client1
		Then everyone should have [{"t": "aefg", "params": {}}]

	Scenario: td vs td, included
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "td": "bcd", "params": {}}]
		And client2 submits [{"p": 2, "td": "c", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "td": "bcd", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [] to client1
		And everyone should have [{"t": "aefg", "params": {}}]

	Scenario: td vs td, same operation
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "td": "bcd", "params": {}}]
		And client2 submits [{"p": 1, "td": "bcd", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "td": "bcd", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [] to client1
		And everyone should have [{"t": "aefg", "params": {}}]

	Scenario: td vs ti, delete is later
		Given server with [{"t": "abcfg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 3, "ti": "de", "params": {}}]
		And client2 submits [{"p": 3, "td": "f", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 3, "ti": "de", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 5, "td": "f", "params": {}}] to client1
		Then everyone should have [{"t": "abcdeg", "params": {}}]

	Scenario: td vs ti, delete is earlier
		Given server with [{"t": "abcfg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 3, "ti": "de", "params": {}}]
		And client2 submits [{"p": 1, "td": "b", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 3, "ti": "de", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "td": "b", "params": {}}] to client1
		And everyone should have [{"t": "acdefg", "params": {}}]		

	Scenario: td vs paramsi, td at left part of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And client2 submits [{"p": 0, "td": "abc", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "td": "a", "params": {}}, {"p": 0, "td": "bc", "params": {"bold": true}}] to client1
		And everyone should have [{"t": "de", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: td vs paramsi, td at start of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And client2 submits [{"p": 1, "td": "bc", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "td": "bc", "params": {"bold": true}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "de", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: td vs paramsi, td at right part of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And client2 submits [{"p": 3, "td": "def", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 3, "td": "de", "params": {"bold": true}}, {"p": 3, "td": "f", "params": {}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bc", "params": {"bold": true}}, {"t": "g", "params": {}}]

	Scenario: td vs paramsi, td at end of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And client2 submits [{"p": 3, "td": "de", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 3, "td": "de", "params": {"bold": true}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bc", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: td vs paramsi, td is inside of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And client2 submits [{"p": 2, "td": "cd", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "td": "cd", "params": {"bold": true}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "be", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: td vs paramsi, td includes paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And client2 submits [{"p": 0, "td": "abcdef", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "td": "a", "params": {}}, {"p": 0, "td": "bcde", "params": {"bold": true}}, {"p": 0, "td": "f", "params": {}}] to client1
		And everyone should have [{"t": "g", "params": {}}]
