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
    var RoleModel, _merge, addToRefs, cached, calcPerms, capitalizeFirstLetter, deleteUsedRole, findRoleById, getDiffRoles, getValidRoles, indexOfRef, isPerm, isPermsExist, maxLevel, ownerFieldName, permsFieldName, roleIdFieldName, roleRefsFieldName, rolesFieldName, rolesUpperName, updatePermsByRefs;
    capitalizeFirstLetter = function(aString) {
      return aString.charAt(0).toUpperCase() + aString.slice(1);
    };
    cached = (aOptions && aOptions.cached) || 1;
    rolesFieldName = (aOptions && aOptions.rolesFieldName) || 'roles';
    permsFieldName = (aOptions && aOptions.permsFieldName) || '_perms';
    roleRefsFieldName = (aOptions && aOptions.roleRefsFieldName) || '_roleRefs';
    roleIdFieldName = (aOptions && aOptions.roleIdFieldName) || 'name';
    ownerFieldName = (aOptions && aOptions.ownerFieldName) || 'creatorId';
    maxLevel = (aOptions && aOptions.maxLevel) || 12;
    deleteUsedRole = (aOptions && aOptions.deleteUsedRole) || false;
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
    Model.hasPerm = function(aId, aPermName, aContext) {
      return Model.findById(aId).then(function(aModel) {
        if (aModel) {
          return aModel.hasPerm(aPermName, aContext);
        }
      });
    };
    Model.prototype.hasPerm = function(aPermName, aContext) {
      return Promise.resolve(hasPerm(this[permsFieldName], aPermName, aContext, ownerFieldName));
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
    _merge = function(result, aRole) {
      var vPerms;
      if (isString(aRole)) {
        if (result.indexOf(aRole) === -1) {
          result.push(aRole);
        }
      } else if (aRole && isPermsExist(vPerms = aRole[permsFieldName])) {
        vPerms.forEach(function(k) {
          if (result.indexOf(k) === -1) {
            return result.push(k);
          }
        });
      }
      return result;
    };
    Model.getPerms = function(aRoles) {
      if (isArray(aRoles)) {
        return Promise.map(aRoles, function(aId) {
          if (isPerm(aId)) {
            return aId;
          } else {
            return findRoleById(aId);
          }
        }).reduce(function(aResult, aRole) {
          return _merge(aResult, aRole);
        }, []);
      } else {
        return Promise.resolve([]);
      }
    };
    Model.prototype.getPerms = function() {
      return Model.getPerms(this[rolesFieldName]);
    };
    calcPerms = function(aInstance, ctx) {
      var account, remoteCtx, vGetPerms;
      vGetPerms = Model.getPerms(aInstance[rolesFieldName]);
      if (ctx.options && (remoteCtx = ctx.options.remoteCtx) && remoteCtx.req && (account = remoteCtx.req.currentUser)) {
        return account.hasPerm(Model.modelName + '.' + 'add' + rolesUpperName).then(function(allowed) {
          var err;
          if (allowed) {
            return vGetPerms;
          }
          err = new Error;
          err.statusCode = 401;
          err.message = 'No AddRole Authority';
          err.code = 'NO_AUTHORITY_ADD_ROLE';
          throw err;
        });
      } else {
        return vGetPerms;
      }
    };
    getValidRoles = function(aRoles) {
      var result;
      if (isArray(aRoles)) {
        result = aRoles.filter(function(item) {
          return isString(item) && item.length;
        });
      } else {
        result = [];
      }
      return result;
    };
    getDiffRoles = function(aNewRoles, aOriginalRoles) {
      var i, j, l, len, len1, vAddedRoles, vDelRoles;
      if (aOriginalRoles && aOriginalRoles.length) {
        vAddedRoles = [];
        vDelRoles = [];
        for (j = 0, len = aNewRoles.length; j < len; j++) {
          i = aNewRoles[j];
          if (aOriginalRoles.indexOf(i) === -1) {
            vAddedRoles.push(i);
          }
        }
        for (l = 0, len1 = aOriginalRoles.length; l < len1; l++) {
          i = aOriginalRoles[l];
          if (aNewRoles.indexOf(i) === -1) {
            vDelRoles.push(i);
          }
        }
      } else {
        vAddedRoles = aNewRoles;
      }
      return [getValidRoles(vAddedRoles), getValidRoles(vDelRoles)];
    };
    indexOfRef = function(aRefs, aModel, aId) {
      var aRef, j, len, result;
      for (result = j = 0, len = aRefs.length; j < len; result = ++j) {
        aRef = aRefs[result];
        if (aRef.model !== aModel) {
          continue;
        }
        if (aRef.id === aId) {
          return result;
        }
      }
      return -1;
    };
    addToRefs = function(aInstance, ctx) {
      var ref, vAddedRoles, vDelRoles, vDoAddedRoles, vDoDelRoles, vId;
      ref = getDiffRoles(aInstance[rolesFieldName], ctx.hookState.oldRoles), vAddedRoles = ref[0], vDelRoles = ref[1];
      vId = aInstance.id;
      if (vAddedRoles && vAddedRoles.length) {
        vAddedRoles = vAddedRoles.filter(function(item) {
          return !isPerm(item);
        });
        vDoAddedRoles = Promise.map(vAddedRoles, function(aRoleId) {
          return findRoleById(aRoleId).then(function(aRole) {
            var vRoleRefs;
            if (!aRole) {
              return;
            }
            vRoleRefs = aRole[roleRefsFieldName] || [];
            if (indexOfRef(vRoleRefs, Model.modelName, vId) === -1) {
              vRoleRefs.push({
                model: Model.modelName,
                id: vId
              });
              return aRole.updateAttribute(roleRefsFieldName, vRoleRefs, {
                skipPropertyFilter: true
              });
            }
          });
        });
      }
      if (vDelRoles && vDelRoles.length) {
        vDelRoles = vDelRoles.filter(function(item) {
          return !isPerm(item);
        });
        vDoDelRoles = Promise.map(vDelRoles, function(aRoleId) {
          return findRoleById(aRoleId).then(function(aRole) {
            var ix, vRoleRefs;
            if (!aRole) {
              return;
            }
            vRoleRefs = aRole[roleRefsFieldName] || [];
            ix = indexOfRef(vRoleRefs, Model.modelName, vId);
            if (ix !== -1) {
              vRoleRefs.splice(ix, 1);
              return aRole.updateAttribute(roleRefsFieldName, vRoleRefs, {
                skipPropertyFilter: true
              });
            }
          });
        });
      }
      return Promise.all([vDoAddedRoles, vDoDelRoles]);
    };
    Model.observe('before save', function(ctx) {
      var err, saveOldRoles, vInstance;
      vInstance = ctx.instance || ctx.data;
      if (!vInstance || (ctx.options && ctx.options.skipPropertyFilter)) {
        return Promise.resolve();
      }
      if (vInstance[rolesFieldName] == null) {
        return Promise.resolve();
      }
      if (ctx.instance) {
        vInstance.unsetAttribute(permsFieldName);
      } else {
        delete vInstance[permsFieldName];
      }
      if (ctx.data && !ctx.currentInstance) {
        err = new Error;
        err.message = 'Disable batch update roles';
        err.code = 'NO_AUTHORITY_BATCH_ROLE';
        return Promise.reject(err);
      }
      if (ctx.data) {
        saveOldRoles = Model.findById(ctx.currentInstance.id, {
          fields: [rolesFieldName]
        }).then(function(instance) {
          var vRoles;
          if (instance) {
            vRoles = instance[rolesFieldName];
          }
          if (vRoles && vRoles.length) {
            ctx.hookState.oldRoles = vRoles;
          }
        });
      }
      if (vInstance[rolesFieldName] == null) {
        return Promise.resolve();
      }
      vInstance[rolesFieldName] = getValidRoles(vInstance[rolesFieldName]);
      if (!saveOldRoles) {
        saveOldRoles = Promise.resolve();
      }
      return saveOldRoles.then(function() {
        return calcPerms(vInstance, ctx).then(function(aPerms) {
          vInstance[permsFieldName] = aPerms;
          if (!ctx.options) {
            ctx.options = {};
          }
          return ctx.options.updatePermsByRefs = 0;
        });
      });
    });
    Model.observe('after save', function(ctx) {
      var vInstance;
      if (ctx.options && ctx.options.skipPropertyFilter) {
        return Promise.resolve();
      }
      vInstance = ctx.instance || ctx.data;
      if (!(vInstance && (vInstance[rolesFieldName] != null))) {
        return Promise.resolve();
      }
      return addToRefs(vInstance, ctx);
    });
    Model.observe('before delete', function(ctx) {
      var vRoleRefs, vRoles, vState;
      vState = ctx.hookState;
      vState.deletedRoles = [];
      vRoleRefs = new Set();
      vRoles = new Set();
      return Model.find({
        where: ctx.where,
        fields: ['id', roleRefsFieldName, rolesFieldName]
      }).then(function(results) {
        if (results) {
          return Promise.each(results, function(item) {
            var v, vOk;
            if ((v = item[rolesFieldName]) && v.length) {
              v.forEach(function(i) {
                if (!isPerm(i)) {
                  return vRoles.add(i);
                }
              });
              vOk = true;
            }
            if ((v = item[roleRefsFieldName]) && v.length) {
              v.forEach(function(i) {
                return vRoleRefs.add(i);
              });
              vOk = true;
            }
            if (vOk) {
              vState.deletedRoles.push(item.id);
            }
          });
        }
      }).then(function() {
        if (vRoles.size) {
          vState.roles = Array.from(vRoles);
        }
        if (vRoleRefs.size) {
          vState.roleRefs = Array.from(vRoleRefs);
        }
        if (!vState.deletedRoles.length) {
          vState.deletedRoles = null;
        }
      });
    });
    Model.observe('after delete', function(ctx) {
      var vRoles, vState;
      vState = ctx.hookState;
      if (!(vState.roles && vState.deletedRoles)) {
        return Promise.resolve();
      }
      vRoles = vState.roles;
      return Promise.map(vState.roles, function(id) {
        return Model.findById(id);
      }).each(function(item) {
        var result, vRoleRefs;
        if (!item) {
          return;
        }
        vRoleRefs = item[roleRefsFieldName];
        if (vRoleRefs && vRoleRefs.length && removeObject(vRoleRefs, vState.deletedRoles, Model.modelName)) {
          result = item.updateAttribute(roleRefsFieldName, vRoleRefs, {
            skipPropertyFilter: true
          });
        }
        return result;
      });
    });
    if (Model === RoleModel) {
      if (deleteUsedRole) {
        Model.observe('after delete', function(ctx) {
          var vState;
          vState = ctx.hookState;
          if (!(vState.deletedRoles && vState.roleRefs)) {
            return Promise.resolve();
          }
          return Promise.map(vState.roleRefs, function(i) {
            var M;
            M = loopback.getModel(i.model);
            if (M) {
              return M.findById(i.id);
            }
          }).each(function(item) {
            var result, vRoles;
            if (!item) {
              return;
            }
            vRoles = item[rolesFieldName];
            if (vRoles && vRoles.length) {
              if (removeArray(vRoles, vState.deletedRoles)) {
                result = item.updateAttribute(rolesFieldName, vRoles);
              }
            }
            return result;
          });
        });
      } else {
        Model.observe('before delete', function(ctx) {
          return Model.find({
            where: ctx.where,
            fields: ['id', roleRefsFieldName]
          }).then(function(results) {
            if (results) {
              return Promise.each(results, function(item) {
                var v, vError;
                if ((v = item[roleRefsFieldName]) && v.length) {
                  vError = new Error('Can not delete the used role:' + item.id);
                  vError.code = 'DELETE_USED_ROLE';
                  throw vError;
                }
              });
            }
          });
        });
      }
      Model.observe('before save', function(ctx, next) {
        var vInstance;
        if (ctx.options && ctx.options.skipPropertyFilter) {
          return next();
        }
        vInstance = ctx.instance || ctx.data;
        if (vInstance) {
          if (ctx.instance) {
            vInstance.unsetAttribute(roleRefsFieldName);
          } else {
            delete vInstance[roleRefsFieldName];
          }
        }
        return next();
      });
      updatePermsByRefs = function(aInstance, ctx) {
        var vRefs;
        vRefs = aInstance[roleRefsFieldName];
        if (vRefs && vRefs.length) {
          return Promise.map(vRefs, function(aRef) {
            var vModel;
            vModel = loopback.getModel(aRef.model);
            if (vModel) {
              return vModel.findById(aRef.id).then(function(aItem) {
                if (!aItem) {
                  return;
                }
                return aItem.getPerms().then(function(aPerms) {
                  var vLevel;
                  if (isPermsExist(aPerms)) {
                    vLevel = (ctx.options && ctx.options.updatePermsByRefs) || 0;
                    vLevel++;
                    return aItem.updateAttribute(permsFieldName, aPerms, {
                      skipPropertyFilter: true,
                      updatePermsByRefs: vLevel
                    });
                  }
                });
              });
            }
          });
        } else {
          return Promise.resolve();
        }
      };
      return Model.observe('after save', function(ctx) {
        var vError, vInstance, vLevel;
        vInstance = ctx.instance || ctx.data;
        vLevel = ctx.options && ctx.options.updatePermsByRefs;
        if (!((vLevel != null) && vInstance && (vInstance[rolesFieldName] != null))) {
          return Promise.resolve();
        }
        if (vLevel >= maxLevel) {
          vError = new Error('Exceed max level limits:' + maxLevel);
          vError.code = 'ROLE_MAX_LEVEL_LIMITS';
          return Promise.reject(vError);
        }
        return updatePermsByRefs(vInstance, ctx);
      });
    }
  };

}).call(this);

//# sourceMappingURL=updated-roles.js.map
