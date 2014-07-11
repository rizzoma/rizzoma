Feature: Transformations of text insert operation
	Text insert operations should be transformed properly
	Scenario: ti vs ti at new doc, different params
		Given server with []
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "First", "params": {"bold": true}}]
		And client2 submits [{"p": 0, "ti": "Second", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "First", "params": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "ti": "Second", "params": {}}] to client1
		And everyone should have [{"t": "Second", "params": {}}, {"t": "First", "params": {"bold": true}}]

	Scenario: ti vs ti, second op has shiftLeft
		Given server with []
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "First", "params": {"bold": true}}]
		And client2 submits [{"p": 0, "ti": "Second", "params": {}, "shiftLeft": true}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "First", "params": {"bold": true}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "ti": "Second", "params": {}, "shiftLeft": true}] to client1
		And everyone should have [{"t": "Second", "params": {}}, {"t": "First", "params": {"bold": true}}]

	Scenario: ti vs ti, first op has shiftLeft
		Given server with []
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "First", "params": {"bold": true}, "shiftLeft": true}]
		And client2 submits [{"p": 0, "ti": "Second", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "First", "params": {"bold": true}, "shiftLeft": true}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 5, "ti": "Second", "params": {}}] to client1
		And everyone should have [{"t": "First", "params": {"bold": true}}, {"t": "Second", "params": {}}]

	Scenario: ti vs ti at new doc, same params
		Given server with []
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "First", "params": {}}]
		And client2 submits [{"p": 0, "ti": "Second", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "First", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "ti": "Second", "params": {}}] to client1
		And everyone should have [{"t": "SecondFirst", "params": {}}]

	Scenario: ti vs ti, different places
		Given server with [{"t": "irs", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "F", "params": {}}]
		And client2 submits [{"p": 3, "ti": "t", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "F", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 4, "ti": "t", "params": {}}] to client1
		And everyone should have [{"t": "First", "params": {}}]

	Scenario: ti vs td, different places
		Given server with [{"t": "First", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 0, "td": "F", "params": {}}]
		And client2 submits [{"p": 2, "ti": "qqq", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "td": "F", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "ti": "qqq", "params": {}}] to client1
		And everyone should have [{"t": "iqqqrst", "params": {}}]

	Scenario: ti vs td, insert is inside of delete
		Given server with [{"t": "First", "params": {}}]
		And client1
		And client2
		When client1 submits [{"p": 1, "td": "irs", "params": {}}]
		And client2 submits [{"p": 3, "ti": "ron", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 1, "td": "irs", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 1, "ti": "ron", "params": {}}] to client1
		And everyone should have [{"t": "Front", "params": {}}]
