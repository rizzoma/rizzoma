'use strict';

require('should')

it('Should not leak', function(done) {

    var SP = require('../index')

    try {
        var p = new SP.StringPrep('nameprep')
        var result = p.prepare('A\u0308ffin')
        result.should.equal('äffin')
        done()
    } catch (e) {
        done(e)
    }
})
