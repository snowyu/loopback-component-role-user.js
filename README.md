# Loopback Component user dynamic role

This loopback component add a new dynamic user role which mapping the operators of model to the role and
you can enable the super user role too.
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
      "adminRole": "admin",
      "models": [],
      "operators":[]
    }
  }
  ```
  - `enabled` *[Boolean]*: whether enable this component. *defaults: true*
  - `role` *[String]* : the role name. *defaults: $user*
  - `adminRole` *[String]* : the administrator(super user) role name. *defaults: undefined*
    * `null/undefined/""` means disable the admin(super user) role.
  - `models` *[Boolean|Array of string]*. *defaults: true*
    * enable the admin role to the models. `true` means all models in the app.models.
  - `operators` *[Object]*: the mapping operators of model to the role name.
    * the `key` is the operator(method), the `value` is the role name.
    * Note: the operator name is the role name if no mapping operator.
    * *defaults:*

      ```json
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


the `User.hasRole(aUserId, aRoleName)` promise async function added to check.

## History

### V0.2.0

+ add the `Role::hasRole`

