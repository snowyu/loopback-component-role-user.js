(function() {
  var extend, isArray, isObject, isString, match, minimatch;

  isArray = require('util-ex/lib/is/type/array');

  isObject = require('util-ex/lib/is/type/object');

  isString = require('util-ex/lib/is/type/string');

  extend = require('util-ex/lib/_extend');

  minimatch = require('minimatch-ex');

  match = function(aPath, aCollection) {
    return minimatch(aPath, aCollection);
  };


  /*
  if the perm is `.owned`
  we should limit the resource's creator(ownerFieldName) is itself.
   */

  module.exports = function(aPerms, aPermName, aContext, ownerFieldName) {
    var ref, ref1, result, vArgs, vFilter, vUserId, vWhere;
    if (isArray(aPerms)) {
      result = match(aPermName, aPerms);
      if (aContext) {
        vOwnedPermName += '.owned';
        if (match(vOwnedPermName, aPerms)) {
          aContext.owned = true;
        }
        if (!result && aContext.owned) {
          aContext['owned'] = true;
          result = aContext.model;
          if (result) {
            vUserId = aContext.getUserId();
            if (aContext.modelId != null) {
              result = aContext.model.findById(aContext.modelId).then(function(m) {
                return m && m[ownerFieldName] === vUserId;
              });
            } else if (result = (ref = aContext.remotingContext) != null ? (ref1 = ref.args) != null ? ref1.hasOwnProperty('filter') : void 0 : void 0) {
              vArgs = aContext.remotingContext.args;
              if (isString(vArgs.filter)) {
                vFilter = JSON.parse(vArgs.filter);
              } else {
                vFilter = extend({}, vArgs.filter);
              }
              vWhere = vFilter.where;
              if (!isObject(vWhere)) {
                vWhere = vFilter.where = {};
              }
              vWhere[ownerFieldName] = vUserId;
              vArgs.filter = vFilter;
            }
          }
        }
      }
      return result;
    } else {
      return false;
    }
  };

}).call(this);

//# sourceMappingURL=has-perm.js.map
