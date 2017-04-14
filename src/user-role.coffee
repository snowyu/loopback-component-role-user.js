Promise     = require 'bluebird'
isArray     = require 'util-ex/lib/is/type/array'
isFunction  = require 'util-ex/lib/is/type/function'
extend      = require 'util-ex/lib/_extend'
debug       = require('debug')('loopback:security:role:user')
injectRoles = require './mixins/roles'

registerRole = (Role, aRoleName, User, aOperations)->
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
      vPermName = context.modelName + '.' + (aOperations[context.property] || context.property)
      User.hasPerm vUserId, vPermName, context
      .then (result)->
        debug 'the userId %s has the %s: %s', vUserId, vPermName, result
        done(null, result)
        return
      .catch (err)->
        debug 'the userId %s has the %s raise error: %s', vUserId, vPermName, err
        done(err)
        return
    return

isRoleIn = (aAcls, aRoleName)->
  for acl in aAcls
    return true if acl.principalType is 'ROLE' and acl.principalId is aRoleName
  return false

module.exports = (aApp, aOptions = {}) ->
  loopback = aApp.loopback
  Role = (aOptions.roleModel and loopback.getModel aOptions.roleModel) || loopback.Role
  User = (aOptions.userModel and loopback.getModel aOptions.userModel) || loopback.User
  # aOptions.ownerFieldName = 'creatorId' unless aOptions.ownerFieldName
  injectRoles Role, aOptions
  injectRoles User, extend {}, aOptions, RoleModel: Role

  vRoleName = (aOptions and aOptions.role) or '$user'
  vOperations = (aOptions and aOptions.operations) or
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

  registerRole loopback.Role, vRoleName, User, vOperations

  for vName, Model of vModels
    vAcls = Model.settings.acls
    vAcls = Model.settings.acls = [] unless vAcls
    unless isRoleIn vAcls, vRoleName
      debug 'enable "%s" Role for Model %s', vRoleName, vName
      vAcls.push
        principalType: 'ROLE'
        principalId: vRoleName
        permission: 'ALLOW'
  return
