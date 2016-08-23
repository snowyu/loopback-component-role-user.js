Promise     = require 'bluebird'
isArray     = require 'util-ex/lib/is/type/array'
debug       = require('debug')('loopback:security:role:user')
injectUserHasRoleMethod = require './user-has-role'

registerRole = (Role, aRoleName, ahasRoleFn, aOperators)->
  debug 'register role resolver: %s', aRoleName
  Role.registerResolver aRoleName, (role, context, done)->
    reject = (err)-> if err then done(err) else process.nextTick ->
      if done then done(null, false)
      return
    vUserId = context.getUserId()
    unless vUserId
      debug 'disable anonymous user'
      reject()
    else
      vRoleName = context.modelName + '.' + (aOperators[context.property] || context.property)
      ahasRoleFn vUserId, vRoleName, context
      .then (result)->
        debug 'the userId %s has the %s: %s', vUserId, vRoleName, result
        done(null, result)
        return
      .catch (err)->
        debug 'the userId %s has the %s raise error: %s', vUserId, vRoleName, err
        done(err)
        return
    return

isRoleIn = (aAcls, aRoleName)->
  for acl in aAcls
    return true if acl.principalType is 'ROLE' and acl.principalId is aRoleName
  return false

module.exports = (aApp, aOptions) ->
  injectUserHasRoleMethod aApp, (aOptions and aOptions.adminRole)

  loopback = aApp.loopback
  Role = loopback.Role
  RoleMapping = loopback.RoleMapping
  User = loopback.User
  vRoleName = (aOptions and aOptions.role) or '$user'
  vOperators = (aOptions and aOptions.operators) or
    create: 'add'
    upsert: 'edit'
    updateAttributes: 'edit'
    exists: 'view'
    findById: 'view'
    find: 'find'
    findOne: 'find'
    count: 'find'
    destroyById: 'delete'
    deleteById: 'delete'

  vHasRole = (aOptions and aOptions.hasRole) or User.hasRole
  vModels = (aOptions and aOptions.models)
  vModels = [] if vModels is false
  if isArray vModels
    vResult = {}
    for vName in vModels
      Model = aApp.models[vName]
      vResult[vName] = Model if Model
    vModels = vResult
  else
    vModels = aApp.models

  registerRole Role, vRoleName, vHasRole, vOperators

  for vName, Model of vModels
    vAcls = Model.settings.acls
    vAcls = Model.settings.acls = [] unless vAcls
    unless isRoleIn vAcls, vRoleName
      debug 'enable $user for Model %s', vName
      vAcls.push
        principalType: 'ROLE'
        principalId: vRoleName
        permission: 'ALLOW'
  return
