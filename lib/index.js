(function() {
  'use strict';
  var debug, userRole;

  debug = require('debug')('loopback:security:role:user');

  userRole = require('./user-role');

  module.exports = function(app, options) {
    var loopback, loopbackMajor;
    debug('initializing component');
    loopback = app.loopback;
    loopbackMajor = loopback && loopback.version && loopback.version.split('.')[0] || 1;
    if (loopbackMajor < 2) {
      throw new Error('loopback-component-role-user requires loopback 2.0 or newer');
    }
    if (!options || options.enabled !== false) {
      return userRole(app, options);
    } else {
      return debug('component not enabled');
    }
  };

}).call(this);

//# sourceMappingURL=index.js.map
