Feature: Volna sharejs type
	Volna sharejs type should transform and apply operations correctly
	Scenario: text insert is applied for new doc
		Given server with {"content": []}
		And client1
		When client1 submits [{"p": 0, "ti": "First", "params": {}}]
		Then client1 should have {"content": [{"t": "First", "params": {}}]}

	Scenario: json object insert is applied for new doc
		Given server with {"content": []}
		And client1
		When client1 submits [{"p": ["t"], "oi": "First"}]
		Then client1 should have {"content": [], "t": "First"}

	Scenario: json object insert and text insert are applied for new doc
		Given server with {"content": []}
		And client1
		And client2
		When client1 submits [{"p": ["t"], "oi": "First"}]
		And client2 submits [{"p": 0, "ti": "Second", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": ["t"], "oi": "First"}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "ti": "Second", "params": {}}] to client1
		And everyone should have {"content": [{"t": "Second", "params": {}}], "t": "First"}

	Scenario: two text insert operations
		Given server with {"content": []}
		And client1
		And client2
		When client1 submits [{"p": 0, "ti": "First", "params": {}}]
		And client2 submits [{"p": 0, "ti": "Second", "params": {}}]
		And server receives operation 1 from client1
		Then server should send [{"p": 0, "ti": "First", "params": {}}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": 0, "ti": "Second", "params": {}}] to client1
		And everyone should have {"content": [{"t": "SecondFirst", "params": {}}]}

	Scenario: two json list insert  insert and text insert are applied for new doc
		Given server with {"content": [], "users": []}
		And client1
		And client2
		When client1 submits [{"p": ["users", 0], "li": 1}]
		And client2 submits [{"p": ["users", 0], "li": 2}]
		And server receives operation 1 from client1
		Then server should send [{"p": ["users", 0], "li": 1}] to client2
		When server receives operation 1 from client2
		Then server should send [{"p": ["users", 0], "li": 2}] to client1
		And everyone should have {"content": [], "users": [2, 1]}
