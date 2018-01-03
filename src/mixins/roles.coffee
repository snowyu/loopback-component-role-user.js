'use strict'
noneCache     = require './none-cache-roles'
updatedCache  = require './updated-roles'
userCache     = require './user-cache-roles'

## inject new fields to the Role Model
RoleMixin = module.exports = (Model, aOptions) ->

  capitalizeFirstLetter = (aString)-> aString.charAt(0).toUpperCase() + aString.slice(1)

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

  Model.defineProperty rolesFieldName,
    "type": ["string"]
    "description": "The role list"
    "mysql":
      "columnName":rolesFieldName
      "dataType":"TEXT"
      "nullable":"Y"
  Model.defineProperty permsFieldName,
    "type": ["string"]
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

  switch cached
    when 0
      noneCache(Model, aOptions)
    when 2
      userCache(Model, aOptions)
    else
      updatedCache(Model, aOptions)
