(function() {
  var Promise, loopback;

  Promise = require('bluebird');

  loopback = require('loopback');

  module.exports = function(app, aAdminRole) {
    var Role, RoleMapping, User;
    User = loopback.User;
    RoleMapping = loopback.RoleMapping;
    Role = loopback.Role;
    Role.prototype.hasRole = function(aRoleName) {
      var result;
      if (aAdminRole && this.name === aAdminRole) {
        return true;
      }
      result = new Promise((function(_this) {
        return function(resolve, reject) {
          return _this.principals(function(err, aPrincipals) {
            if (err) {
              return reject(err);
            } else {
              return resolve(aPrincipals);
            }
          });
        };
      })(this));
      return result.filter(function(aPrincipal) {
        return aPrincipal.principalType === RoleMapping.ROLE;
      }).reduce(function(aResult, aPrincipal) {
        if (aResult !== true) {
          if (aPrincipal.principalId === aRoleName) {
            aResult = true;
          } else {
            aResult = Role.findOne({
              where: {
                name: aPrincipal.principalId
              }
            }).then(function(role) {
              if (role) {
                return role.hasRole(aRoleName);
              } else {
                return false;
              }
            });
          }
        }
        return aResult;
      }, false);
    };
    return User.hasRole = function(aUserId, aRole) {
      return RoleMapping.find({
        where: {
          principalType: RoleMapping.USER,
          principalId: aUserId
        }
      }).then(function(aRoleMappings) {
        if (aRoleMappings) {
          return Promise.reduce(aRoleMappings, function(aResult, aRoleMapping) {
            if (aResult !== true) {
              aResult = Role.findById(aRoleMapping.roleId).then(function(role) {
                if (role) {
                  if (role.name === aRole) {
                    return aResult = true;
                  } else {
                    return role.hasRole(aRole);
                  }
                }
              });
            }
            return aResult;
          }, false);
        } else {
          return false;
        }
      });
    };
  };

}).call(this);

//# sourceMappingURL=user-has-role.js.map
