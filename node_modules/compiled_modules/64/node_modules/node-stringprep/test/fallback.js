'use strict';

var proxyquire = require('proxyquire')

/* jshint -W030 */
describe('Should use JS fallbacks for StringPrep', function() {

    var StringPrep = proxyquire('../index', { 'bindings': null }).StringPrep

    it('Should throw on unknown icu-profile', function(done) {
        var prep = new StringPrep('cRaZYcASE')
        try {
            prep.prepare('UPPERCASE')
            done('Should have thrown error')
        } catch (e) {
            e.message.should.equal(prep.UNKNOWN_PROFILE_TYPE)
            done()
        }
    })

    it('Should perform a \'nameprep\'', function(done) {
        var prep = new StringPrep('nameprep')
        prep.prepare('UPPERCASE').should.equal('uppercase')
        done()
    })

    it('Should perform a \'nodeprep\'', function(done) {
        var prep = new StringPrep('nodeprep')
        prep.prepare('UPPERCASE').should.equal('uppercase')
        done()
    })

    it('Should preform a \'resourceprep\'', function(done) {
        var prep = new StringPrep('resourceprep')
        prep.prepare('UPPERCASE').should.equal('UPPERCASE')
        done()
    })

    it('Can\'t handle other profiles', function(done) {

        var unsupportedFallbackProfiles = [
            'nfs4_cs_prep',
            'nfs4_cis_prep',
            'nfs4_mixed_prep prefix',
            'nfs4_mixed_prep suffix',
            'iscsi',
            'mib',
            'saslprep',
            'trace',
            'ldap',
            'ldapci'
        ]

        var isDone = false
        unsupportedFallbackProfiles.forEach(function(profile) {

            var prep = new StringPrep(profile)
            try {
                prep.prepare('UPPERCASE')
                isDone = true
                done('Should have thrown error')
            } catch (e) {
                e.message.should.equal(prep.UNHANDLED_FALLBACK)
            }
        })
        if (false === isDone) done()
    })

})

describe('Can disable fallbacks', function() {
    
    var StringPrep = proxyquire('../index', { 'bindings': null }).StringPrep

    it('Should allow javascript fallbacks to be disabled', function(done) {
        var prep = new StringPrep('nameprep')
        try {
            prep.disableJsFallbacks()
            prep.prepare('UPPERCASE')
            done('Should have thrown exception')
        } catch (e) {
            e.message.should.equal(prep.LIBICU_NOT_AVAILABLE)
            done()
        }
    })
    
    it('Should allow javascript fallbacks to be re-enabled', function(done) {
        var prep = new StringPrep('nameprep')
        try {
            prep.disableJsFallbacks()
            prep.prepare('UPPERCASE')
            done('Should have thrown exception')
        } catch (e) {
            e.message.should.equal(prep.LIBICU_NOT_AVAILABLE)
            prep.enableJsFallbacks()
            prep.prepare('UPPERCASE')
            done()
        }
    })
    
})

describe('\'isNative\' method test', function() {

    it('Reports true with native', function() {
        var StringPrep = require('../index').StringPrep
        var prep = new StringPrep('resourceprep')
        prep.isNative().should.be.true
    })

    it('Reports false without native', function() {
        var StringPrep = proxyquire('../index', { 'bindings': null }).StringPrep
        var prep = new StringPrep('resourceprep')
        prep.isNative().should.be.false
    })

})
