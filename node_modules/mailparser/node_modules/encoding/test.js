var testCase = require('nodeunit').testCase,
    encoding = require("./index");

exports["General tests"] = {
    "From UTF-8 to Latin_1": function(test){
        var input = "ÕÄÖÜ",
            expected = new Buffer([0xd5, 0xc4, 0xd6, 0xdc]);
        test.deepEqual(encoding.convert(input, "latin1"), expected);
        test.done();
    },
    "From Latin_1 to UTF-8": function(test){
        var input = new Buffer([0xd5, 0xc4, 0xd6, 0xdc]),
            expected = "ÕÄÖÜ";
        test.deepEqual(encoding.convert(input, "utf-8", "latin1").toString(), expected);
        test.done();
    },
    "From Latin_13 to Latin_15": function(test){
        var input = new Buffer([0xd5, 0xc4, 0xd6, 0xdc, 0xd0]),
            expected = new Buffer([0xd5, 0xc4, 0xd6, 0xdc, 0xA6]);
        test.deepEqual(encoding.convert(input, "latin_15", "latin13"), expected);
        test.done();
    },
    "From Latin_13 to Latin_15 lite": function(test){
        var input = new Buffer([0xd5, 0xc4, 0xd6, 0xdc, 0xd0]),
            expected = new Buffer([0xd5, 0xc4, 0xd6, 0xdc, 0xA6]);
        test.deepEqual(encoding.convert(input, "latin_15", "latin13", true), expected);
        test.done();
    }
}