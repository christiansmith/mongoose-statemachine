# Copyright(c) 2012 Christian Smith <smith@anvil.io>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

_ = require 'underscore'

statemachine = (schema, options) ->
  {states, transitions} = options
  stateNames            = Object.keys states
  transitionNames       = Object.keys transitions

  # add a state field to the schema
  schema.add state: { type: String, enum: stateNames, default: defaultState(states) }

  # make a reference on the model to allowed states
  schema.virtual('_states').get ->
    schema.paths.state.enumValues

  # transition method creation
  transitionize = (t) ->

    # get the transition by name and destructure it
    transition = transitions[t]
    exit       = states[transition.from].exit
    enter      = states[transition.to].enter
    guard      = transition.guard

    # return a transition method 
    return (callback) ->
      switch typeof guard
        when 'function'
          return callback(new Error 'guard failed') if guard?.apply(@)?
        when 'object'
          # invalidate the document for each guard that returns a message
          @invalidate k, v.apply(@) for k, v of guard when v.apply(@)?
          return callback @_validationError if @_validationError?
      
      # change the state
      @state = transition.to if @state is transition.from

      # save the document
      @save (err) =>
        return callback(err) if err

        # call the state change handlers
        enter.call(@) if enter?
        exit.call(@) if exit?
        return callback(null)

  # build the transition methods from provided transitions
  transitionMethods = {}
  transitionMethods[t] = transitionize(t) for t in transitionNames
  schema.method transitionMethods

# check for an explicit default
# otherwise use the first state
defaultState = (states) ->
  stateNames = Object.keys states
  selected = _.filter stateNames, (s) -> return s if states[s].default is true
  selected[0] or stateNames[0]

module.exports = statemachine
