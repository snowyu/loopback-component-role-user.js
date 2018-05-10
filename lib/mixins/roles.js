(function() {
  'use strict';
  var RoleMixin, noneCache, updatedCache, userCache;

  noneCache = require('./none-cache-roles');

  updatedCache = require('./updated-roles');

  userCache = require('./user-cache-roles');

  RoleMixin = module.exports = function(Model, aOptions) {
    var RoleModel, cached, capitalizeFirstLetter, deleteUsedRole, maxLevel, ownerFieldName, permsFieldName, roleIdFieldName, roleRefsFieldName, rolesFieldName, rolesUpperName;
    capitalizeFirstLetter = function(aString) {
      return aString.charAt(0).toUpperCase() + aString.slice(1);
    };
    cached = aOptions && (aOptions.cached != null) ? aOptions.cached : 1;
    rolesFieldName = (aOptions && aOptions.rolesFieldName) || 'roles';
    permsFieldName = (aOptions && aOptions.permsFieldName) || '_perms';
    roleRefsFieldName = (aOptions && aOptions.roleRefsFieldName) || '_roleRefs';
    roleIdFieldName = (aOptions && aOptions.roleIdFieldName) || 'name';
    ownerFieldName = (aOptions && aOptions.ownerFieldName) || 'creatorId';
    maxLevel = (aOptions && aOptions.maxLevel) || 12;
    deleteUsedRole = (aOptions && aOptions.deleteUsedRole) || false;
    RoleModel = (aOptions && aOptions.RoleModel) || Model;
    rolesUpperName = capitalizeFirstLetter(rolesFieldName);
    Model.defineProperty(rolesFieldName, {
      "type": ["string"],
      "description": "The role list",
      "mysql": {
        "columnName": rolesFieldName,
        "dataType": "TEXT",
        "nullable": "Y"
      }
    });
    Model.defineProperty(permsFieldName, {
      "type": ["string"],
      "description": "The permissions cache list for roles(Readonly)",
      "mysql": {
        "columnName": permsFieldName,
        "dataType": "TEXT",
        "nullable": "Y"
      }
    });
    if (Model === RoleModel) {
      Model.defineProperty(roleRefsFieldName, {
        "type": "array",
        "description": "The role reference list for roles(Readonly)",
        "mysql": {
          "columnName": roleRefsFieldName,
          "dataType": "TEXT",
          "nullable": "Y"
        }
      });
    }
    switch (cached) {
      case 0:
        return noneCache(Model, aOptions);
      case 2:
        return userCache(Model, aOptions);
      default:
        return updatedCache(Model, aOptions);
    }
  };

}).call(this);

//# sourceMappingURL=roles.js.map
