'use strict'
Promise   = require 'bluebird'
loopback  = require 'loopback'
isArray   = require 'util-ex/lib/is/type/array'
isObject  = require 'util-ex/lib/is/type/object'
isString  = require 'util-ex/lib/is/type/string'
minimatch = require 'minimatch-ex'

match = (aPath, aCollection)->
  aCollection = Object.keys aCollection if isObject aCollection
  minimatch aPath, aCollection

## inject new fields to the Role Model
RoleMixin = module.exports = (Model, aOptions) ->

  capitalizeFirstLetter = (aString)-> aString.charAt(0).toUpperCase() + aString.slice(1)

  # DataSource = Model.getDataSource()

  rolesFieldName    = (aOptions && aOptions.rolesFieldName) || 'roles'
  permsFieldName    = (aOptions && aOptions.permsFieldName) || '_perms'
  roleRefsFieldName = (aOptions && aOptions.roleRefsFieldName) || '_roleRefs'
  roleIdFieldName   = (aOptions && aOptions.roleIdFieldName) || 'name'
  RoleModel         = (aOptions && aOptions.RoleModel) || Model
  rolesUpperName    = capitalizeFirstLetter rolesFieldName

  Model.defineProperty rolesFieldName,
    "type": "array"
    "description": "The role list"
    "mysql":
      "columnName":rolesFieldName
      "dataType":"TEXT"
      "nullable":"Y"
  Model.defineProperty permsFieldName,
    "type": "object"
    "description": "The permissions cache list for roles(Readonly)"
    "mysql":
      "columnName":permsFieldName
      "dataType":"TEXT"
      "nullable":"Y"
  if Model is RoleModel
    Model.defineProperty roleRefsFieldName,
      "type": "array" # item: {model: xx, id: xxx}
      "description": "The role reference list for roles(Readonly)"
      "mysql":
        "columnName":roleRefsFieldName
        "dataType":"TEXT"
        "nullable":"Y"
    # DataSource.hiddenProperty Model, roleRefsFieldName

  isPerm = (aRoleId)-> aRoleId.lastIndexOf('.') > 0

  if roleIdFieldName is 'id'
    findRoleById = (aId, aOptions) -> RoleModel.findById aId, aOptions
  else
    findRoleById = (aId, aOptions) ->
      aOptions = aOptions || {}
      aOptions.where = {} unless isObject aOptions.where
      aOptions.where[roleIdFieldName] = aId
      RoleModel.findOne aOptions

  Model.hasPerm = (aId, aPermName)->
    Model.findById aId
    .then (aModel)->
      return aModel.hasPerm(aPermName) if aModel
      # err = new TypeError
      # err.statusCode = 404
      # err.message = Model.modelName + ' no such id:', aId
      # err.code = 'ID_NOT_EXISTS'
      # throw err

  Model::hasPerm = (aPermName)->
    # if adminRole and @[roleIdFieldName] is adminRole
    #   Promise.resolve(true)
    # else
    if isObject @[permsFieldName]
      Promise.resolve minimatch aPermName, @[permsFieldName]
    else
      Promise.resolve(false)
    # return Promise.resolve(true) if @id is adminRole
    # return Promise.resolve minimatch aRoleName, @perms if isArray @perms
    # vRoles = @principals
    # if isArray(vRoles) and vRoles.length
    #   Promise.map vRole, (aRoleId)->
    #     Model.findById aRoleId
    #   .reduce (aResult, aRole)->
    #     unless aResult is true
    #       if aRole.id is aRoleName
    #         aResult = true
    #       else
    #         aResult = aRole.hasPerm(aRoleName)
    #     aResult
    #   , false
    # else
    #   Promise.resolve(false)


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
      if result[aRole]?
        result[aRole]++
      else
        result[aRole] = 1
    else if aRole and isObject(vPerms = aRole[permsFieldName])
      for k,v of vPerms
        if result[k]?
          result[k]++
        else
          result[k] = 1
    result

  Model.getPerms = (aRoles)->
    # get all perms from roles
    if isArray aRoles
      Promise.map aRoles, (aId)->
        if isPerm(aId) then aId else findRoleById aId
      .reduce (aResult, aRole)->
        _merge aResult, aRole
      , {}
    else
      Promise.resolve({})

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

  getDiffRoles = (aInstance, ctx)->
    if ctx.instance # full save of a single model
      vAddedRoles = aInstance[rolesFieldName]
    else # if ctx.data # Partial update of possibly multiple models
      unless ctx.currentInstance # The Role only
        err = new Error
        err.statusCode = 401
        err.message = 'Disable batch update roles'
        err.code = 'NO_AUTHORITY_BATCH_ROLE'
        throw err
      vAddedRoles = []
      vDelRoles = []
      vOrgionalRoles = ctx.currentInstance[rolesFieldName]
      if vOrgionalRoles and vOrgionalRoles.length
        vNewRoles = aInstance[rolesFieldName]
        for i in vNewRoles
          vAddedRoles.push i if vOrgionalRoles.indexOf(i) is -1
        for i in vOrgionalRoles
          vDelRoles.push i if vNewRoles.indexOf(i) is -1
      else
        vAddedRoles = aInstance[rolesFieldName]
    [getValidRoles(vAddedRoles), getValidRoles(vDelRoles)]

  indexOfRef = (aRefs, aModel, aId)->
    for aRef,result in aRefs
      continue unless aRef.model is aModel
      return result if aRef.id is aId
    -1

  addToRefs = (aInstance, ctx)->
    try
      [vAddedRoles, vDelRoles] = getDiffRoles aInstance, ctx
    catch err
      return Promise.reject(err)

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
            aRole.updateAttribute roleRefsFieldName, vRoleRefs

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
            aRole.updateAttribute roleRefsFieldName, vRoleRefs

    Promise.all [vDoAddedRoles, vDoDelRoles]

  Model.observe 'before save',(ctx)->
    vInstance = ctx.instance || ctx.data
    return Promise.resolve() unless vInstance

    # disable update/save the perms field
    if ctx.instance # full save of a single model
      vInstance.unsetAttribute permsFieldName
    else # if ctx.data # Partial update of possibly multiple models
      delete vInstance[permsFieldName]

    return Promise.resolve() unless vInstance[rolesFieldName]?
    vInstance[rolesFieldName] = getValidRoles vInstance[rolesFieldName]
    calcPerms vInstance, ctx
    .then (aPerms)->
      vInstance[permsFieldName] = aPerms

  if Model is RoleModel
    Model.observe 'before save',(ctx, next)->
      vInstance = ctx.instance || ctx.data

      # disable update/save the roleRefs field
      if vInstance
        if ctx.instance
          vInstance.unsetAttribute roleRefsFieldName
        else
          delete vInstance[roleRefsFieldName]
      next()

    updatePermsByRefs = (aInstance, ctx)->
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
                aItem.updateAttribute permsFieldName, aPerms if aPerms and aPerms.length
      else
        Promise.resolve()

    Model.observe 'after save',(ctx)->
      vInstance = ctx.instance || ctx.data
      return Promise.resolve() unless vInstance and vInstance[rolesFieldName]?
      addToRefs(vInstance, ctx)
      .then ->
        updatePermsByRefs vInstance, ctx
  else
    Model.observe 'after save',(ctx)->
      vInstance = ctx.instance || ctx.data
      return Promise.resolve() unless vInstance and vInstance[rolesFieldName]?
      addToRefs(vInstance, ctx)
