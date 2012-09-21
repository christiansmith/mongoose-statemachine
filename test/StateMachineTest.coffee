mongoose = require 'mongoose'
statemachine = require '../lib/index'

require 'should'

describe 'state machine', ->

  schema = null

  beforeEach ->
    schema = new mongoose.Schema enterVal: String, exitVal: String
    schema.plugin statemachine,
      states:
        a:
          enter: -> @enterVal = 'entered'
        b: {}
        c:
          exit: -> @exitVal = 'exited'
      transitions:
        x: { from: 'a', to: 'b' }
        y: { from: 'b', to: 'c', guard: -> return false }
        z: { from: 'c', to: 'a' }

  describe 'schema', ->

    it 'should enumerate states', ->
      schema.paths.state.enumValues.should.eql ['a', 'b', 'c']

  describe 'model', ->
    
    model = null
    Model = null

    beforeEach ->
      Model = mongoose.model 'Model', schema
      model = new Model

    it 'should expose available states', ->
      model._states.should.eql schema.paths.state.enumValues
      
    it 'should have transition methods', ->
      model.x.should.be.a 'function'
      model.y.should.be.a 'function'
      model.z.should.be.a 'function'

    it 'should have a default state', ->
      model.state.should.eql 'a'

    it 'should look for a defined default state', ->
      schema2 = new mongoose.Schema
      schema2.plugin statemachine, {states: {a:{},b:{default:true}}, transitions: {}}
      Model = mongoose.model 'Model2', schema2
      model = new Model
      model.state.should.eql 'b'

    it 'should transition between states', ->
      model.x()
      model.state.should.eql 'b'

    it 'should require transitions between states to be defined', ->
      model.y()
      model.state.should.eql 'a'

    it 'should guard transitions', ->
      model = new Model state: 'b'
      model.y()
      model.state.should.eql 'b'

    it 'should handle enter events', ->
      model = new Model state: 'b'
      model.z()
      model.enterVal.should.eql 'entered'

    it 'should handle exit events', ->
      model = new Model state: 'b'
      model.z()
      model.exitVal.should.eql 'exited'

