(function() {
  var Promise, Role, RoleMapping, debug, isAdminUserFn, isArray, isRoleIn, registerAdminRole;

  Promise = require('bluebird');

  isArray = require('util-ex/lib/is/type/array');

  debug = require('debug')('loopback:security:role:super');

  registerAdminRole = function(Role, aRoleName, aIsAdminUserFn) {
    debug('register role resolver: %s', aRoleName);
    return Role.registerResolver(aRoleName, function(role, context, done) {
      var reject, resolve, vUserId;
      reject = function(err) {
        if (err) {
          return done(err);
        } else {
          return process.nextTick(function() {
            if (done) {
              done(null, false);
            }
          });
        }
      };
      resolve = function(result) {
        if (result == null) {
          result = true;
        }
        return process.nextTick(function() {
          if (done) {
            done(null, result);
          }
        });
      };
      vUserId = context.getUserId();
      debug('check the userId %s has the %s', vUserId, role);
      if (!vUserId) {
        reject();
      } else {
        aIsAdminUserFn(vUserId, aRoleName, function(err, result) {
          debug('isAdminUser: %s', result);
          if (err) {
            reject(err);
          } else {
            resolve(result);
          }
        });
      }
    });
  };

  isRoleIn = function(aAcls, aRoleName) {
    var acl, i, len;
    for (i = 0, len = aAcls.length; i < len; i++) {
      acl = aAcls[i];
      if (acl.principalType === 'ROLE' && acl.principalId === aRoleName) {
        return true;
      }
    }
    return false;
  };

  Role = null;

  RoleMapping = null;

  isAdminUserFn = function(aUserId, aRoleName, done) {
    return Role.findOne({
      where: {
        name: aRoleName
      }
    }).then(function(role) {
      return RoleMapping.findOne({
        where: {
          principalId: aUserId,
          roleId: role.id
        }
      });
    }).then(function(roleMapping) {
      done(null, !!roleMapping);
    })["catch"](function(err) {
      return done(err);
    });
  };

  module.exports = function(aApp, aOptions) {
    var Model, i, len, loopback, vAcls, vIsAdminUser, vModels, vName, vResult, vRoleName;
    loopback = aApp.loopback;
    Role = loopback.Role;
    RoleMapping = loopback.RoleMapping;
    vRoleName = (aOptions && aOptions.role) || '$admin';
    vIsAdminUser = (aOptions && aOptions.isAdminUserCallback) || isAdminUserFn;
    vModels = aOptions && aOptions.models;
    if (vModels === false) {
      vModels = [];
    }
    if (isArray(vModels)) {
      vResult = {};
      for (i = 0, len = vModels.length; i < len; i++) {
        vName = vModels[i];
        Model = aApp.models[vName];
        if (Model) {
          vResult[vName] = Model;
        }
      }
      vModels = vResult;
    } else {
      vModels = aApp.models;
    }
    Role = aApp.models.Role;
    registerAdminRole(Role, vRoleName, vIsAdminUser);
    for (vName in vModels) {
      Model = vModels[vName];
      vAcls = Model.settings.acls;
      if (!vAcls) {
        vAcls = Model.settings.acls = [];
      }
      if (!isRoleIn(vAcls, vRoleName)) {
        debug('enable superuser for Model %s', vName);
        vAcls.push({
          principalType: 'ROLE',
          principalId: vRoleName,
          permission: 'ALLOW'
        });
      }
    }
  };

}).call(this);

//# sourceMappingURL=admin-role.js.map
