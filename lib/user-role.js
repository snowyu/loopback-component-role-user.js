(function() {
  var Promise, debug, extend, injectRoles, isArray, isFunction, isRoleIn, registerRole;

  Promise = require('bluebird');

  isArray = require('util-ex/lib/is/type/array');

  isFunction = require('util-ex/lib/is/type/function');

  extend = require('util-ex/lib/_extend');

  debug = require('debug')('loopback:security:role:user');

  injectRoles = require('./mixins/roles');

  registerRole = function(Role, aRoleName, User, aOperations) {
    debug('register role resolver: %s', aRoleName);
    return Role.registerResolver(aRoleName, function(role, context, done) {
      var reject, vPermName, vUserId;
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
      vUserId = context.getUserId();
      if (!vUserId) {
        debug('disable anonymous user');
        reject();
      } else {
        vPermName = context.modelName + '.' + (aOperations[context.property] || context.property);
        User.hasPerm(vUserId, vPermName, context).then(function(result) {
          debug('the userId %s has the %s: %s', vUserId, vPermName, result);
          done(null, result);
        })["catch"](function(err) {
          debug('the userId %s has the %s raise error: %s', vUserId, vPermName, err);
          done(err);
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

  module.exports = function(aApp, aOptions) {
    var Model, Role, User, i, len, loopback, vAcls, vModels, vName, vOperations, vResult, vRoleName;
    if (aOptions == null) {
      aOptions = {};
    }
    loopback = aApp.loopback;
    Role = (aOptions.roleModel && loopback.getModel(aOptions.roleModel)) || loopback.Role;
    User = (aOptions.userModel && loopback.getModel(aOptions.userModel)) || loopback.User;
    injectRoles(Role, aOptions);
    injectRoles(User, extend({}, aOptions, {
      RoleModel: Role
    }));
    vRoleName = (aOptions && aOptions.role) || '$user';
    vOperations = (aOptions && aOptions.operations) || {
      create: 'add',
      upsert: 'edit',
      updateAttributes: 'edit',
      exists: 'view',
      findById: 'view',
      find: 'find',
      findOne: 'find',
      count: 'find',
      destroyById: 'delete',
      deleteById: 'delete'
    };
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
    registerRole(loopback.Role, vRoleName, User, vOperations);
    for (vName in vModels) {
      Model = vModels[vName];
      vAcls = Model.settings.acls;
      if (!vAcls) {
        vAcls = Model.settings.acls = [];
      }
      if (!isRoleIn(vAcls, vRoleName)) {
        debug('enable "%s" Role for Model %s', vRoleName, vName);
        vAcls.push({
          principalType: 'ROLE',
          principalId: vRoleName,
          permission: 'ALLOW'
        });
      }
    }
  };

}).call(this);

//# sourceMappingURL=user-role.js.map
