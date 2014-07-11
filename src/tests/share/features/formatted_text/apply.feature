Feature: Apply of text insert operation
	Text insert operation should be applied properly
	Scenario: text insert is applied for new doc
		Given server with []
		And client1
		When client1 submits [{"p": 0, "ti": "First", "params": {"bold": true}}]
		Then client1 should have [{"t": "First", "params": {"bold": true}}]

	Scenario: text insert is applied in block with same params
		Given server with [{"t": "abd", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 2, "ti": "c", "params": {"bold": true}}]
		Then client1 should have [{"t": "abcd", "params": {"bold": true}}]

	Scenario: text insert is applied in block with different params
		Given server with [{"t": "abd", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 2, "ti": "c", "params": {"italic": true}}]
		Then client1 should have [{"t": "ab", "params": {"bold": true}}, {"t": "c", "params": {"italic": true}}, {"t": "d", "params": {"bold": true}}]

	Scenario: text insert is applied before the block with same params
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 0, "ti": "x", "params": {"bold": true}}]
		Then client1 should have [{"t": "xabc", "params": {"bold": true}}]

	Scenario: text insert is applied before the block with different params
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 0, "ti": "x", "params": {"italic": true}}]
		Then client1 should have [{"t": "x", "params": {"italic": true}}, {"t": "abc", "params": {"bold": true}}]

	Scenario: text insert is applied after the block with same params
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 3, "ti": "d", "params": {"bold": true}}]
		Then client1 should have [{"t": "abcd", "params": {"bold": true}}]

	Scenario: text insert is applied after the block with different params
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 3, "ti": "d", "params": {"italic": true}}]
		Then client1 should have [{"t": "abc", "params": {"bold": true}}, {"t": "d", "params": {"italic": true}}]

	Scenario: text insert is applied between blocks, left is with same params
		Given server with [{"t": "abc", "params": {"bold": true}}, {"t": "efg", "params": {"italic": true}}]
		And client1
		When client1 submits [{"p": 3, "ti": "d", "params": {"bold": true}}]
		Then client1 should have [{"t": "abcd", "params": {"bold": true}}, {"t": "efg", "params": {"italic": true}}]

	Scenario: text insert is applied between blocks, right is with same params
		Given server with [{"t": "abc", "params": {"bold": true}}, {"t": "efg", "params": {"italic": true}}]
		And client1
		When client1 submits [{"p": 3, "ti": "d", "params": {"italic": true}}]
		Then client1 should have [{"t": "abc", "params": {"bold": true}}, {"t": "defg", "params": {"italic": true}}]

	Scenario: text insert is applied between blocks, both with different params
		Given server with [{"t": "abc", "params": {"bold": true}}, {"t": "efg", "params": {"italic": true}}]
		And client1
		When client1 submits [{"p": 3, "ti": "d", "params": {}}]
		Then client1 should have [{"t": "abc", "params": {"bold": true}}, {"t": "d", "params": {}}, {"t": "efg", "params": {"italic": true}}]

	Scenario: text delete is applied in block with same params
		Given server with [{"t": "abd", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 1, "td": "b", "params": {"bold": true}}]
		Then client1 should have [{"t": "ad", "params": {"bold": true}}]

	Scenario: text delete is applied at start of block with same params
		Given server with [{"t": "abd", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 0, "td": "a", "params": {"bold": true}}]
		Then client1 should have [{"t": "bd", "params": {"bold": true}}]

	Scenario: text delete is applied at end of block with same params
		Given server with [{"t": "abd", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 2, "td": "d", "params": {"bold": true}}]
		Then client1 should have [{"t": "ab", "params": {"bold": true}}]

	Scenario: text delete of whole block
		Given server with [{"t": "a", "params": {"bold": true}}, {"t": "b", "params": {}}]
		And client1
		When client1 submits [{"p": 1, "td": "b", "params": {}}]
		Then client1 should have [{"t": "a", "params": {"bold": true}}]
		
	Scenario: text delete is between two blocks with same params
		Given server with [{"t": "a", "params": {"bold": true}}, {"t": "b", "params": {}}, {"t": "c", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 1, "td": "b", "params": {}}]
		Then client1 should have [{"t": "ac", "params": {"bold": true}}]

	Scenario: params insert is applied on whole block
		Given server with [{"t": "abc", "params": {}}]
		And client1
		When client1 submits [{"p": 0, "len": 3, "paramsi": {"italic": true}}]
		Then client1 should have [{"t": "abc", "params": {"italic": true}}]

	Scenario: params delete is applied on whole block
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 0, "len": 3, "paramsd": {"bold": true}}]
		Then client1 should have [{"t": "abc", "params": {}}]

	Scenario: params insert is applied on whole block, it should merge with previous block
		Given server with [{"t": "a", "params": {"a": true}}, {"t": "b", "params": {}}, {"t": "c", "params": {"c": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsi": {"a": true}}]
		Then client1 should have [{"t": "ab", "params": {"a": true}}, {"t": "c", "params": {"c": true}}]
		
	Scenario: params delete is applied on whole block, it should merge with previous block
		Given server with [{"t": "a", "params": {}}, {"t": "b", "params": {"b": true}}, {"t": "c", "params": {"c": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsd": {"b": true}}]
		Then client1 should have [{"t": "ab", "params": {}}, {"t": "c", "params": {"c": true}}]

	Scenario: params insert is applied on whole block, it should merge with next block
		Given server with [{"t": "a", "params": {"a": true}}, {"t": "b", "params": {}}, {"t": "c", "params": {"c": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsi": {"c": true}}]
		Then client1 should have [{"t": "a", "params": {"a": true}}, {"t": "bc", "params": {"c": true}}]

	Scenario: params delete is applied on whole block, it should merge with next block
		Given server with [{"t": "a", "params": {"a": true}}, {"t": "b", "params": {"b": true}}, {"t": "c", "params": {}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsd": {"b": true}}]
		Then client1 should have [{"t": "a", "params": {"a": true}}, {"t": "bc", "params": {}}]

	Scenario: params insert is applied on whole block, it should merge with next and previous blocks
		Given server with [{"t": "a", "params": {"a": true}}, {"t": "b", "params": {}}, {"t": "c", "params": {"a": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsi": {"a": true}}]
		Then client1 should have [{"t": "abc", "params": {"a": true}}]

	Scenario: params delete  is applied on whole block, it should merge with next and previous blocks
		Given server with [{"t": "a", "params": {}}, {"t": "b", "params": {"b": true}}, {"t": "c", "params": {}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsd": {"b": true}}]
		Then client1 should have [{"t": "abc", "params": {}}]
		
	Scenario: params insert is applied on first part of block
		Given server with [{"t": "abc", "params": {}}]
		And client1
		When client1 submits [{"p": 0, "len": 2, "paramsi": {"italic": true}}]
		Then client1 should have [{"t": "ab", "params": {"italic": true}}, {"t": "c", "params": {}}]

	Scenario: params delete is applied on first part of block
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 0, "len": 2, "paramsd": {"bold": true}}]
		Then client1 should have [{"t": "ab", "params": {}}, {"t": "c", "params": {"bold": true}}]

	Scenario: params insert is applied on first part of block, it should merge with previous block
		Given server with [{"t": "a", "params": {"b": true}}, {"t": "bc", "params": {}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsi": {"b": true}}]
		Then client1 should have [{"t": "ab", "params": {"b": true}}, {"t": "c", "params": {}}]

	Scenario: params delete is applied on first part of block, it should merge with previous block
		Given server with [{"t": "a", "params": {"b": true}}, {"t": "bc", "params": {"b": true, "c": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsd": {"c": true}}]
		Then client1 should have [{"t": "ab", "params": {"b": true}}, {"t": "c", "params": {"b": true, "c": true}}]

	Scenario: params insert is applied on last part of block
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 2, "paramsi": {"italic": true}}]
		Then client1 should have [{"t": "a", "params": {"bold": true}}, {"t": "bc", "params": {"bold": true, "italic": true}}]

	Scenario: params delete is applied on last part of block
		Given server with [{"t": "abc", "params": {"bold": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 2, "paramsd": {"bold": true}}]
		Then client1 should have [{"t": "a", "params": {"bold": true}}, {"t": "bc", "params": {}}]

	Scenario: params insert is applied on last part of block, it should merge with next block
		Given server with [{"t": "ab", "params": {"b": true}}, {"t": "c", "params": {"b": true, "i": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsi": {"i": true}}]
		Then client1 should have [{"t": "a", "params": {"b": true}}, {"t": "bc", "params": {"b": true, "i": true}}]

	Scenario: params delete is applied on last part of block, it should merge with next block
		Given server with [{"t": "ab", "params": {"b": true, "i": true}}, {"t": "c", "params": {"b": true}}]
		And client1
		When client1 submits [{"p": 1, "len": 1, "paramsd": {"i": true}}]
		Then client1 should have [{"t": "a", "params": {"b": true, "i": true}}, {"t": "bc", "params": {"b": true}}]
