mongoose = require 'mongoose'
mongoose.connect 'mongodb://192.168.33.10/test'

statemachine = require './lib/index'

UserSchema = new mongoose.Schema
  email: String
  password: String

UserSchema.plugin statemachine,
  states:
    a:
      exit: -> console.log 'exited a'
    b:
      enter: -> console.log 'entered b'
  transitions:
    x:
      from: 'a', to: 'b'
    y:
      from: 'b', to: 'a', guard: -> false


User = mongoose.model 'User', UserSchema



User.remove {}, ->
  user = new User email: 'joe@example.com', password: 'secret'
  user.save ->
    # Initial state of user
    console.log user
    user.x ->

      User.findOne email: 'joe@example.com', (err, bUser) ->
        console.log bUser

        bUser.y (err) ->
          console.log err
          User.findOne email: 'joe@example.com', (err, eUser) ->
            console.log bUser
            console.log eUser
        
