Feature: Transformations of params insert operation
	Params insert operations should be transformed properly
	Scenario: paramsi vs ti, ti before left border of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "q", "params": {}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "q", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 3, "len": 2, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "qab", "params": {}}, {"t": "cd", "params": {"bold": true}}, {"t": "efg", "params": {}}]

	Scenario: paramsi vs ti, ti at left border of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "ti": "q", "params": {}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "ti": "q", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 3, "len": 2, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "abq", "params": {}}, {"t": "cd", "params": {"bold": true}}, {"t": "efg", "params": {}}]

	Scenario: paramsi vs ti, ti inside of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 3, "ti": "q", "params": {}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 3, "ti": "q", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "len": 1, "paramsi": {"bold": true}}, {"p": 4, "len": 1, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "ab", "params": {}}, {"t": "c", "params": {"bold": true}}, {"t": "q", "params": {}}, {"t": "d", "params": {"bold": true}}, {"t": "efg", "params": {}}]

	Scenario: paramsi vs ti, ti inside of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 4, "ti": "q", "params": {}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 4, "ti": "q", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "len": 2, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "ab", "params": {}}, {"t": "cd", "params": {"bold": true}}, {"t": "qefg", "params": {}}]

	Scenario: paramsi vs td, td at left part of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 0, "td": "abc", "params": {}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "td": "abc", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "len": 2, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "de", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs td, td at right part of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "td": "cd", "params": {}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "td": "cd", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "len": 2, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "be", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs td, td is insert of paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "td": "c", "params": {}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "td": "c", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "len": 3, "paramsi": {"bold": true}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bde", "params": {"bold": true}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs td, td includes paramsi
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 0, "td": "abcdef", "params": {}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"bold": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "td": "abcdef", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [] to client1
		Then everyone should have [{"t": "g", "params": {}}]

	Scenario: paramsd vs td, td is earlier
		Given server with [{"t": "abcdefg", "params": {"b": true}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "td": "c", "params": {"b": true}}]
		And client2 submits [{"p": 3, "len": 4, "paramsd": {"b": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "td": "c", "params": {"b": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "len": 4, "paramsd": {"b": true}}] to client1
		Then everyone should have [{"t": "ab", "params": {"b": true}}, {"t": "defg", "params": {}}]

	Scenario: paramsi vs paramsi, params are different
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": true}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"b": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "len": 4, "paramsi": {"b": true}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bcde", "params": {"i": true, "b": true}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs paramsi, params are same
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": true}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"i": true}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [] to client1
		Then everyone should have [{"t": "a", "params": {}}, {"t": "bcde", "params": {"i": true}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs paramsi, left overlap, different value
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": 1}}]
		And client2 submits [{"p": 3, "len": 4, "paramsi": {"i": 2}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": 1}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 3, "len": 2, "paramsd": {"i": 1}}, {"p": 3, "len": 2, "paramsi": {"i": 2}}, {"p": 5, "len": 2, "paramsi": {"i": 2}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bc", "params": {"i": 1}}, {"t": "defg", "params": {"i": 2}}]

	Scenario: paramsi vs paramsi, right overlap, different value
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 3, "len": 4, "paramsi": {"i": 2}}]
		And client2 submits [{"p": 1, "len": 4, "paramsi": {"i": 1}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 3, "len": 4, "paramsi": {"i": 2}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "len": 2, "paramsi": {"i": 1}}, {"p": 3, "len": 2, "paramsd": {"i": 2}}, {"p": 3, "len": 2, "paramsi": {"i": 1}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bcde", "params": {"i": 1}}, {"t": "fg", "params": {"i": 2}}]

	Scenario: paramsi vs paramsi, first includes second, same value
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": 1}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"i": 1}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": 1}}] to client2
		When server receives operation 1 from client2
		Then server should send [] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "bcde", "params": {"i": 1}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs paramsi, first includes second, different value
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": 1}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"i": 2}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": 1}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "len": 2, "paramsd": {"i": 1}}, {"p": 2, "len": 2, "paramsi": {"i": 2}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "b", "params": {"i": 1}}, {"t": "cd", "params": {"i": 2}}, {"t": "e", "params": {"i": 1}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs paramsi, first includes second, different value
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": 1}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"i": 2}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": 1}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "len": 2, "paramsd": {"i": 1}}, {"p": 2, "len": 2, "paramsi": {"i": 2}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "b", "params": {"i": 1}}, {"t": "cd", "params": {"i": 2}}, {"t": "e", "params": {"i": 1}}, {"t": "fg", "params": {}}]

	Scenario: paramsi vs paramsi, first includes second, different value
		Given server with [{"t": "abcdefg", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "len": 4, "paramsi": {"i": 1}}]
		And client2 submits [{"p": 2, "len": 2, "paramsi": {"i": 2}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "len": 4, "paramsi": {"i": 1}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 2, "len": 2, "paramsd": {"i": 1}}, {"p": 2, "len": 2, "paramsi": {"i": 2}}] to client1
		And everyone should have [{"t": "a", "params": {}}, {"t": "b", "params": {"i": 1}}, {"t": "cd", "params": {"i": 2}}, {"t": "e", "params": {"i": 1}}, {"t": "fg", "params": {}}]

	Scenario: paramsd vs paramsd, first is included in second
		Given server with [{"t": "abcdefg", "params": {"i": 1}}]
		And client1
		And client2
		When client1 submits [{"p": 2, "len": 2, "paramsd": {"i": 1}}]
		And client2 submits [{"p": 1, "len": 4, "paramsd": {"i": 1}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 2, "len": 2, "paramsd": {"i": 1}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "len": 1, "paramsd": {"i": 1}}, {"p": 4, "len": 1, "paramsd": {"i": 1}}] to client1
		And everyone should have [{"t": "a", "params": {"i": 1}}, {"t": "bcde", "params": {}}, {"t": "fg", "params": {"i": 1}}]
