'use strict'
Promise   = require 'bluebird'
loopback  = require 'loopback'
isArray   = require 'util-ex/lib/is/type/array'
isObject  = require 'util-ex/lib/is/type/object'
isString  = require 'util-ex/lib/is/type/string'
isFunc    = require 'util-ex/lib/is/type/function'
extend    = require 'util-ex/lib/_extend'
minimatch = require 'minimatch-ex'

removeArray = (arr, items)->
  items = [items] if isString items
  a = items
  L = a.length
  result = 0
  while L && arr.length
    what = a[--L]
    while (ax = arr.indexOf(what)) != -1
      arr.splice(ax, 1)
      result++
  result
removeObject = (arr, items, model)->
  result = 0
  arr.forEach (item, index)->
    if item.model is model and items.indexOf(item.id)>=0
      arr.splice(index, 1)
      result++
  result

match = (aPath, aCollection)->
  # aCollection = Object.keys aCollection if isObject aCollection
  minimatch aPath, aCollection

# ['Account.find=1', 'xxx=3']
# to {'Account.find':1, 'xxx':3}
# arrayToObject = (value)->
#   result = {}
#   if isArray(value) and value.length
#     for item in value
#       if isString(item)
#         [k,v]=item.split '='
#         result[k]=v
#   if Object.keys(result).length then result else null
# objectToArray = (value)->
#   result = []
#   if isObject(value)
#     for k,v of value
#       result.push k + '=' + v
#   if result.length then result else null
# trimArray = (value)->
#   value.map (item)->
#     [k,_]=item.split('=')
#     k

RoleMixin = module.exports = (Model, aOptions) ->

  capitalizeFirstLetter = (aString)-> aString.charAt(0).toUpperCase() + aString.slice(1)

  # DataSource = Model.getDataSource()

  rolesFieldName    = (aOptions && aOptions.rolesFieldName) || 'roles'
  permsFieldName    = (aOptions && aOptions.permsFieldName) || '_perms'
  roleIdFieldName   = (aOptions && aOptions.roleIdFieldName) || 'name'
  ownerFieldName    = (aOptions && aOptions.ownerFieldName) || 'creatorId'
  maxLevel          = (aOptions && aOptions.maxLevel) || 12
  RoleModel         = (aOptions && aOptions.RoleModel) || Model
  rolesUpperName    = capitalizeFirstLetter rolesFieldName

  isPerm = (aRoleId)-> aRoleId.lastIndexOf('.') > 0

  isPermsExist = (aPerms) -> isArray(aPerms) and aPerms.length

  if roleIdFieldName is 'id'
    findRoleById = (aId, aOptions) -> RoleModel.findById aId, aOptions
  else
    findRoleById = (aId, aOptions) ->
      aOptions = aOptions || {}
      aOptions.where = {} unless isObject aOptions.where
      aOptions.where[roleIdFieldName] = aId
      RoleModel.findOne aOptions

  _mergePerms = (result, aRoles, lastVisited)->
    # get all perms from roles
    if isArray aRoles
      Promise.map aRoles, (aId)->
        if isPerm(aId) then aId else findRoleById aId
      .reduce (result, aRole)->
        if isString aRole
          result.push(aRole) if result.indexOf(aRole) is -1
        else if aRole
          if lastVisited < maxLevel
            ++lastVisited
            _mergePerms(result, aRole[rolesFieldName], lastVisited)
          else
            vError = new Error 'Exceed max level limits:' + maxLevel
            vError.code = 'ROLE_MAX_LEVEL_LIMITS'
            throw vError
        result
      , result
    else
      Promise.resolve(result)

  Model.getPerms = (aRoles, lastVisited = 0)->
    _mergePerms([], aRoles, lastVisited)

  Model::getPerms = (lastVisited = 0)->
    if isFunc Model._getPerms
      Model._getPerms(@, aRoles, lastVisited)
    else
      Model.getPerms @[rolesFieldName], lastVisited

  Model.hasPerm = (aId, aPermName, aContext)->
    Model.findById aId
    .then (aModel)->
      return aModel.hasPerm(aPermName, aContext) if aModel

  Model::hasPerm = (aPermName, aContext)->
    @getPerms().then (aPerms)->
      result = isArray(aPerms)
      if result
        result = match aPermName, aPerms
        if !result and aContext
          aPermName += '.owned'
          result = match aPermName, aPerms
          if result
            result = aContext.model
            if result
              vUserId = aContext.getUserId()
              if aContext.modelId?
                result = aContext.model.findById aContext.modelId
                .then (m)-> m and m[ownerFieldName] is vUserId
              else if result = aContext.remotingContext?.args?.hasOwnProperty 'filter'
                vArgs = aContext.remotingContext.args
                if isString vArgs.filter
                  vFilter = JSON.parse vArgs.filter
                else
                  vFilter = extend {}, vArgs.filter
                vWhere  = vFilter.where
                vWhere  = vFilter.where = {} unless isObject vWhere
                vWhere[ownerFieldName] = vUserId
                vArgs.filter = vFilter
      result

  Model::['add'+ rolesUpperName] = (aRoles)->
    result = @[rolesFieldName] || []
    vRoleId = @[roleIdFieldName] if Model is RoleModel
    if isString(aRoles)
      if result.indexOf(aRoles) is -1 and aRoles isnt vRoleId
        result.push aRoles
    else if isArray(aRoles) and aRoles.length
      for item in aRoles
        if result.indexOf(item) is -1 and item isnt vRoleId
          result.push item
    vData = {}
    vData[rolesFieldName] = result
    @updateAttributes vData

  Model::['remove'+ rolesUpperName] = (aRoles)->
    result = @[rolesFieldName]
    return Promise.resolve() unless isArray result
    if isString(aRoles)
      i = result.indexOf(aRoles)
      result.splice(i, 1) if i >= 0
    else if isArray(aRoles) and aRoles.length
      for item in aRoles
        i = result.indexOf(item)
        result.splice(i, 1) if i >= 0
    vData = {}
    vData[rolesFieldName] = result
    @updateAttributes vData

  Model.observe 'before save',(ctx)->
    vInstance = ctx.instance || ctx.data
    return Promise.resolve() if !vInstance or (ctx.options and ctx.options.skipPropertyFilter)

    return Promise.resolve() unless ctx.options and (remoteCtx = ctx.options.remoteCtx) and remoteCtx.req and account = remoteCtx.req.currentUser

    account.hasPerm Model.modelName + '.' + 'add' + rolesUpperName
    .then (allowed)->
      unless allowed
        err = new Error
        err.statusCode = 401
        err.message = 'No AddRole Authority'
        err.code = 'NO_AUTHORITY_ADD_ROLE'
        Promise.reject err

