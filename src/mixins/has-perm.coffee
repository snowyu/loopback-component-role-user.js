extend    = require 'util-ex/lib/_extend'
minimatch = require 'minimatch-ex'

match = (aPath, aCollection)->
  # aCollection = Object.keys aCollection if isObject aCollection
  minimatch aPath, aCollection

###
if the perm is `.owned`
we should limit the resource's creator(ownerFieldName) is itself.
###
module.exports = (aPerms, aPermName, aContext, ownerFieldName)->
  if isArray(aPerms)
    result = match aPermName, aPerms
    if !result and aContext
      vOwnedPermName += '.owned'
      result = match vOwnedPermName, aPerms
      if result
        aContext['owned'] = true
        result = aContext.model
        if result
          # get the current session user id.
          vUserId = aContext.getUserId()
          if aContext.modelId?
            result = aContext.model.findById aContext.modelId
            .then (m)->
              m and m[ownerFieldName] is vUserId
          else if result = aContext.remotingContext?.args?.hasOwnProperty 'filter'
            vArgs = aContext.remotingContext.args
            if isString vArgs.filter
              vFilter = JSON.parse vArgs.filter
            else
              vFilter = extend {}, vArgs.filter
            vWhere  = vFilter.where
            vWhere  = vFilter.where = {} unless isObject vWhere
            vWhere[ownerFieldName] = vUserId
            vArgs.filter = vFilter
    result
  else
    false
