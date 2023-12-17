var system = require('system');
var page = require('webpage').create();
var fs = require('fs');
var cookieJarFilePath = '/tmp/cookies.txt';
var clientId = system.env.IAM_CLIENT_ID;
var redirectUri = system.env.REDIRECT_URI;
var args = system.args;
var iamServer = args[1];

page.viewportSize = {
  width: 1920,
  height: 1080
};

readCookiesFromFile = function() {
  cookieJar = [];
  if(fs.isFile(cookieJarFilePath)) {
    cookieJar = JSON.parse(fs.read(cookieJarFilePath));
  }
  for(var j in cookieJar) {
    phantom.addCookie({
      'name'     : cookieJar[j].name,
      'value'    : cookieJar[j].value,
      'domain'   : cookieJar[j].domain,
      'path'     : cookieJar[j].path,
      'httponly' : cookieJar[j].httponly,
      'secure'   : cookieJar[j].secure,
      'expires'  : cookieJar[j].expires
    });
  }
};

readCookiesFromFile();

page.open('https://' + iamServer + '/authorize?response_type=code&redirect_uri=' + redirectUri + '&client_id=' + clientId, function(status) {
  setTimeout(function(){
      (function() {
          document.querySelector("#wrap > div > div > div.container-fluid.page-content > div:nth-child(1) > form > div > div.scopes-box > div:nth-child(18) > input.btn.btn-success.btn-large").click();
      });
  }, 1);

  setTimeout(function(){
      console.log(page.url);
      phantom.exit();
  }, 1);

});
