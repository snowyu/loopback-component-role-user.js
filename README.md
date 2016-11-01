# Loopback Component user dynamic role

This loopback component add a new dynamic user role which mapping the operators of model to the role.
The role name should be '[`modelName`]' + '.' + '[`operator`]'. The role should be mapped into the ACL too.
And the role can be nested like this:

```coffee
Role1:
  User.add

Role2:
  Role1

Role3:
  Role2
```

The Role3 should has the `User.add` role too.

The role could have multi containers of permission(aother role) or permissions.

The Permission is the model with operation. You can use the `*` to match the any model or any operation.
eg, `'*.add', 'User.*'`.

**Note:**

* The same permission should NOT be exists in multi-roles.
* The same role could be exists in multi-roles.
* Disable batch update roles.


### Installation

1. Install in you loopback project:

  `npm install --save loopback-component-role-user`

2. Create a component-config.json file in your server folder (if you don't already have one)

3. Configure options inside `component-config.json`:

  ```json
  {
    "loopback-component-role-user": {
      "enabled": true,
      "role": "$user",
      "userModel": "User",
      "roleIdFieldName": "name",
      "rolesFieldName": "roles",
      "permsFieldName": "_perms",
      "roleRefsFieldName": "_roleRefs",
      "models": [],
      "operations":[]
    }
  }
  ```
  - `enabled` *[Boolean]*: whether enable this component. *defaults: true*
  - `role` *[String]* : the role name. *defaults: $user*
  - `roleModel` *[string]*: The role model to inject. *defaults: Role*
    * The `rolesFieldName` and `permsFieldName` fields will be added to the Model.
    * The `hasPerm` method will be added to the Model.
    * The `addRoles` and `removeRoles` methods will be added if the `rolesFieldName` is 'roles'.
      * The `Role.addRoles` and `Role.removeRoles` permissions are added too.
  - `userModel` *[string]*: The user model to inject. *defaults: User*
    * The `rolesFieldName` and `permsFieldName` fields will be added to the User Model.
    * The `hasPerm` method will be added to the User Model.
    * The `addRoles` and `removeRoles` methods will be added if the `rolesFieldName` is 'roles'.
      * The `User.addRoles` and `User.removeRoles` permissions are added too.
  - `rolesFieldName` *[string]*: The roles field to define. *defaults: roles*
    * The model(role) can have zero or more roles/permissions.
  - `permsFieldName` *[string]*: The cached perms of this role. *defaults: _perms*
    * Cache all the permissions to the roles(Readonly).
  - `roleRefsFieldName` *[string]*: The cached items which reference this role(Readonly). *defaults: _roleRefs*
  - `models` *[Boolean|Array of string]*. *defaults: true*
    * enable the user role to the models. `true` means all models in the app.models.
  - `operations` *[Object]*: the mapping operations of model to the role name.
    * the `key` is the operation(method), the `value` is the role name.
    * Note: the operations name is the role name if no mapping operations.
    * *defaults:*

      ```js
      {
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
      }
      ```

### Usage


Just enable it on `component-config.json`.

set `DEBUG=loopback:security:role:user` env vaiable to show debug info.

`Model::hasPerm(perm)`

## History

### V1.0.0

- remove the deprecated `adminRole` option. you can define the admin Role with `*.*` principal.
* rename the operators option to operations
* Customize the Role and User Model.
- remove `hasRole` Method.
+ add the `Roles` mxin.
  * Define the `roles` and `perms` fields.
    * roles: the
  * Add the `hasPerm`, `addRoles` and `removeRoles` methods.
+ add the `hasPerm`, `addRoles` and `removeRoles` methods to Role and User Model.
* Performance optimization.
  * cache permissions and references.

### V0.2.0

+ add the `Role::hasRole`

