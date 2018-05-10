'use strict'
Promise   = require 'bluebird'
loopback  = require 'loopback'
isArray   = require 'util-ex/lib/is/type/array'
isObject  = require 'util-ex/lib/is/type/object'
isString  = require 'util-ex/lib/is/type/string'
extend    = require 'util-ex/lib/_extend'
hasPerm   = require './has-perm'

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

## inject new fields to the Role Model
RoleMixin = module.exports = (Model, aOptions) ->

  capitalizeFirstLetter = (aString)-> aString.charAt(0).toUpperCase() + aString.slice(1)

  # DataSource = Model.getDataSource()

  cached            = (aOptions && aOptions.cached) || 1
  rolesFieldName    = (aOptions && aOptions.rolesFieldName) || 'roles'
  permsFieldName    = (aOptions && aOptions.permsFieldName) || '_perms'
  roleRefsFieldName = (aOptions && aOptions.roleRefsFieldName) || '_roleRefs'
  roleIdFieldName   = (aOptions && aOptions.roleIdFieldName) || 'name'
  ownerFieldName    = (aOptions && aOptions.ownerFieldName) || 'creatorId'
  maxLevel          = (aOptions && aOptions.maxLevel) || 12
  deleteUsedRole    = (aOptions && aOptions.deleteUsedRole) || false
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

  Model.hasPerm = (aId, aPermName, aContext)->
    Model.findById aId
    .then (aModel)->
      return aModel.hasPerm(aPermName, aContext) if aModel
      # err = new TypeError
      # err.statusCode = 404
      # err.message = Model.modelName + ' no such id:', aId
      # err.code = 'ID_NOT_EXISTS'
      # throw err

  Model::hasPerm = (aPermName, aContext)->
    Promise.resolve hasPerm @[permsFieldName], aPermName, aContext, ownerFieldName

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

  _merge = (result, aRole)->
    if isString(aRole)
      result.push(aRole) if result.indexOf(aRole) is -1
    else if aRole and isPermsExist(vPerms = aRole[permsFieldName])
      vPerms.forEach (k)->
        result.push(k) if result.indexOf(k) is -1
    result

  Model.getPerms = (aRoles)->
    # get all perms from roles
    if isArray aRoles
      Promise.map aRoles, (aId)->
        if isPerm(aId) then aId else findRoleById aId
      .reduce (aResult, aRole)->
        _merge aResult, aRole
      , []
    else
      Promise.resolve([])

  Model::getPerms = -> Model.getPerms @[rolesFieldName]

  calcPerms = (aInstance, ctx)->
    vGetPerms = Model.getPerms aInstance[rolesFieldName]

    if ctx.options and (remoteCtx = ctx.options.remoteCtx) and remoteCtx.req and account = remoteCtx.req.currentUser
      account.hasPerm Model.modelName + '.' + 'add' + rolesUpperName
      .then (allowed)->
        return vGetPerms if allowed
        err = new Error
        err.statusCode = 401
        err.message = 'No AddRole Authority'
        err.code = 'NO_AUTHORITY_ADD_ROLE'
        throw err
    else
       vGetPerms

  getValidRoles = (aRoles)->
    if isArray aRoles
      result = aRoles.filter (item)-> isString(item) and item.length
    else
      result = []
    result

  getDiffRoles = (aNewRoles, aOriginalRoles)->
    if aOriginalRoles and aOriginalRoles.length
      vAddedRoles = []
      vDelRoles = []
      for i in aNewRoles
        vAddedRoles.push i if aOriginalRoles.indexOf(i) is -1
      for i in aOriginalRoles
        vDelRoles.push i if aNewRoles.indexOf(i) is -1
    else
      vAddedRoles = aNewRoles

    [getValidRoles(vAddedRoles), getValidRoles(vDelRoles)]

  indexOfRef = (aRefs, aModel, aId)->
    for aRef,result in aRefs
      continue unless aRef.model is aModel
      return result if aRef.id is aId
    -1

  addToRefs = (aInstance, ctx)->
    [vAddedRoles, vDelRoles] = getDiffRoles aInstance[rolesFieldName], ctx.hookState.oldRoles

    vId = aInstance.id

    if vAddedRoles and vAddedRoles.length
      vAddedRoles = vAddedRoles.filter (item)-> not isPerm item
      vDoAddedRoles = Promise.map vAddedRoles, (aRoleId)->
        findRoleById aRoleId
        .then (aRole)->
          return unless aRole
          vRoleRefs = aRole[roleRefsFieldName] || []
          if indexOfRef(vRoleRefs, Model.modelName, vId) is -1
            vRoleRefs.push model:Model.modelName, id: vId
            return aRole.updateAttribute roleRefsFieldName, vRoleRefs, skipPropertyFilter:true
          return

    if vDelRoles and vDelRoles.length
      vDelRoles = vDelRoles.filter (item)-> not isPerm item
      vDoDelRoles = Promise.map vDelRoles, (aRoleId)->
        findRoleById aRoleId
        .then (aRole)->
          return unless aRole
          vRoleRefs = aRole[roleRefsFieldName] || []
          ix = indexOfRef(vRoleRefs, Model.modelName, vId)
          if ix isnt -1
            vRoleRefs.splice ix, 1
            return aRole.updateAttribute roleRefsFieldName, vRoleRefs, skipPropertyFilter:true
          return

    Promise.all [vDoAddedRoles, vDoDelRoles]

  Model.observe 'before save',(ctx)->
    vInstance = ctx.instance || ctx.data
    return Promise.resolve() if !vInstance or (ctx.options and ctx.options.skipPropertyFilter)
    return Promise.resolve() unless vInstance[rolesFieldName]?

    # disable update/save the perms field
    if ctx.instance # full save of a single model
      vInstance.unsetAttribute permsFieldName
    else # if ctx.data # Partial update of possibly multiple models
      delete vInstance[permsFieldName]

    if ctx.data and !ctx.currentInstance
      err = new Error
      # err.statusCode = 401
      err.message = 'Disable batch update roles'
      err.code = 'NO_AUTHORITY_BATCH_ROLE'
      return Promise.reject err

    if ctx.data
      saveOldRoles = Model.findById ctx.currentInstance.id, fields: [rolesFieldName]
      .then (instance)->
        vRoles = instance[rolesFieldName] if instance
        ctx.hookState.oldRoles = vRoles if vRoles and vRoles.length
        return

    return Promise.resolve() unless vInstance[rolesFieldName]?

    vInstance[rolesFieldName] = getValidRoles vInstance[rolesFieldName]
    saveOldRoles = Promise.resolve() unless saveOldRoles


    saveOldRoles.then ->
      calcPerms vInstance, ctx
      .then (aPerms)->
        vInstance[permsFieldName] = aPerms
        ctx.options = {} unless ctx.options
        ctx.options.updatePermsByRefs = 0

  Model.observe 'after save',(ctx)->
    return Promise.resolve() if ctx.options and ctx.options.skipPropertyFilter
    # it's always ctx.instance after saving?
    vInstance = ctx.instance || ctx.data
    return Promise.resolve() unless vInstance and vInstance[rolesFieldName]?
    addToRefs(vInstance, ctx)

  # remove itself from roleRefs
  Model.observe 'before delete',(ctx)->
    vState = ctx.hookState
    vState.deletedRoles = []
    vRoleRefs = new Set()
    vRoles = new Set()
    Model.find where: ctx.where, fields: ['id', roleRefsFieldName, rolesFieldName]
    .then (results)->
      if results
        Promise.each results, (item)->
          if (v = item[rolesFieldName]) and v.length
            v.forEach (i)-> vRoles.add i unless isPerm i
            vOk = true
          if (v = item[roleRefsFieldName]) and v.length
            #  for cascade delete. write here to speedup. no more Model.find.
            v.forEach (i)-> vRoleRefs.add i
            vOk = true
          if vOk
            vState.deletedRoles.push item.id
          return
    .then ->
      vState.roles = Array.from(vRoles) if vRoles.size
      vState.roleRefs = Array.from(vRoleRefs) if vRoleRefs.size
      vState.deletedRoles = null unless vState.deletedRoles.length
      return

  # remove itself from roleRefs
  Model.observe 'after delete',(ctx)->
    vState = ctx.hookState
    return Promise.resolve() unless vState.roles and vState.deletedRoles
    vRoles = vState.roles
    Promise.map vState.roles, (id)->
      Model.findById id
    .each (item)->
      return unless item
      vRoleRefs = item[roleRefsFieldName]
      if vRoleRefs and vRoleRefs.length and removeObject vRoleRefs, vState.deletedRoles, Model.modelName
        result = item.updateAttribute roleRefsFieldName, vRoleRefs, skipPropertyFilter:true
      result

  if Model is RoleModel
    if deleteUsedRole # cascade delete.
      Model.observe 'after delete',(ctx)->
        vState = ctx.hookState
        return Promise.resolve() unless vState.deletedRoles and vState.roleRefs
        Promise.map vState.roleRefs, (i)->
          M = loopback.getModel i.model
          M.findById i.id if M
        .each (item)->
          return unless item
          vRoles = item[rolesFieldName]
          if vRoles and vRoles.length
            if removeArray vRoles, vState.deletedRoles
              result = item.updateAttribute rolesFieldName, vRoles
          result
    else # not deleteUsedRole
      Model.observe 'before delete',(ctx)->
        Model.find where: ctx.where, fields: ['id', roleRefsFieldName]
        .then (results)->
          if results
            Promise.each results, (item)->
              if (v=item[roleRefsFieldName]) and v.length
                vError = new Error 'Can not delete the used role:' + item.id
                vError.code = 'DELETE_USED_ROLE'
                throw vError

    Model.observe 'before save',(ctx, next)->
      return next() if ctx.options and ctx.options.skipPropertyFilter

      vInstance = ctx.instance || ctx.data

      # disable update/save the roleRefs field
      if vInstance
        if ctx.instance
          vInstance.unsetAttribute roleRefsFieldName
        else
          delete vInstance[roleRefsFieldName]
      next()

    updatePermsByRefs = (aInstance, ctx)->
      # ctx.hookState?
      vRefs = aInstance[roleRefsFieldName]
      if vRefs and vRefs.length
        Promise.map vRefs, (aRef)->
          vModel = loopback.getModel aRef.model
          if vModel
            vModel.findById aRef.id
            .then (aItem)->
              return unless aItem
              aItem.getPerms()
              .then (aPerms)->
                if isPermsExist(aPerms)
                  vLevel = (ctx.options && ctx.options.updatePermsByRefs) || 0
                  vLevel++
                  aItem.updateAttribute permsFieldName, aPerms,
                    skipPropertyFilter:true
                    updatePermsByRefs: vLevel
      else
        Promise.resolve()

    Model.observe 'after save',(ctx)->
      vInstance = ctx.instance || ctx.data
      vLevel = ctx.options && ctx.options.updatePermsByRefs
      return Promise.resolve() unless vLevel? and vInstance and vInstance[rolesFieldName]?
      if vLevel >= maxLevel
        vError = new Error 'Exceed max level limits:' + maxLevel
        vError.code = 'ROLE_MAX_LEVEL_LIMITS'
        return Promise.reject vError
      # when perms changed.
      updatePermsByRefs vInstance, ctx
