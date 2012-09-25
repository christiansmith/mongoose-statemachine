statemachine = require '../lib/index'
mongoose     = require 'mongoose'
sinon        = require 'sinon'
require 'should'

describe 'state machine', ->

  model  = null
  Model  = null

  before (done) ->
    mongoose.connect 'mongodb://192.168.33.10/statemachine-test'
    done()

  describe 'schema', ->

    it 'should enumerate states', ->
      schema = new mongoose.Schema
      schema.plugin statemachine,
        states:
          a: {}
          b: {}
          c: {}
        transitions:
          x: { from: 'a', to: 'b' }
          y: { from: 'b', to: 'c', guard: -> return false }
          z: { from: 'c', to: 'a' }

      schema.paths.state.enumValues.should.eql ['a', 'b', 'c']

  describe 'model', ->
    
    beforeEach (done) ->
      schema = new mongoose.Schema
      schema.plugin statemachine,
        states:
          a: {}
          b: {}
          c: {}
        transitions:
          x: { from: 'a', to: 'b' }
          y: { from: 'b', to: 'c', guard: -> return false }
          z: { from: 'c', to: 'a' }
      Model = mongoose.model 'Model', schema
      model = new Model
      done()

    it 'should expose available states', ->
      model._states.should.eql ['a','b','c']
      
    it 'should have transition methods', ->
      model.x.should.be.a 'function'
      model.y.should.be.a 'function'
      model.z.should.be.a 'function'

    it 'should have a default state', ->
      model.state.should.eql 'a'

    it 'should look for a defined default state', ->
      DefaultState = new mongoose.Schema
      DefaultState.plugin statemachine, {states: {a:{},b:{default:true}}, transitions: {}}
      Model = mongoose.model 'DefaultState', DefaultState
      model = new Model
      model.state.should.eql 'b'

    it 'should transition between states', (done) ->
      model.x (err) ->
        model.state.should.eql 'b'
        done()

    it 'should require transitions between states to be defined', (done) ->
      model.y (err) ->
        model.state.should.eql 'a'
        done()

    it 'should guard transitions', (done) ->
      model = new Model state: 'b'
      model.y (err) ->
        model.state.should.eql 'b'
        done()

    it 'should save the document during transition', (done) ->
      model = new Model state: 'c'
      model.z (err) ->
        model.isNew.should.be.false
        done()

  describe 'guard', ->

    before (done) ->
      GuardSchema = new mongoose.Schema
        attr1: String
        attr2: String
      GuardSchema.plugin statemachine,
        states:
          a: {}
          b: {}
        transitions:
          f:
            from: 'a'
            to: 'b'
            guard:
              attr1: -> 'required' unless @attr1?

      Model = mongoose.model 'GuardSchema', GuardSchema
      done()

    it 'should protect the state', (done) ->
      model = new Model
      model.f (err) ->
        model.state.should.eql 'a'
        done()

    it 'should invalidate the document', (done) ->
      model = new Model
      model.f (err) ->
        err.errors.attr1.type.should.eql 'required'
        done()


  describe 'after transition', ->
    enter = null
    exit  = null

    before (done) ->
      enter = sinon.spy()
      exit = sinon.spy()

      CallbackSchema = new mongoose.Schema
      CallbackSchema.plugin statemachine,
        states:
          a: {exit}
          b: {enter}
        transitions:
          f: { from: 'a', to: 'b' }

      Model = mongoose.model 'CallbackSchema', CallbackSchema
      done()

    it 'should call enter', (done) ->
      model = new Model
      model.f (err) ->
        enter.called.should.be.true
        done()

    it 'should call exit', (done) ->
      model = new Model
      model.f ->
        exit.called.should.be.true
        done()
