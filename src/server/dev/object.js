/**
 * Module dependencies
 */

var nodeunit = require('nodeunit'),
    fs = require('fs'),
    path = require('path');
    utils = require('nodeunit').utils;
    AssertionError = require('assert').AssertionError;

/**
 * Reporter info string
 */

exports.info = "Django tests reporter";

exports.run = function (files) {

    var start = new Date().getTime();
    var paths = files.map(function (p) {
        return path.join(process.cwd(), p);
    });

    files=[];
    
    var filetest = {
        filename: "",
        tests: [],
        testsresult : []
    };    

    nodeunit.runFiles(paths, {             
        moduleStart: function (name) {
            filetest = {
                filename: name,
                tests : [],
                testsresult : []                        
            }
        },
        testDone: function (name, assertions) {
            
            if (!assertions.failures()) {                                                
                filetest.tests.push(''+name);
                filetest.testsresult.push('OK');
            }
            else {                                
                filetest.tests.push(''+name);
                assertions.forEach(function (a) {
                    if (a.failed()) {
                        a = utils.betterErrors(a);
                        if (a.error instanceof AssertionError && a.message) {                           
                                b = {
                                    messadge: a.message,
                                    stack: a.error.stack
                                }                                                           
                        } else {
                            b = {
                                messadge: "",
                                stack: a.error.stack
                            }
                        }
                        
                        filetest.testsresult.push(b);                        
                    }
                });
            }      
        },        
        moduleDone: function (name, assertions) {
            files.push(filetest);
        },    
        done: function (assertions, end) {
            console.log(files);  
        },
        testStart: function(name) {

        }        
    });
};
