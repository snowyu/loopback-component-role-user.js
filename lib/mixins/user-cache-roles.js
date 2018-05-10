(function() {
  'use strict';
  var Promise, RoleMixin, extend, hasPerm, isArray, isObject, isString, loopback, removeArray, removeObject;

  Promise = require('bluebird');

  loopback = require('loopback');

  isArray = require('util-ex/lib/is/type/array');

  isObject = require('util-ex/lib/is/type/object');

  isString = require('util-ex/lib/is/type/string');

  extend = require('util-ex/lib/_extend');

  hasPerm = require('./has-perm');

  removeArray = function(arr, items) {
    var L, a, ax, result, what;
    if (isString(items)) {
      items = [items];
    }
    a = items;
    L = a.length;
    result = 0;
    while (L && arr.length) {
      what = a[--L];
      while ((ax = arr.indexOf(what)) !== -1) {
        arr.splice(ax, 1);
        result++;
      }
    }
    return result;
  };

  removeObject = function(arr, items, model) {
    var result;
    result = 0;
    arr.forEach(function(item, index) {
      if (item.model === model && items.indexOf(item.id) >= 0) {
        arr.splice(index, 1);
        return result++;
      }
    });
    return result;
  };

  RoleMixin = module.exports = function(Model, aOptions) {
    var RoleModel, _mergePerms, capitalizeFirstLetter, findRoleById, isPerm, isPermsExist, maxLevel, ownerFieldName, permsFieldName, roleIdFieldName, rolesFieldName, rolesUpperName;
    capitalizeFirstLetter = function(aString) {
      return aString.charAt(0).toUpperCase() + aString.slice(1);
    };
    rolesFieldName = (aOptions && aOptions.rolesFieldName) || 'roles';
    permsFieldName = (aOptions && aOptions.permsFieldName) || '_perms';
    roleIdFieldName = (aOptions && aOptions.roleIdFieldName) || 'name';
    ownerFieldName = (aOptions && aOptions.ownerFieldName) || 'creatorId';
    maxLevel = (aOptions && aOptions.maxLevel) || 12;
    RoleModel = (aOptions && aOptions.RoleModel) || Model;
    rolesUpperName = capitalizeFirstLetter(rolesFieldName);
    isPerm = function(aRoleId) {
      return aRoleId.lastIndexOf('.') > 0;
    };
    isPermsExist = function(aPerms) {
      return isArray(aPerms) && aPerms.length;
    };
    if (roleIdFieldName === 'id') {
      findRoleById = function(aId, aOptions) {
        return RoleModel.findById(aId, aOptions);
      };
    } else {
      findRoleById = function(aId, aOptions) {
        aOptions = aOptions || {};
        if (!isObject(aOptions.where)) {
          aOptions.where = {};
        }
        aOptions.where[roleIdFieldName] = aId;
        return RoleModel.findOne(aOptions);
      };
    }
    _mergePerms = function(result, aRoles, lastVisited) {
      if (isArray(aRoles)) {
        return Promise.map(aRoles, function(aId) {
          if (isPerm(aId)) {
            return aId;
          } else {
            return findRoleById(aId);
          }
        }).reduce(function(result, aRole) {
          var vError;
          if (isString(aRole)) {
            if (result.indexOf(aRole) === -1) {
              result.push(aRole);
            }
          } else if (aRole) {
            if (lastVisited < maxLevel) {
              ++lastVisited;
              _merege(result, aRole[rolesFieldName], lastVisited);
            } else {
              vError = new Error('Exceed max level limits:' + maxLevel);
              vError.code = 'ROLE_MAX_LEVEL_LIMITS';
              throw vError;
            }
          }
          return result;
        }, result);
      } else {
        return Promise.resolve(result);
      }
    };
    Model.getPerms = function(aRoles, lastVisited) {
      if (lastVisited == null) {
        lastVisited = 0;
      }
      return _mergePerms([], aRoles, lastVisited);
    };
    Model.prototype.getPerms = function(lastVisited) {
      if (lastVisited == null) {
        lastVisited = 0;
      }
      return Model.getPerms(this[rolesFieldName], lastVisited);
    };
    Model.hasPerm = function(aId, aPermName, aContext) {
      return Model.findById(aId).then(function(aModel) {
        if (aModel) {
          return aModel.hasPerm(aPermName, aContext);
        }
      });
    };
    Model.prototype.hasPerm = function(aPermName, aContext) {
      var vPerms;
      vPerms = this[permsFieldName];
      if (isArray(vPerms)) {
        vPerms = Promise.resolve(this[permsFieldName]);
      } else {
        vPerms = this.getPerms();
      }
      return vPerms.then((function(_this) {
        return function(aPerms) {
          var result, vData;
          result = isArray(aPerms);
          vData = {};
          vData[permsFieldName] = result;
          result = hasPerm(aPerms, aPermName, aContext, ownerFieldName);
          return _this.updateAttributes(vData).then(function() {
            return result;
          });
        };
      })(this));
    };
    Model.prototype['add' + rolesUpperName] = function(aRoles) {
      var item, j, len, result, vData, vRoleId;
      result = this[rolesFieldName] || [];
      if (Model === RoleModel) {
        vRoleId = this[roleIdFieldName];
      }
      if (isString(aRoles)) {
        if (result.indexOf(aRoles) === -1 && aRoles !== vRoleId) {
          result.push(aRoles);
        }
      } else if (isArray(aRoles) && aRoles.length) {
        for (j = 0, len = aRoles.length; j < len; j++) {
          item = aRoles[j];
          if (result.indexOf(item) === -1 && item !== vRoleId) {
            result.push(item);
          }
        }
      }
      vData = {};
      vData[rolesFieldName] = result;
      return this.updateAttributes(vData);
    };
    Model.prototype['remove' + rolesUpperName] = function(aRoles) {
      var i, item, j, len, result, vData;
      result = this[rolesFieldName];
      if (!isArray(result)) {
        return Promise.resolve();
      }
      if (isString(aRoles)) {
        i = result.indexOf(aRoles);
        if (i >= 0) {
          result.splice(i, 1);
        }
      } else if (isArray(aRoles) && aRoles.length) {
        for (j = 0, len = aRoles.length; j < len; j++) {
          item = aRoles[j];
          i = result.indexOf(item);
          if (i >= 0) {
            result.splice(i, 1);
          }
        }
      }
      vData = {};
      vData[rolesFieldName] = result;
      return this.updateAttributes(vData);
    };
    return Model.observe('before save', function(ctx) {
      var account, remoteCtx, vInstance;
      vInstance = ctx.instance || ctx.data;
      if (!vInstance || (ctx.options && ctx.options.skipPropertyFilter)) {
        return Promise.resolve();
      }
      if (vInstance[rolesFieldName] == null) {
        return Promise.resolve();
      }
      if (!(ctx.options && (remoteCtx = ctx.options.remoteCtx) && remoteCtx.req && (account = remoteCtx.req.currentUser))) {
        return Promise.resolve();
      }
      return account.hasPerm(Model.modelName + '.' + 'add' + rolesUpperName).then(function(allowed) {
        var err;
        if (!allowed) {
          err = new Error;
          err.statusCode = 401;
          err.message = 'No AddRole Authority';
          err.code = 'NO_AUTHORITY_ADD_ROLE';
          return Promise.reject(err);
        }
      });
    });
  };

}).call(this);

//# sourceMappingURL=user-cache-roles.js.map
