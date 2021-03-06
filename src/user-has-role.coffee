Promise   = require 'bluebird'
loopback  = require 'loopback'

module.exports = (app, aAdminRole)->
  User = loopback.User
  RoleMapping = loopback.RoleMapping
  Role = loopback.Role

  # Whether the aRoleName is in the aRole.principals.
  Role::hasRole = (aRoleName)->
    return true if aAdminRole and @name is aAdminRole
    result = new Promise (resolve, reject)=>
      @principals (err, aPrincipals)->
        if err then reject(err) else resolve(aPrincipals)
    result.filter (aPrincipal)-> aPrincipal.principalType is RoleMapping.ROLE
    .reduce (aResult, aPrincipal)->
      unless aResult is true
        if aPrincipal.principalId is aRoleName
          aResult = true
        else
          aResult = Role.findOne where: name: aPrincipal.principalId
          .then (role)->
            if role then role.hasRole(aRoleName) else false
      aResult
    , false

  User.hasRole = (aUserId, aRole)->
    # find all roles for the user
    RoleMapping.find where: principalType: RoleMapping.USER, principalId: aUserId
    .then (aRoleMappings)->
      if (aRoleMappings)
        Promise.reduce aRoleMappings, (aResult, aRoleMapping)->
          unless aResult is true
            aResult = Role.findById aRoleMapping.roleId
            .then (role)->
              if role
                if role.name is aRole
                  aResult = true
                else
                  role.hasRole aRole
          aResult
        , false
      else
        false
