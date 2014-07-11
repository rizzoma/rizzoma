
nodeunit = require 'nodeunit',
fs = require('fs'),
path = require('path');
utils = require('nodeunit').utils;
AssertionError = require('assert').AssertionError;

class TestRunner
    _info = "Object for Django tests reporter";
    
    _run = (files) ->
        start = new Date().getTime();
        paths = files.map( (p) ->
            return path.join(process.cwd(), p);
        );
    
        files=[];    
        filetest = {
            filename: "",
            tests: [],
            testsresult : []
        };    
    
        nodeunit.runFiles paths, {             
            moduleStart: (name) ->
                filetest = 
                    filename: name
                    tests: []
                    testsresult: []
                    
            testDone: (name, assertions) ->            
                if (!assertions.failures())                                                
                    filetest.tests.push(''+name);
                    filetest.testsresult.push('OK');            
                else                                
                    filetest.tests.push(''+name);
                    assertions.forEach( (a) ->
                        if (a.failed()) 
                            a = utils.betterErrors(a);
                            if (a.error instanceof AssertionError && a.message)
                                    b = 
                                        messadge: a.message,
                                        stack: a.error.stack                                                                                         
                            else
                                b = 
                                    messadge: "",
                                    stack: a.error.stack                                        
                            
                            filetest.testsresult.push b
                    )
            moduleDone: (name, assertions) ->
                files.push(filetest)
            done: (assertions, end) ->
                console.log(files)
        }

module.exports.TestRunner =  TestRunner